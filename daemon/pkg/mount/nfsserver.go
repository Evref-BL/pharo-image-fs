package mount

import (
	"fmt"
	"log"
	"net"
	"os"
	"os/exec"
	"os/signal"
	"runtime"
	"strings"

	"github.com/Evref-BL/pharo-image-fs/daemon/pkg/protocol"
	nfs "github.com/willscott/go-nfs"
	helpers "github.com/willscott/go-nfs/helpers"
)

// NFSServer manages the NFS server lifecycle and mount.
type NFSServer struct {
	listener   net.Listener
	server     *nfs.Server
	mountPoint string
	port       int
	unmounted  bool
}

// RunNFS starts the pharo-image-fs NFS mount daemon.
func RunNFS(args []string) error {
	config, err := ParseConfig(args)
	if err != nil {
		return err
	}

	client, err := protocol.NewHTTPClient(config.Endpoint)
	if err != nil {
		return err
	}

	server, err := MountNFS(config.MountPoint, client, config)
	if err != nil {
		return err
	}

	// Wait for interrupt signal
	sigCh := make(chan os.Signal, 1)
	signal.Notify(sigCh, os.Interrupt)
	<-sigCh

	return server.Unmount()
}

// MountNFS starts the NFS server and mounts at mountPoint.
func MountNFS(mountPoint string, client protocol.Client, config Config) (*NFSServer, error) {
	if err := ensureMountPoint(mountPoint); err != nil {
		return nil, err
	}

	// Create PharoFS
	pharoFS := NewPharoFS(client)

	// Create NFS handler
	handler := helpers.NewNullAuthHandler(pharoFS)
	cacheHandler := helpers.NewCachingHandler(handler, 1024)

	// Enable debug logging for go-nfs
	nfs.Log.SetLevel(nfs.DebugLevel)

	// Listen on a port
	listener, err := net.Listen("tcp", ":0")
	if err != nil {
		return nil, fmt.Errorf("failed to listen on port: %w", err)
	}
	port := listener.Addr().(*net.TCPAddr).Port

	// Start NFS server
	server := &nfs.Server{
		Handler: cacheHandler,
	}
	go func() {
		if err := server.Serve(listener); err != nil && err != net.ErrClosed {
			log.Printf("NFS server error: %v", err)
		}
	}()

	srv := &NFSServer{
		listener:   listener,
		server:     server,
		mountPoint: mountPoint,
		port:       port,
	}

	// Mount the NFS share
	if err := srv.mount(config); err != nil {
		listener.Close()
		return nil, err
	}

	return srv, nil
}

// mount mounts the NFS share at the mount point.
func (s *NFSServer) mount(config Config) error {
	if runtime.GOOS == "darwin" {
		return s.mountDarwin(config)
	}
	return s.mountLinux(config)
}

// mountDarwin mounts on macOS using mount_nfs.
func (s *NFSServer) mountDarwin(config Config) error {
	// Build mount options
	mountOpts := []string{
		fmt.Sprintf("port=%d", s.port),
		fmt.Sprintf("mountport=%d", s.port),
		"nfsvers=3",
		"tcp",
		"nolock",
		"locallocks",
		"nfc",
		"actimeo=1",
		"noatime",
		"rsize=32768",
		"wsize=32768",
	}

	// Add user-specified mount options
	for _, opt := range config.MountOptions {
		mountOpts = append(mountOpts, opt)
	}

	// Build mount command
	// mount_nfs -o <options> localhost:/ <mountpoint>
	args := []string{"-o", strings.Join(mountOpts, ","), "localhost:/", s.mountPoint}

	cmd := exec.Command("mount_nfs", args...)
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stdout

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("mount_nfs failed: %w", err)
	}

	return nil
}

// mountLinux mounts on Linux using mount with NFS.
func (s *NFSServer) mountLinux(config Config) error {
	// Build mount options
	mountOpts := []string{
		fmt.Sprintf("port=%d", s.port),
		fmt.Sprintf("mountport=%d", s.port),
		"nfsvers=3",
		"tcp",
		"nolock",
		"locallocks",
		"actimeo=1",
		"noatime",
		"rsize=32768",
		"wsize=32768",
	}

	// Add user-specified mount options
	for _, opt := range config.MountOptions {
		mountOpts = append(mountOpts, opt)
	}

	// Build mount command
	// mount -t nfs -o <options> localhost:/ <mountpoint>
	args := []string{"-t", "nfs", "-o", strings.Join(mountOpts, ","), "localhost:/", s.mountPoint}

	cmd := exec.Command("mount", args...)
	cmd.Stderr = os.Stderr
	cmd.Stdout = os.Stdout

	if err := cmd.Run(); err != nil {
		return fmt.Errorf("mount failed: %w", err)
	}

	return nil
}

// Unmount unmounts the NFS share and stops the server.
func (s *NFSServer) Unmount() error {
	if s.unmounted {
		return nil
	}
	s.unmounted = true

	var err error
	if runtime.GOOS == "darwin" {
		err = s.unmountDarwin()
	} else {
		err = s.unmountLinux()
	}

	// Close the listener to stop the server
	if s.listener != nil {
		s.listener.Close()
	}

	return err
}

// unmountDarwin unmounts on macOS.
func (s *NFSServer) unmountDarwin() error {
	cmd := exec.Command("umount", s.mountPoint)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		// Try force unmount
		cmd = exec.Command("umount", "-f", s.mountPoint)
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}
	return nil
}

// unmountLinux unmounts on Linux.
func (s *NFSServer) unmountLinux() error {
	cmd := exec.Command("umount", s.mountPoint)
	cmd.Stderr = os.Stderr
	if err := cmd.Run(); err != nil {
		cmd = exec.Command("umount", "-f", s.mountPoint)
		cmd.Stderr = os.Stderr
		return cmd.Run()
	}
	return nil
}

// MountPoint returns the mount point path.
func (s *NFSServer) MountPoint() string {
	return s.mountPoint
}

// Port returns the NFS server port.
func (s *NFSServer) Port() int {
	return s.port
}
