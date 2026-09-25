//go:build android && cgo

package main

import "sync/atomic"

var rootControlMode atomic.Bool

func saveRootSetupParams(*SetupParams) error { return nil }

func saveRootProxySelection(string, string) error { return nil }
