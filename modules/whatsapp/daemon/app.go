package main

import (
	"context"
	"database/sql"
	"fmt"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strings"
	"sync"
	"time"

	_ "github.com/mattn/go-sqlite3"
	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waCompanionReg"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/proto/waWeb"
	"go.mau.fi/whatsmeow/store"
	"go.mau.fi/whatsmeow/store/sqlstore"
	"go.mau.fi/whatsmeow/types"
	"go.mau.fi/whatsmeow/types/events"
	waLog "go.mau.fi/whatsmeow/util/log"
	"google.golang.org/protobuf/proto"
)

const keep = 200

const schema = `
CREATE TABLE IF NOT EXISTS chats (
	jid TEXT PRIMARY KEY,
	name TEXT NOT NULL DEFAULT '',
	unread INTEGER NOT NULL DEFAULT 0,
	ts INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS messages (
	chat TEXT NOT NULL,
	id TEXT NOT NULL,
	sender TEXT NOT NULL,
	sender_raw TEXT NOT NULL,
	from_me INTEGER NOT NULL,
	ts INTEGER NOT NULL,
	kind TEXT NOT NULL,
	text TEXT NOT NULL,
	file_name TEXT NOT NULL DEFAULT '',
	mime TEXT NOT NULL DEFAULT '',
	size INTEGER NOT NULL DEFAULT 0,
	raw BLOB,
	path TEXT NOT NULL DEFAULT '',
	quote_sender TEXT NOT NULL DEFAULT '',
	quote_text TEXT NOT NULL DEFAULT '',
	status TEXT NOT NULL DEFAULT '',
	edited INTEGER NOT NULL DEFAULT 0,
	deleted INTEGER NOT NULL DEFAULT 0,
	PRIMARY KEY (chat, id)
);
CREATE INDEX IF NOT EXISTS messages_chat_ts ON messages (chat, ts);
`

type App struct {
	cli *whatsmeow.Client
	db  *sql.DB

	mu        sync.Mutex
	dirty     map[string]bool
	listDirty bool
	state     string
	kick      chan struct{}

	offline     bool
	missed      map[string]int
	asked       map[string]bool
	fetching    map[string]bool
	gotHistory  bool
	lastHistory time.Time
}

func open(ctx context.Context) *App {
	for _, dir := range []string{stateDir, filepath.Join(stateDir, "chat"), mediaDir} {
		if err := os.MkdirAll(dir, 0o700); err != nil {
			die("%v", err)
		}
	}
	if version, err := whatsmeow.GetLatestVersion(ctx, http.DefaultClient); err == nil {
		store.SetWAVersion(*version)
	}
	store.SetOSInfo("Quickshell", [3]uint32{1, 0, 0})
	store.DeviceProps.PlatformType = waCompanionReg.DeviceProps_DESKTOP.Enum()

	session := filepath.Join(stateDir, "session.db")
	container, err := sqlstore.New(ctx, "sqlite3", "file:"+session+"?_foreign_keys=on&_busy_timeout=5000", waLog.Stdout("store", "WARN", true))
	if err != nil {
		die("session store: %v", err)
	}
	device, err := container.GetFirstDevice(ctx)
	if err != nil {
		die("session store: %v", err)
	}
	db, err := sql.Open("sqlite3", "file:"+filepath.Join(stateDir, "messages.db")+"?_busy_timeout=5000&_journal_mode=WAL&_secure_delete=on")
	if err != nil {
		die("message store: %v", err)
	}
	if _, err := db.Exec(schema); err != nil {
		die("message store: %v", err)
	}
	app := &App{
		cli:      whatsmeow.NewClient(device, waLog.Stdout("client", "WARN", true)),
		db:       db,
		dirty:    map[string]bool{},
		state:    "connecting",
		kick:     make(chan struct{}, 1),
		missed:   map[string]int{},
		asked:    map[string]bool{},
		fetching: map[string]bool{},
	}
	app.cli.AddEventHandler(app.handle)
	return app
}

func (a *App) touch(chats ...string) {
	a.mu.Lock()
	for _, chat := range chats {
		a.dirty[chat] = true
	}
	a.listDirty = true
	a.mu.Unlock()
	select {
	case a.kick <- struct{}{}:
	default:
	}
}

func (a *App) prune(chat string) {
	a.db.Exec(`DELETE FROM messages WHERE chat = ? AND id NOT IN
		(SELECT id FROM messages WHERE chat = ? ORDER BY ts DESC LIMIT ?)`, chat, chat, keep)
}

func (a *App) compact() {
	rows, err := a.db.Query(`SELECT DISTINCT chat FROM messages`)
	if err != nil {
		return
	}
	chats := []string{}
	for rows.Next() {
		var chat string
		if rows.Scan(&chat) == nil {
			chats = append(chats, chat)
		}
	}
	rows.Close()
	for _, chat := range chats {
		a.prune(chat)
	}
	a.db.Exec(`VACUUM`)
	a.db.Exec(`PRAGMA wal_checkpoint(TRUNCATE)`)
}

func (a *App) touchAll() {
	rows, err := a.db.Query(`SELECT jid FROM chats`)
	if err != nil {
		return
	}
	chats := []string{}
	for rows.Next() {
		var jid string
		if rows.Scan(&jid) == nil {
			chats = append(chats, jid)
		}
	}
	rows.Close()
	a.touch(chats...)
}

func (a *App) setState(state string) {
	a.mu.Lock()
	a.state = state
	a.mu.Unlock()
	a.touch()
}

func (a *App) handle(evt any) {
	ctx := context.Background()
	switch e := evt.(type) {
	case *events.Message:
		a.message(ctx, e, true)
	case *events.HistorySync:
		a.history(ctx, e)
	case *events.Receipt:
		a.receipt(ctx, e)
	case *events.MarkChatAsRead:
		chat := a.normalize(ctx, e.JID)
		unread := 0
		if !e.Action.GetRead() {
			unread = 1
		}
		a.db.Exec(`UPDATE chats SET unread = ? WHERE jid = ?`, unread, chat.String())
		a.touch()
	case *events.Mute, *events.Archive, *events.Pin, *events.Contact, *events.PushName:
		a.touch()
	case *events.GroupInfo:
		if e.Name != nil {
			a.db.Exec(`UPDATE chats SET name = ? WHERE jid = ?`, e.Name.Name, e.JID.String())
			a.touch()
		}
	case *events.JoinedGroup:
		a.upsertChat(e.JID.String(), e.GroupInfo.Name, 0)
		a.touch()
	case *events.Connected:
		a.setState("connected")
	case *events.Disconnected:
		a.setState("connecting")
	case *events.OfflineSyncPreview:
		a.mu.Lock()
		a.offline = e.Messages > 0
		a.mu.Unlock()
	case *events.OfflineSyncCompleted:
		a.summarize(ctx)
	case *events.ClientOutdated:
		a.setState("outdated")
	case *events.StreamReplaced:
		a.setState("replaced")
		a.flush(ctx)
		os.Exit(1)
	case *events.LoggedOut:
		a.setState("logged-out")
		a.flush(ctx)
		os.Exit(0)
	}
}

func (a *App) normalize(ctx context.Context, jid types.JID) types.JID {
	jid = jid.ToNonAD()
	if jid.Server == types.HiddenUserServer {
		if pn, err := a.cli.Store.LIDs.GetPNForLID(ctx, jid); err == nil && !pn.IsEmpty() {
			return pn.ToNonAD()
		}
	}
	return jid
}

func skip(chat types.JID) bool {
	return chat.IsEmpty() || chat.Server == types.BroadcastServer || chat.Server == types.NewsletterServer
}

func (a *App) upsertChat(jid, name string, ts int64) {
	a.db.Exec(`INSERT INTO chats (jid, name, ts) VALUES (?, ?, ?)
		ON CONFLICT (jid) DO UPDATE SET
			name = CASE WHEN excluded.name != '' THEN excluded.name ELSE chats.name END,
			ts = max(chats.ts, excluded.ts)`, jid, name, ts)
}

type parsed struct {
	kind, text, name, mime string
	size                   uint64
	ctx                    *waE2E.ContextInfo
}

func describe(m *waE2E.Message) parsed {
	switch {
	case m.GetConversation() != "":
		return parsed{kind: "text", text: m.GetConversation()}
	case m.GetExtendedTextMessage() != nil:
		x := m.GetExtendedTextMessage()
		return parsed{kind: "text", text: x.GetText(), ctx: x.GetContextInfo()}
	case m.GetImageMessage() != nil:
		x := m.GetImageMessage()
		return parsed{kind: "image", text: x.GetCaption(), mime: x.GetMimetype(), size: x.GetFileLength(), ctx: x.GetContextInfo()}
	case m.GetStickerMessage() != nil:
		x := m.GetStickerMessage()
		return parsed{kind: "sticker", mime: x.GetMimetype(), size: x.GetFileLength(), ctx: x.GetContextInfo()}
	case m.GetVideoMessage() != nil:
		x := m.GetVideoMessage()
		return parsed{kind: "video", text: x.GetCaption(), mime: x.GetMimetype(), size: x.GetFileLength(), ctx: x.GetContextInfo()}
	case m.GetAudioMessage() != nil:
		x := m.GetAudioMessage()
		return parsed{kind: "audio", mime: x.GetMimetype(), size: x.GetFileLength(), ctx: x.GetContextInfo()}
	case m.GetDocumentMessage() != nil:
		x := m.GetDocumentMessage()
		return parsed{kind: "document", text: x.GetCaption(), name: x.GetFileName(), mime: x.GetMimetype(), size: x.GetFileLength(), ctx: x.GetContextInfo()}
	case m.GetLocationMessage() != nil:
		x := m.GetLocationMessage()
		return parsed{kind: "location", text: strings.TrimSpace(fmt.Sprintf("%s %.5f, %.5f", x.GetName(), x.GetDegreesLatitude(), x.GetDegreesLongitude()))}
	case m.GetContactMessage() != nil:
		return parsed{kind: "contact", text: m.GetContactMessage().GetDisplayName()}
	case m.GetPollCreationMessage() != nil:
		return parsed{kind: "poll", text: m.GetPollCreationMessage().GetName()}
	case m.GetPollCreationMessageV3() != nil:
		return parsed{kind: "poll", text: m.GetPollCreationMessageV3().GetName()}
	}
	return parsed{}
}

func summary(kind, text, name string) string {
	label := map[string]string{
		"image":    "Photo",
		"sticker":  "Sticker",
		"video":    "Video",
		"audio":    "Voice message",
		"document": "Document",
		"location": "Location",
		"contact":  "Contact",
		"poll":     "Poll",
	}[kind]
	if kind == "document" && name != "" {
		label = name
	}
	switch {
	case label == "":
		return text
	case text == "":
		return label
	}
	return label + ": " + text
}

func (a *App) message(ctx context.Context, e *events.Message, live bool) {
	chat := a.normalize(ctx, e.Info.Chat)
	if skip(chat) {
		return
	}
	if p := e.Message.GetProtocolMessage(); p != nil {
		id := p.GetKey().GetID()
		switch p.GetType() {
		case waE2E.ProtocolMessage_REVOKE:
			a.db.Exec(`UPDATE messages SET deleted = 1, text = '', raw = NULL WHERE chat = ? AND id = ?`, chat.String(), id)
		case waE2E.ProtocolMessage_MESSAGE_EDIT:
			a.db.Exec(`UPDATE messages SET edited = 1, text = ? WHERE chat = ? AND id = ?`, describe(p.GetEditedMessage()).text, chat.String(), id)
		}
		a.touch(chat.String())
		return
	}
	m := describe(e.Message)
	if m.kind == "" {
		return
	}
	var quoteSender, quoteText string
	if q := m.ctx.GetQuotedMessage(); q != nil {
		quoted := describe(q)
		quoteSender = m.ctx.GetParticipant()
		quoteText = summary(quoted.kind, quoted.text, quoted.name)
	}
	var raw []byte
	if m.kind != "text" {
		raw, _ = proto.Marshal(e.Message)
	}
	status := ""
	if e.Info.IsFromMe {
		status = "sent"
		if e.SourceWebMsg != nil {
			status = webStatus(e.SourceWebMsg.GetStatus())
		}
	}
	sender := a.normalize(ctx, e.Info.Sender)
	ts := e.Info.Timestamp.Unix()
	res, err := a.db.Exec(`INSERT OR IGNORE INTO messages
		(chat, id, sender, sender_raw, from_me, ts, kind, text, file_name, mime, size, raw, quote_sender, quote_text, status)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
		chat.String(), e.Info.ID, sender.String(), e.Info.Sender.ToNonAD().String(), e.Info.IsFromMe, ts,
		m.kind, m.text, m.name, m.mime, m.size, raw, quoteSender, quoteText, status)
	if err != nil {
		fmt.Fprintf(os.Stderr, "store message: %v\n", err)
		return
	}
	a.upsertChat(chat.String(), "", ts)
	if added, _ := res.RowsAffected(); added == 1 && live {
		if !e.Info.IsFromMe {
			a.db.Exec(`UPDATE chats SET unread = unread + 1 WHERE jid = ?`, chat.String())
			a.alert(ctx, chat, sender, summary(m.kind, m.text, m.name))
		}
		if m.kind == "sticker" && m.size < 4<<20 {
			go a.fetch(context.Background(), chat.String(), e.Info.ID)
		}
	}
	a.touch(chat.String())
}

func webStatus(s waWeb.WebMessageInfo_Status) string {
	switch s {
	case waWeb.WebMessageInfo_READ, waWeb.WebMessageInfo_PLAYED:
		return "read"
	case waWeb.WebMessageInfo_DELIVERY_ACK:
		return "delivered"
	}
	return "sent"
}

func (a *App) history(ctx context.Context, e *events.HistorySync) {
	for _, conv := range e.Data.GetConversations() {
		jid, err := types.ParseJID(conv.GetID())
		if err != nil {
			continue
		}
		chat := a.normalize(ctx, jid)
		if skip(chat) {
			continue
		}
		a.upsertChat(chat.String(), conv.GetName(), int64(conv.GetConversationTimestamp()))
		for _, item := range conv.GetMessages() {
			if evt, err := a.cli.ParseWebMessage(jid, item.GetMessage()); err == nil {
				a.message(ctx, evt, false)
			}
		}
		a.db.Exec(`UPDATE chats SET unread = ? WHERE jid = ?`, conv.GetUnreadCount(), chat.String())
		a.touch(chat.String())
	}
	a.mu.Lock()
	a.gotHistory = true
	a.lastHistory = time.Now()
	a.mu.Unlock()
}

func (a *App) receipt(ctx context.Context, e *events.Receipt) {
	status := ""
	switch e.Type {
	case types.ReceiptTypeDelivered:
		status = "delivered"
	case types.ReceiptTypeRead, types.ReceiptTypePlayed:
		status = "read"
	default:
		return
	}
	chat := a.normalize(ctx, e.Chat).String()
	for _, id := range e.MessageIDs {
		a.db.Exec(`UPDATE messages SET status = ? WHERE chat = ? AND id = ? AND from_me = 1 AND status != 'read'`, status, chat, id)
	}
	a.touch(chat)
}

func (a *App) muted(ctx context.Context, chat types.JID) bool {
	settings, err := a.cli.Store.ChatSettings.GetChatSettings(ctx, chat)
	return err == nil && settings.MutedUntil.After(time.Now())
}

func (a *App) alert(ctx context.Context, chat, sender types.JID, body string) {
	if a.muted(ctx, chat) {
		return
	}
	a.mu.Lock()
	offline := a.offline
	if offline {
		a.missed[chat.String()]++
	}
	a.mu.Unlock()
	if offline {
		return
	}
	title := a.nameOf(ctx, chat)
	if chat.Server == types.GroupServer {
		body = a.nameOf(ctx, sender) + ": " + body
	}
	notify(title, body)
}

func (a *App) summarize(ctx context.Context) {
	a.mu.Lock()
	missed := a.missed
	a.missed = map[string]int{}
	a.offline = false
	a.mu.Unlock()
	if len(missed) == 0 {
		return
	}
	total := 0
	names := []string{}
	for chat, n := range missed {
		total += n
		jid, _ := types.ParseJID(chat)
		names = append(names, a.nameOf(ctx, jid))
	}
	notify(fmt.Sprintf("%d new messages", total), strings.Join(names, ", "))
}

func notify(title, body string) {
	cmd := exec.Command("notify-send", "--app-name=WhatsApp", "--icon=whatsapp", title, body)
	if cmd.Start() == nil {
		go cmd.Wait()
	}
}

func (a *App) self(jid types.JID) bool {
	id := a.cli.Store.ID
	if id == nil {
		return false
	}
	return jid.User == id.User || (!a.cli.Store.LID.IsEmpty() && jid.User == a.cli.Store.LID.User)
}

func (a *App) nameOf(ctx context.Context, jid types.JID) string {
	if jid.Server == types.GroupServer {
		var name string
		a.db.QueryRow(`SELECT name FROM chats WHERE jid = ?`, jid.String()).Scan(&name)
		if name == "" {
			a.askGroup(jid)
			return jid.User
		}
		return name
	}
	if a.self(jid) {
		return "You"
	}
	contact, _ := a.cli.Store.Contacts.GetContact(ctx, jid)
	if !contact.Found && jid.Server == types.HiddenUserServer {
		if pn, err := a.cli.Store.LIDs.GetPNForLID(ctx, jid); err == nil && !pn.IsEmpty() {
			jid = pn
			contact, _ = a.cli.Store.Contacts.GetContact(ctx, pn)
		}
	}
	for _, name := range []string{contact.FullName, contact.FirstName, contact.PushName, contact.BusinessName} {
		if name != "" {
			return name
		}
	}
	if jid.Server == types.DefaultUserServer {
		return "+" + jid.User
	}
	if contact.RedactedPhone != "" {
		return contact.RedactedPhone
	}
	return jid.User
}

func (a *App) askGroup(jid types.JID) {
	if !a.cli.IsConnected() {
		return
	}
	a.mu.Lock()
	asked := a.asked[jid.String()]
	a.asked[jid.String()] = true
	a.mu.Unlock()
	if asked {
		return
	}
	go func() {
		info, err := a.cli.GetGroupInfo(context.Background(), jid)
		if err == nil && info.Name != "" {
			a.upsertChat(jid.String(), info.Name, 0)
			a.touch(jid.String())
		}
	}()
}
