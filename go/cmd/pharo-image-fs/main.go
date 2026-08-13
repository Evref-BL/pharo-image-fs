package main

import (
	"fmt"
	"os"

	"github.com/Evref-BL/pharo-image-fs/go/pkg/mount"
)

func main() {
	if err := mount.Run(os.Args[1:]); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}
