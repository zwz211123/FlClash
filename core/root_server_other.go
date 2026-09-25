//go:build !linux && !(android && cgo)

package main

import "sync/atomic"

var rootControlMode atomic.Bool

func startRootServer(string, bool) {
	panic("root control is only supported on Linux")
}

func saveRootSetupParams(*SetupParams) error { return nil }

func saveRootProxySelection(string, string) error { return nil }
