package main

import (
	"bufio"
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"net"
	"os"
	"path/filepath"
	"strings"
	"time"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"google.golang.org/protobuf/proto"
)

func (a *App) listen(ctx context.Context) {
	path := socketPath()
	os.Remove(path)
	ln, err := net.Listen("unix", path)
	if err != nil {
		die("socket: %v", err)
	}
	os.Chmod(path, 0o600)
	for {
		conn, err := ln.Accept()
		if err != nil {
			continue
		}
		go a.serve(ctx, conn)
	}
}

func (a *App) serve(ctx context.Context, conn net.Conn) {
	defer conn.Close()
	var req request
	if err := json.NewDecoder(bufio.NewReader(conn)).Decode(&req); err != nil {
		return
	}
	resp := response{OK: true}
	path, err := a.do(ctx, req)
	if err != nil {
		resp = response{Error: err.Error()}
	}
	resp.Path = path
	json.NewEncoder(conn).Encode(resp)
}

func (a *App) do(ctx context.Context, req request) (string, error) {
	if req.Op == "logout" {
		err := a.cli.Logout(ctx)
		if err == nil {
			go func() {
				time.Sleep(200 * time.Millisecond)
				os.Exit(0)
			}()
		}
		return "", err
	}
	chat, err := types.ParseJID(req.Chat)
	if err != nil || skip(chat) {
		return "", fmt.Errorf("bad chat %q", req.Chat)
	}
	switch req.Op {
	case "send":
		return "", a.send(ctx, chat, req.Text, req.Quote)
	case "file":
		return "", a.sendFile(ctx, chat, req.Path, req.As, req.Quote)
	case "open":
		go a.prefetch(context.Background(), chat.String())
		return "", a.markRead(ctx, chat)
	case "fetch":
		return a.fetch(ctx, chat.String(), req.ID)
	case "save":
		return a.save(ctx, chat.String(), req.ID)
	}
	return "", fmt.Errorf("unknown op %q", req.Op)
}

func (a *App) send(ctx context.Context, chat types.JID, text, quoteID string) error {
	text = strings.TrimSpace(text)
	if text == "" {
		return errors.New("empty message")
	}
	if a.cli.Store.ID == nil {
		return errors.New("not linked")
	}
	id := a.cli.GenerateMessageID()
	quote, quoteSender, quoteText := a.contextFor(chat, quoteID)
	if err := a.record(chat, id, "text", text, "", "", 0, "", quoteSender, quoteText); err != nil {
		return err
	}
	msg := &waE2E.Message{Conversation: proto.String(text)}
	if quote != nil {
		msg = &waE2E.Message{ExtendedTextMessage: &waE2E.ExtendedTextMessage{Text: proto.String(text), ContextInfo: quote}}
	}
	return a.deliver(ctx, chat, id, msg)
}

func (a *App) record(chat types.JID, id, kind, text, name, mimeType string, size int64, path, quoteSender, quoteText string) error {
	me := a.cli.Store.ID.ToNonAD().String()
	now := time.Now().Unix()
	_, err := a.db.Exec(`INSERT INTO messages
		(chat, id, sender, sender_raw, from_me, ts, kind, text, file_name, mime, size, path, quote_sender, quote_text, status)
		VALUES (?, ?, ?, ?, 1, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending')`,
		chat.String(), id, me, me, now, kind, text, name, mimeType, size, path, quoteSender, quoteText)
	if err != nil {
		return err
	}
	a.upsertChat(chat.String(), "", now)
	a.touch(chat.String())
	return nil
}

func (a *App) deliver(ctx context.Context, chat types.JID, id string, msg *waE2E.Message) error {
	_, err := a.cli.SendMessage(ctx, chat, msg, whatsmeow.SendRequestExtra{ID: id})
	a.settle(chat, id, err)
	return err
}

func (a *App) settle(chat types.JID, id string, err error) {
	status := "sent"
	if err != nil {
		status = "failed"
	}
	a.db.Exec(`UPDATE messages SET status = ? WHERE chat = ? AND id = ? AND status = 'pending'`, status, chat.String(), id)
	a.touch(chat.String())
}

func (a *App) contextFor(chat types.JID, id string) (*waE2E.ContextInfo, string, string) {
	if id == "" {
		return nil, "", ""
	}
	var sender, kind, text, name string
	var fromMe bool
	var raw []byte
	err := a.db.QueryRow(`SELECT sender_raw, from_me, kind, text, file_name, raw FROM messages
		WHERE chat = ? AND id = ? AND deleted = 0`, chat.String(), id).Scan(&sender, &fromMe, &kind, &text, &name, &raw)
	if err != nil {
		return nil, "", ""
	}
	quoted := &waE2E.Message{}
	if raw == nil || proto.Unmarshal(raw, quoted) != nil {
		quoted = &waE2E.Message{Conversation: proto.String(text)}
	}
	if fromMe {
		sender = a.cli.Store.ID.ToNonAD().String()
	}
	return &waE2E.ContextInfo{
		StanzaID:      proto.String(id),
		Participant:   proto.String(sender),
		QuotedMessage: quoted,
	}, sender, summary(kind, text, name)
}

func (a *App) markRead(ctx context.Context, chat types.JID) error {
	var unread int
	a.db.QueryRow(`SELECT unread FROM chats WHERE jid = ?`, chat.String()).Scan(&unread)
	if unread == 0 {
		return nil
	}
	rows, err := a.db.Query(`SELECT id, sender_raw, ts FROM messages
		WHERE chat = ? AND from_me = 0 ORDER BY ts DESC LIMIT ?`, chat.String(), unread)
	if err != nil {
		return err
	}
	bySender := map[string][]types.MessageID{}
	var newest int64
	for rows.Next() {
		var id, sender string
		var ts int64
		if rows.Scan(&id, &sender, &ts) == nil {
			bySender[sender] = append(bySender[sender], id)
			newest = max(newest, ts)
		}
	}
	rows.Close()
	for sender, ids := range bySender {
		who := types.EmptyJID
		if chat.Server == types.GroupServer {
			who, _ = types.ParseJID(sender)
		}
		if err := a.cli.MarkRead(ctx, ids, time.Unix(newest, 0), chat, who); err != nil {
			return err
		}
	}
	a.db.Exec(`UPDATE chats SET unread = 0 WHERE jid = ?`, chat.String())
	a.touch()
	return nil
}

func (a *App) prefetch(ctx context.Context, chat string) {
	rows, err := a.db.Query(`SELECT id FROM messages
		WHERE chat = ? AND kind = 'sticker' AND path = '' AND deleted = 0 AND raw IS NOT NULL
		ORDER BY ts DESC LIMIT 40`, chat)
	if err != nil {
		return
	}
	ids := []string{}
	for rows.Next() {
		var id string
		if rows.Scan(&id) == nil {
			ids = append(ids, id)
		}
	}
	rows.Close()
	for _, id := range ids {
		a.fetch(ctx, chat, id)
	}
}

var extensions = map[string]string{
	"image/jpeg":      ".jpg",
	"image/png":       ".png",
	"image/webp":      ".webp",
	"image/gif":       ".gif",
	"video/mp4":       ".mp4",
	"audio/ogg":       ".ogg",
	"audio/mpeg":      ".mp3",
	"audio/mp4":       ".m4a",
	"application/pdf": ".pdf",
}

func mediaPath(chat, id, kind, name, mimeType string) string {
	jid, _ := types.ParseJID(chat)
	dir := filepath.Join(mediaDir, jid.User)
	name = strings.ReplaceAll(filepath.Base(name), string(filepath.Separator), "_")
	if kind == "document" && name != "" && name != "." && name != ".." {
		return filepath.Join(dir, id, name)
	}
	ext, ok := extensions[strings.TrimSpace(strings.Split(mimeType, ";")[0])]
	if !ok {
		ext = ".bin"
	}
	return filepath.Join(dir, id+ext)
}

func (a *App) fetch(ctx context.Context, chat, id string) (string, error) {
	key := chat + "/" + id
	a.mu.Lock()
	busy := a.fetching[key]
	a.fetching[key] = true
	a.mu.Unlock()
	if busy {
		return "", errors.New("already downloading")
	}
	defer func() {
		a.mu.Lock()
		delete(a.fetching, key)
		a.mu.Unlock()
	}()

	var kind, name, mimeType, path string
	var raw []byte
	err := a.db.QueryRow(`SELECT kind, file_name, mime, path, raw FROM messages WHERE chat = ? AND id = ?`, chat, id).
		Scan(&kind, &name, &mimeType, &path, &raw)
	if err != nil {
		return "", fmt.Errorf("no such message: %w", err)
	}
	if path != "" {
		if _, err := os.Stat(path); err == nil {
			return path, nil
		}
	}
	if raw == nil {
		return "", errors.New("message has no media")
	}
	msg := &waE2E.Message{}
	if err := proto.Unmarshal(raw, msg); err != nil {
		return "", err
	}
	data, err := a.cli.DownloadAny(ctx, msg)
	if err != nil {
		return "", fmt.Errorf("download: %w", err)
	}
	path = mediaPath(chat, id, kind, name, mimeType)
	if err := os.MkdirAll(filepath.Dir(path), 0o700); err != nil {
		return "", err
	}
	tmp := path + ".part"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return "", err
	}
	if err := os.Rename(tmp, path); err != nil {
		return "", err
	}
	a.db.Exec(`UPDATE messages SET path = ? WHERE chat = ? AND id = ?`, path, chat, id)
	a.touch(chat)
	return path, nil
}

func (a *App) save(ctx context.Context, chat, id string) (string, error) {
	path, err := a.fetch(ctx, chat, id)
	if err != nil {
		return "", err
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return "", err
	}
	dir := filepath.Join(home(), "Downloads")
	if err := os.MkdirAll(dir, 0o755); err != nil {
		return "", err
	}
	base := filepath.Base(path)
	ext := filepath.Ext(base)
	stem := strings.TrimSuffix(base, ext)
	dest := filepath.Join(dir, base)
	for n := 2; ; n++ {
		if _, err := os.Stat(dest); errors.Is(err, os.ErrNotExist) {
			break
		}
		dest = filepath.Join(dir, fmt.Sprintf("%s (%d)%s", stem, n, ext))
	}
	if err := os.WriteFile(dest, data, 0o644); err != nil {
		return "", err
	}
	return dest, nil
}
