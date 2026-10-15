package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"strings"
	"syscall"
	"time"

	"github.com/mdp/qrterminal/v3"
	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/types"
)

func daemon() {
	ctx := context.Background()
	a := open(ctx)
	if a.cli.Store.ID == nil {
		a.setState("logged-out")
		a.flush(ctx)
		fmt.Fprintln(os.Stderr, "whatsapp: not linked; run whatsapp login")
		return
	}
	go a.flusher(ctx)
	go a.listen(ctx)
	a.compact()
	a.touchAll()
	if err := a.cli.Connect(); err != nil {
		die("connect: %v", err)
	}
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop
	a.cli.Disconnect()
	os.Remove(socketPath())
}

func login() {
	exec.Command("systemctl", "--user", "stop", "whatsapp").Run()
	ctx := context.Background()
	a := open(ctx)
	if a.cli.Store.ID != nil {
		die("already linked as +%s; run whatsapp logout first", a.cli.Store.ID.User)
	}
	codes, err := a.cli.GetQRChannel(ctx)
	if err != nil {
		die("%v", err)
	}
	go a.flusher(ctx)
	go a.listen(ctx)
	if err := a.cli.Connect(); err != nil {
		die("connect: %v", err)
	}
	passkey := false
	for item := range codes {
		switch item.Event {
		case whatsmeow.QRChannelEventCode:
			if passkey {
				continue
			}
			fmt.Print("\033[H\033[2J")
			qrterminal.GenerateHalfBlock(item.Code, qrterminal.L, os.Stdout)
			fmt.Println("\nWhatsApp on the phone → Linked devices → Link a device, and scan this.")
		case whatsmeow.QRChannelEventPasskeyRequest:
			passkey = true
			resp, err := askPasskey(item.PasskeyRequest.PublicKey)
			if err != nil {
				die("%v", err)
			}
			if err := a.cli.SendPasskeyResponse(ctx, resp); err != nil {
				die("passkey: %v", err)
			}
		case whatsmeow.QRChannelEventPasskeyResponse:
			fmt.Printf("\nCheck that the phone shows %s, then press Enter.\n", item.PasskeyConfirmation.Code)
			bufio.NewReader(os.Stdin).ReadString('\n')
			if err := a.cli.SendPasskeyConfirmation(ctx); err != nil {
				die("passkey: %v", err)
			}
		case whatsmeow.QRChannelEventError:
			die("pairing failed: %v", item.Error)
		case "success":
			fmt.Println("Linked. Receiving history from the phone; this takes a minute or two.")
		default:
			die("pairing failed: %s", item.Event)
		}
	}
	start := time.Now()
	for {
		time.Sleep(time.Second)
		a.mu.Lock()
		got, lastAt := a.gotHistory, a.lastHistory
		a.mu.Unlock()
		if (got && time.Since(lastAt) > 20*time.Second) || time.Since(start) > 4*time.Minute {
			break
		}
	}
	a.flush(ctx)
	a.cli.Disconnect()
	os.Remove(socketPath())
	if err := exec.Command("systemctl", "--user", "start", "whatsapp").Run(); err != nil {
		die("history saved, but the service did not start: %v", err)
	}
	fmt.Println("Done. The daemon is running.")
}

func askPasskey(key *types.WebAuthnPublicKey) (*types.WebAuthnResponse, error) {
	options, err := json.Marshal(key)
	if err != nil {
		return nil, err
	}
	fmt.Printf(`
This account needs its passkey to link a new device.
Open https://web.whatsapp.com in a browser, open the developer console and run:

  const opts = PublicKeyCredential.parseRequestOptionsFromJSON(%s);
  const cred = await navigator.credentials.get({ publicKey: opts });
  console.log(JSON.stringify(cred.toJSON()));

Approve the prompt, then paste the JSON line it prints here:
`, options)
	reader := bufio.NewReader(os.Stdin)
	var buf strings.Builder
	for {
		line, err := reader.ReadString('\n')
		buf.WriteString(line)
		text := strings.TrimSpace(buf.String())
		if text != "" && json.Valid([]byte(text)) {
			var resp types.WebAuthnResponse
			if err := json.Unmarshal([]byte(text), &resp); err != nil {
				return nil, err
			}
			return &resp, nil
		}
		if err != nil {
			return nil, fmt.Errorf("no passkey response")
		}
	}
}
