package main

import (
	"context"
	"encoding/base64"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"time"

	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"google.golang.org/protobuf/proto"
)

type last struct {
	Me      bool   `json:"me"`
	Who     string `json:"who"`
	Kind    string `json:"kind"`
	Text    string `json:"text"`
	Deleted bool   `json:"deleted"`
}

type chatRow struct {
	JID      string `json:"jid"`
	Name     string `json:"name"`
	Group    bool   `json:"group"`
	Unread   int    `json:"unread"`
	TS       int64  `json:"ts"`
	Muted    bool   `json:"muted"`
	Pinned   bool   `json:"pinned"`
	Archived bool   `json:"archived"`
	Last     *last  `json:"last"`
}

type quote struct {
	Who  string `json:"who"`
	Text string `json:"text"`
}

type messageRow struct {
	ID      string `json:"id"`
	Me      bool   `json:"me"`
	Who     string `json:"who"`
	TS      int64  `json:"ts"`
	Kind    string `json:"kind"`
	Text    string `json:"text"`
	File    string `json:"file"`
	Name    string `json:"name"`
	Mime    string `json:"mime"`
	Size    int64  `json:"size"`
	Status  string `json:"status"`
	Edited  bool   `json:"edited"`
	Deleted bool   `json:"deleted"`
	Quote   *quote `json:"quote"`
	Thumb   string `json:"thumb"`
	Width   uint32 `json:"w"`
	Height  uint32 `json:"h"`
}

func (a *App) flusher(ctx context.Context) {
	for range a.kick {
		time.Sleep(40 * time.Millisecond)
		a.flush(ctx)
	}
}

func (a *App) flush(ctx context.Context) {
	a.mu.Lock()
	dirty := a.dirty
	list := a.listDirty
	state := a.state
	a.dirty = map[string]bool{}
	a.listDirty = false
	a.mu.Unlock()
	for chat := range dirty {
		a.prune(chat)
		if err := a.writeChat(ctx, chat); err != nil {
			fmt.Fprintf(os.Stderr, "write %s: %v\n", chat, err)
		}
	}
	if list {
		if err := a.writeList(ctx, state); err != nil {
			fmt.Fprintf(os.Stderr, "write chats: %v\n", err)
		}
	}
}

func writeJSON(path string, value any) error {
	data, err := json.Marshal(value)
	if err != nil {
		return err
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o600); err != nil {
		return err
	}
	return os.Rename(tmp, path)
}

func (a *App) writeList(ctx context.Context, state string) error {
	rows, err := a.db.Query(`SELECT jid, name, unread, ts FROM chats
		WHERE EXISTS (SELECT 1 FROM messages WHERE messages.chat = chats.jid)`)
	if err != nil {
		return err
	}
	chats := []chatRow{}
	for rows.Next() {
		var c chatRow
		if err := rows.Scan(&c.JID, &c.Name, &c.Unread, &c.TS); err != nil {
			rows.Close()
			return err
		}
		chats = append(chats, c)
	}
	rows.Close()
	for i := range chats {
		c := &chats[i]
		jid, _ := types.ParseJID(c.JID)
		c.Group = jid.Server == types.GroupServer
		if c.Name == "" || !c.Group {
			c.Name = a.nameOf(ctx, jid)
		}
		if settings, err := a.cli.Store.ChatSettings.GetChatSettings(ctx, jid); err == nil {
			c.Muted = settings.MutedUntil.After(time.Now())
			c.Pinned = settings.Pinned
			c.Archived = settings.Archived
		}
		var l last
		var sender string
		err := a.db.QueryRow(`SELECT from_me, sender, kind, text, file_name, deleted FROM messages
			WHERE chat = ? ORDER BY ts DESC LIMIT 1`, c.JID).Scan(&l.Me, &sender, &l.Kind, &l.Text, new(string), &l.Deleted)
		if err == nil {
			if c.Group && !l.Me {
				who, _ := types.ParseJID(sender)
				l.Who = a.nameOf(ctx, who)
			}
			c.Last = &l
		}
		c.TS *= 1000
	}
	sort.SliceStable(chats, func(i, j int) bool {
		if chats[i].Pinned != chats[j].Pinned {
			return chats[i].Pinned
		}
		return chats[i].TS > chats[j].TS
	})
	me := ""
	if a.cli.Store.ID != nil {
		me = "+" + a.cli.Store.ID.User
	}
	return writeJSON(filepath.Join(stateDir, "chats.json"), map[string]any{
		"state":   state,
		"me":      me,
		"updated": time.Now().UnixMilli(),
		"chats":   chats,
	})
}

func (a *App) writeChat(ctx context.Context, chat string) error {
	rows, err := a.db.Query(`SELECT id, from_me, sender, ts, kind, text, path, file_name, mime, size,
			status, edited, deleted, quote_sender, quote_text, raw
		FROM messages WHERE chat = ? ORDER BY ts DESC LIMIT ?`, chat, keep)
	if err != nil {
		return err
	}
	defer rows.Close()
	jid, _ := types.ParseJID(chat)
	group := jid.Server == types.GroupServer
	names := map[string]string{}
	name := func(s string) string {
		if s == "" {
			return ""
		}
		if n, ok := names[s]; ok {
			return n
		}
		who, _ := types.ParseJID(s)
		names[s] = a.nameOf(ctx, a.normalize(ctx, who))
		return names[s]
	}
	messages := []messageRow{}
	for rows.Next() {
		var m messageRow
		var sender, quoteSender, quoteText string
		var raw []byte
		if err := rows.Scan(&m.ID, &m.Me, &sender, &m.TS, &m.Kind, &m.Text, &m.File, &m.Name, &m.Mime, &m.Size,
			&m.Status, &m.Edited, &m.Deleted, &quoteSender, &quoteText, &raw); err != nil {
			return err
		}
		m.Thumb, m.Width, m.Height = preview(m.Kind, raw)
		m.TS *= 1000
		if group && !m.Me {
			m.Who = name(sender)
		}
		if m.File != "" {
			if _, err := os.Stat(m.File); err != nil {
				m.File = ""
			}
		}
		if quoteText != "" || quoteSender != "" {
			m.Quote = &quote{Who: name(quoteSender), Text: quoteText}
		}
		messages = append(messages, m)
	}
	for i, j := 0, len(messages)-1; i < j; i, j = i+1, j-1 {
		messages[i], messages[j] = messages[j], messages[i]
	}
	return writeJSON(filepath.Join(stateDir, "chat", chat+".json"), map[string]any{
		"jid":      chat,
		"name":     a.nameOf(ctx, jid),
		"group":    group,
		"messages": messages,
	})
}

func preview(kind string, raw []byte) (string, uint32, uint32) {
	if raw == nil || (kind != "image" && kind != "video") {
		return "", 0, 0
	}
	msg := &waE2E.Message{}
	if proto.Unmarshal(raw, msg) != nil {
		return "", 0, 0
	}
	thumb, w, h := msg.GetImageMessage().GetJPEGThumbnail(), msg.GetImageMessage().GetWidth(), msg.GetImageMessage().GetHeight()
	if kind == "video" {
		thumb, w, h = msg.GetVideoMessage().GetJPEGThumbnail(), msg.GetVideoMessage().GetWidth(), msg.GetVideoMessage().GetHeight()
	}
	if len(thumb) == 0 {
		return "", w, h
	}
	return "data:image/jpeg;base64," + base64.StdEncoding.EncodeToString(thumb), w, h
}
