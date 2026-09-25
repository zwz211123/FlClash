//go:build linux && !android

package main

import (
	"crypto/subtle"
	"encoding/binary"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/metacubex/mihomo/constant"
)

const rootControlAddress = "127.0.0.1:17901"

var rootControlMode atomic.Bool
var rootSetupMu sync.Mutex

func startRootServer(home string, autostart bool) {
	token, err := os.ReadFile(filepath.Join(home, "root-control-token"))
	if err != nil || len(strings.TrimSpace(string(token))) < 32 {
		panic("missing or invalid root control token")
	}
	info, err := os.Stat(home)
	if err != nil {
		panic(err)
	}
	owner, ok := info.Sys().(*syscall.Stat_t)
	if !ok || owner.Uid == 0 {
		panic("app home must be owned by the app")
	}
	realUid, realGid = int(owner.Uid), int(owner.Gid)
	rootControlMode.Store(true)
	if !handleInitClash(&InitParams{HomeDir: home}) {
		panic("cannot initialize core")
	}
	if autostart {
		params := defaultSetupParams()
		if data, err := os.ReadFile(filepath.Join(home, "root-setup.json")); err == nil {
			if err := json.Unmarshal(data, params); err != nil {
				panic("invalid saved setup: " + err.Error())
			}
		}
		if message := handleSetupConfig(params); message != "" {
			panic("cannot apply boot configuration: " + message)
		}
		handleStartListener()
	}
	listener, err := net.Listen("tcp", rootControlAddress)
	if err != nil {
		panic(err)
	}
	defer listener.Close()
	for {
		client, err := listener.Accept()
		if err != nil {
			panic(err)
		}
		go serveRootClient(client, []byte(strings.TrimSpace(string(token))))
	}
}

func saveRootSetupParams(params *SetupParams) error {
	rootSetupMu.Lock()
	defer rootSetupMu.Unlock()
	return writeRootSetupParams(params)
}

func writeRootSetupParams(params *SetupParams) error {
	data, err := json.Marshal(params)
	if err != nil {
		return err
	}
	path := filepath.Join(constant.Path.HomeDir(), "root-setup.json")
	temporary := path + ".tmp"
	if err := os.WriteFile(temporary, data, 0600); err != nil {
		return err
	}
	if err := os.Rename(temporary, path); err != nil {
		return err
	}
	scheduleReclaimOwnership()
	return nil
}

func saveRootProxySelection(group, proxy string) error {
	rootSetupMu.Lock()
	defer rootSetupMu.Unlock()
	path := filepath.Join(constant.Path.HomeDir(), "root-setup.json")
	data, err := os.ReadFile(path)
	if err != nil {
		return err
	}
	params := defaultSetupParams()
	if err := json.Unmarshal(data, params); err != nil {
		return err
	}
	if params.SelectedMap == nil {
		params.SelectedMap = make(map[string]string)
	}
	params.SelectedMap[group] = proxy
	return writeRootSetupParams(params)
}

func serveRootClient(client net.Conn, token []byte) {
	defer client.Close()
	_ = client.SetReadDeadline(time.Now().Add(5 * time.Second))
	header := make([]byte, 4)
	if _, err := io.ReadFull(client, header); err != nil {
		return
	}
	size := binary.LittleEndian.Uint32(header)
	if size == 0 || size > 128 {
		return
	}
	auth := make([]byte, size)
	_, err := io.ReadFull(client, auth)
	if err != nil || subtle.ConstantTimeCompare(auth, token) != 1 {
		return
	}
	_ = client.SetReadDeadline(time.Time{})
	connMu.Lock()
	previous := conn
	conn = client
	deliveryFailureReported.Store(false)
	connMu.Unlock()
	if previous != nil {
		_ = previous.Close()
	}
	defer func() {
		connMu.Lock()
		if conn == client {
			conn = nil
		}
		connMu.Unlock()
	}()
	for {
		data, err := readFrame(client)
		if err != nil {
			if !errors.Is(err, io.EOF) {
				fmt.Fprintf(os.Stderr, "control connection closed: %v\n", err)
			}
			return
		}
		call := &MethodCall{}
		if err := json.Unmarshal(data, call); err != nil {
			continue
		}
		go handleMethodCall(call, newMethodResponse(call.ID, nil))
	}
}
