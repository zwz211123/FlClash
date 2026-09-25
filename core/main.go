//go:build !(android && cgo)

package main

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/metacubex/mihomo/constant"
)

func main() {
	args := os.Args
	if len(args) <= 1 {
		fmt.Fprintln(os.Stderr, "Arguments error")
		os.Exit(1)
	}
	go exitOnTermination()
	if args[1] == "--root-test" {
		if len(args) != 3 {
			os.Exit(2)
		}
		constant.SetHomeDir(filepath.Dir(args[2]))
		if _, err := loadConfig(args[2]); err != nil {
			fmt.Fprintln(os.Stderr, err)
			os.Exit(1)
		}
		return
	}
	if args[1] == "--root-listen" {
		if len(args) != 3 && len(args) != 4 {
			fmt.Fprintln(os.Stderr, "root listener requires an app home directory")
			os.Exit(1)
		}
		startRootServer(args[2], len(args) == 4 && args[3] == "autostart")
		return
	}
	startServer(args[1])
}
