package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"net"
	"os"
	"path/filepath"
)

var (
	stateDir = filepath.Join(home(), ".local", "state", "whatsapp")
	mediaDir = filepath.Join(runtimeDir(), "whatsapp-media")
)

func home() string {
	dir, err := os.UserHomeDir()
	if err != nil {
		die("no home directory: %v", err)
	}
	return dir
}

func runtimeDir() string {
	if dir := os.Getenv("XDG_RUNTIME_DIR"); dir != "" {
		return dir
	}
	return filepath.Join(os.TempDir(), fmt.Sprintf("whatsapp-%d", os.Getuid()))
}

func socketPath() string {
	return filepath.Join(runtimeDir(), "whatsapp.sock")
}

func die(format string, args ...any) {
	fmt.Fprintf(os.Stderr, "whatsapp: "+format+"\n", args...)
	os.Exit(1)
}

func usage() {
	die("usage: whatsapp login | daemon | logout | send <chat> <text> [quote-id] | file <chat> <path> <auto|photo|document|sticker> [quote-id] | open <chat> | fetch <chat> <id> | save <chat> <id>")
}

type request struct {
	Op    string `json:"op"`
	Chat  string `json:"chat,omitempty"`
	ID    string `json:"id,omitempty"`
	Text  string `json:"text,omitempty"`
	Path  string `json:"path,omitempty"`
	As    string `json:"as,omitempty"`
	Quote string `json:"quote,omitempty"`
}

type response struct {
	OK    bool   `json:"ok"`
	Path  string `json:"path,omitempty"`
	Error string `json:"error,omitempty"`
}

func call(req request) response {
	conn, err := net.Dial("unix", socketPath())
	if err != nil {
		die("daemon not running (%v); systemctl --user status whatsapp", err)
	}
	defer conn.Close()
	if err := json.NewEncoder(conn).Encode(req); err != nil {
		die("%v", err)
	}
	var resp response
	if err := json.NewDecoder(bufio.NewReader(conn)).Decode(&resp); err != nil {
		die("no answer from daemon: %v", err)
	}
	if !resp.OK {
		die("%s", resp.Error)
	}
	return resp
}

func optional(args []string, i int) string {
	if i < len(args) {
		return args[i]
	}
	return ""
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	args := os.Args[2:]
	switch os.Args[1] {
	case "login":
		login()
	case "daemon":
		daemon()
	case "logout":
		call(request{Op: "logout"})
	case "send":
		if len(args) < 2 || len(args) > 3 {
			usage()
		}
		call(request{Op: "send", Chat: args[0], Text: args[1], Quote: optional(args, 2)})
	case "file":
		if len(args) < 3 || len(args) > 4 {
			usage()
		}
		path, err := filepath.Abs(args[1])
		if err != nil {
			die("%v", err)
		}
		call(request{Op: "file", Chat: args[0], Path: path, As: args[2], Quote: optional(args, 3)})
	case "open":
		if len(args) != 1 {
			usage()
		}
		call(request{Op: "open", Chat: args[0]})
	case "fetch":
		if len(args) != 2 {
			usage()
		}
		fmt.Println(call(request{Op: "fetch", Chat: args[0], ID: args[1]}).Path)
	case "save":
		if len(args) != 2 {
			usage()
		}
		fmt.Println(call(request{Op: "save", Chat: args[0], ID: args[1]}).Path)
	default:
		usage()
	}
}
