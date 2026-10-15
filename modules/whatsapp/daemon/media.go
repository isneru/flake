package main

import (
	"context"
	"errors"
	"fmt"
	"mime"
	"net/http"
	"os"
	"os/exec"
	"path/filepath"
	"strconv"
	"strings"

	"go.mau.fi/whatsmeow"
	"go.mau.fi/whatsmeow/proto/waE2E"
	"go.mau.fi/whatsmeow/types"
	"google.golang.org/protobuf/proto"
)

const maxUpload = 2 << 30

type outgoing struct {
	kind, name, mime string
	data             []byte
	width, height    uint32
	seconds          uint32
	animated, gif    bool
	thumb            []byte
}

func probe(path, entries string) []string {
	out, err := exec.Command("ffprobe", "-v", "error", "-select_streams", "v:0", "-count_frames",
		"-show_entries", entries, "-of", "csv=p=0", path).Output()
	if err != nil {
		return nil
	}
	return strings.Split(strings.TrimSpace(strings.Split(string(out), "\n")[0]), ",")
}

func frames(path string) int {
	f := probe(path, "stream=nb_read_frames")
	if len(f) == 0 {
		return 1
	}
	n, _ := strconv.Atoi(f[0])
	return max(n, 1)
}

func dimensions(path string) (uint32, uint32) {
	d := probe(path, "stream=width,height")
	if len(d) != 2 {
		return 0, 0
	}
	w, _ := strconv.Atoi(d[0])
	h, _ := strconv.Atoi(d[1])
	return uint32(w), uint32(h)
}

func duration(path string) uint32 {
	out, err := exec.Command("ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path).Output()
	if err != nil {
		return 0
	}
	s, _ := strconv.ParseFloat(strings.TrimSpace(string(out)), 64)
	return uint32(s + 0.5)
}

func ffmpeg(args ...string) error {
	out, err := exec.Command("ffmpeg", append([]string{"-v", "error", "-y"}, args...)...).CombinedOutput()
	if err != nil {
		return fmt.Errorf("ffmpeg: %v: %s", err, strings.TrimSpace(string(out)))
	}
	return nil
}

func thumbnail(path, dir string) []byte {
	out := filepath.Join(dir, "thumb.jpg")
	if ffmpeg("-i", path, "-frames:v", "1", "-vf", "scale=72:-2", "-q:v", "6", out) != nil {
		return nil
	}
	data, _ := os.ReadFile(out)
	return data
}

func sticker(path, dir string) (*outgoing, error) {
	animated := frames(path) > 1
	out := filepath.Join(dir, "sticker.webp")
	frame := "scale=512:512:force_original_aspect_ratio=decrease,format=rgba,pad=512:512:(ow-iw)/2:(oh-ih)/2:color=0x00000000"
	limit := 100 << 10
	rates := []string{""}
	if animated {
		limit = 500 << 10
		rates = []string{"15", "10"}
	}
	for _, fps := range rates {
		for _, quality := range []string{"80", "60", "40", "25", "10"} {
			args := []string{"-i", path, "-an"}
			if animated {
				args = append(args, "-t", "10", "-vf", "fps="+fps+","+frame, "-c:v", "libwebp_anim", "-loop", "0")
			} else {
				args = append(args, "-frames:v", "1", "-vf", frame, "-c:v", "libwebp")
			}
			if err := ffmpeg(append(args, "-quality", quality, out)...); err != nil {
				return nil, err
			}
			data, err := os.ReadFile(out)
			if err != nil {
				return nil, err
			}
			if len(data) <= limit {
				return &outgoing{kind: "sticker", mime: "image/webp", data: data, width: 512, height: 512, animated: animated}, nil
			}
		}
	}
	return nil, fmt.Errorf("could not fit the sticker under %d KB", limit>>10)
}

func photo(path, mimeType, dir string) (*outgoing, error) {
	if mimeType != "image/jpeg" && mimeType != "image/png" {
		if frames(path) > 1 {
			out := filepath.Join(dir, "gif.mp4")
			err := ffmpeg("-i", path, "-an", "-movflags", "faststart", "-pix_fmt", "yuv420p",
				"-vf", "scale=trunc(iw/2)*2:trunc(ih/2)*2", "-c:v", "libx264", out)
			if err != nil {
				return nil, err
			}
			m, err := video(out, dir)
			if m != nil {
				m.gif = true
			}
			return m, err
		}
		out := filepath.Join(dir, "photo.jpg")
		if err := ffmpeg("-i", path, "-frames:v", "1", "-q:v", "3", out); err != nil {
			return nil, err
		}
		path, mimeType = out, "image/jpeg"
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	w, h := dimensions(path)
	return &outgoing{kind: "image", mime: mimeType, data: data, width: w, height: h, thumb: thumbnail(path, dir)}, nil
}

func video(path, dir string) (*outgoing, error) {
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	w, h := dimensions(path)
	return &outgoing{kind: "video", mime: "video/mp4", data: data, width: w, height: h, seconds: duration(path), thumb: thumbnail(path, dir)}, nil
}

func prepare(path, as, dir string) (*outgoing, error) {
	info, err := os.Stat(path)
	if err != nil {
		return nil, err
	}
	if info.IsDir() {
		return nil, errors.New("that is a directory")
	}
	if info.Size() > maxUpload {
		return nil, errors.New("file is larger than 2 GB")
	}
	mimeType := mime.TypeByExtension(strings.ToLower(filepath.Ext(path)))
	if mimeType == "" {
		head := make([]byte, 512)
		f, err := os.Open(path)
		if err != nil {
			return nil, err
		}
		n, _ := f.Read(head)
		f.Close()
		mimeType = http.DetectContentType(head[:n])
	}
	mimeType = strings.TrimSpace(strings.Split(mimeType, ";")[0])
	if as == "auto" {
		switch {
		case strings.HasPrefix(mimeType, "image/"):
			as = "photo"
		case mimeType == "video/mp4":
			as = "video"
		case mimeType == "audio/ogg" || mimeType == "audio/mpeg" || mimeType == "audio/mp4" || mimeType == "audio/aac":
			as = "audio"
		default:
			as = "document"
		}
	}
	switch as {
	case "sticker":
		return sticker(path, dir)
	case "photo":
		return photo(path, mimeType, dir)
	case "video":
		return video(path, dir)
	}
	data, err := os.ReadFile(path)
	if err != nil {
		return nil, err
	}
	if as == "audio" {
		return &outgoing{kind: "audio", mime: mimeType, data: data, seconds: duration(path)}, nil
	}
	return &outgoing{kind: "document", name: filepath.Base(path), mime: mimeType, data: data}, nil
}

func (m *outgoing) build(up whatsmeow.UploadResponse, quote *waE2E.ContextInfo) *waE2E.Message {
	size := proto.Uint64(up.FileLength)
	switch m.kind {
	case "sticker":
		return &waE2E.Message{StickerMessage: &waE2E.StickerMessage{
			URL: proto.String(up.URL), DirectPath: proto.String(up.DirectPath), MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: size,
			Mimetype: proto.String(m.mime), Width: proto.Uint32(m.width), Height: proto.Uint32(m.height),
			IsAnimated: proto.Bool(m.animated), ContextInfo: quote,
		}}
	case "image":
		return &waE2E.Message{ImageMessage: &waE2E.ImageMessage{
			URL: proto.String(up.URL), DirectPath: proto.String(up.DirectPath), MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: size,
			Mimetype: proto.String(m.mime), Width: proto.Uint32(m.width), Height: proto.Uint32(m.height),
			JPEGThumbnail: m.thumb, ContextInfo: quote,
		}}
	case "video":
		return &waE2E.Message{VideoMessage: &waE2E.VideoMessage{
			URL: proto.String(up.URL), DirectPath: proto.String(up.DirectPath), MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: size,
			Mimetype: proto.String(m.mime), Width: proto.Uint32(m.width), Height: proto.Uint32(m.height),
			Seconds: proto.Uint32(m.seconds), GifPlayback: proto.Bool(m.gif), JPEGThumbnail: m.thumb, ContextInfo: quote,
		}}
	case "audio":
		return &waE2E.Message{AudioMessage: &waE2E.AudioMessage{
			URL: proto.String(up.URL), DirectPath: proto.String(up.DirectPath), MediaKey: up.MediaKey,
			FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: size,
			Mimetype: proto.String(m.mime), Seconds: proto.Uint32(m.seconds), ContextInfo: quote,
		}}
	}
	return &waE2E.Message{DocumentMessage: &waE2E.DocumentMessage{
		URL: proto.String(up.URL), DirectPath: proto.String(up.DirectPath), MediaKey: up.MediaKey,
		FileEncSHA256: up.FileEncSHA256, FileSHA256: up.FileSHA256, FileLength: size,
		Mimetype: proto.String(m.mime), FileName: proto.String(m.name), Title: proto.String(m.name), ContextInfo: quote,
	}}
}

func (m *outgoing) mediaType() whatsmeow.MediaType {
	switch m.kind {
	case "image", "sticker":
		return whatsmeow.MediaImage
	case "video":
		return whatsmeow.MediaVideo
	case "audio":
		return whatsmeow.MediaAudio
	}
	return whatsmeow.MediaDocument
}

func (a *App) sendFile(ctx context.Context, chat types.JID, path, as, quoteID string) error {
	if a.cli.Store.ID == nil {
		return errors.New("not linked")
	}
	switch as {
	case "auto", "photo", "document", "sticker":
	default:
		return fmt.Errorf("unknown kind %q", as)
	}
	dir, err := os.MkdirTemp("", "whatsapp-send-")
	if err != nil {
		return err
	}
	defer os.RemoveAll(dir)
	m, err := prepare(path, as, dir)
	if err != nil {
		return err
	}
	id := a.cli.GenerateMessageID()
	local := mediaPath(chat.String(), id, m.kind, m.name, m.mime)
	if err := os.MkdirAll(filepath.Dir(local), 0o700); err != nil {
		return err
	}
	if err := os.WriteFile(local, m.data, 0o600); err != nil {
		return err
	}
	quote, quoteSender, quoteText := a.contextFor(chat, quoteID)
	if err := a.record(chat, id, m.kind, "", m.name, m.mime, int64(len(m.data)), local, quoteSender, quoteText); err != nil {
		return err
	}
	up, err := a.cli.Upload(ctx, m.data, m.mediaType())
	if err != nil {
		a.settle(chat, id, err)
		return fmt.Errorf("upload: %w", err)
	}
	msg := m.build(up, quote)
	if raw, err := proto.Marshal(msg); err == nil {
		a.db.Exec(`UPDATE messages SET raw = ? WHERE chat = ? AND id = ?`, raw, chat.String(), id)
	}
	return a.deliver(ctx, chat, id, msg)
}
