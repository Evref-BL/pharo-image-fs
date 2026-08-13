package mount

import (
	"flag"
	"fmt"
	"io"
)

// Config describes daemon startup options.
type Config struct {
	Endpoint   string
	MountPoint string
	Debug      bool
}

// ParseConfig parses command-line arguments for the daemon.
func ParseConfig(args []string) (Config, error) {
	flags := flag.NewFlagSet("pharo-image-fs", flag.ContinueOnError)
	flags.SetOutput(io.Discard)

	config := Config{}
	flags.StringVar(&config.Endpoint, "endpoint", "http://127.0.0.1:9013/projection", "Pharo projection endpoint root")
	flags.BoolVar(&config.Debug, "debug", false, "enable FUSE debug logging")

	if err := flags.Parse(args); err != nil {
		return Config{}, err
	}
	if flags.NArg() != 1 {
		return Config{}, fmt.Errorf("usage: pharo-image-fs [--endpoint URL] [--debug] <mountpoint>")
	}

	config.MountPoint = flags.Arg(0)
	return config, nil
}
