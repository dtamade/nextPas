package main

import (
	"bytes"
	"crypto/sha1"
	"encoding/base64"
	"encoding/binary"
	"fmt"
	"math/rand"
	"mime/multipart"
	"net/http"
	"strings"
	"time"
)

const iterations = 100000

func bench(name string, fn func()) {
	// warmup
	for i := 0; i < 100; i++ {
		fn()
	}
	start := time.Now()
	for i := 0; i < iterations; i++ {
		fn()
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iterations)
	opsPerSec := 1e9 / nsPerOp
	fmt.Printf("  %-40s %10.1f ns/op %14.0f ops/s\n", name, nsPerOp, opsPerSec)
}

// ===== Cookie =====

func benchParseCookieHeader() {
	header := http.Header{}
	header.Set("Cookie", "a=1; b=2; c=3; d=4; e=5")
	req := &http.Request{Header: header}
	_ = req.Cookies()
}

func benchBuildSetCookie() {
	c := &http.Cookie{
		Name:     "session",
		Value:    "abc123def456ghi789",
		Domain:   ".example.com",
		Path:     "/app",
		MaxAge:   86400,
		Secure:   true,
		HttpOnly: true,
		SameSite: http.SameSiteLaxMode,
	}
	_ = c.String()
}

func benchParseCookieHeader10() {
	header := http.Header{}
	header.Set("Cookie", "a=1; b=2; c=3; d=4; e=5; f=6; g=7; h=8; i=9; j=10")
	req := &http.Request{Header: header}
	_ = req.Cookies()
}

// ===== SSE =====

func sseParseAll(input string) int {
	count := 0
	lines := strings.Split(input, "\n")
	hasData := false
	for _, line := range lines {
		if line == "" {
			if hasData {
				count++
				hasData = false
			}
			continue
		}
		if strings.HasPrefix(line, "data:") {
			hasData = true
		}
	}
	return count
}

func benchSseParseEvent() {
	_ = sseParseAll("data: hello\n\n")
}

var sseStream100 string

func initSseStream() {
	var sb strings.Builder
	for i := 1; i <= 100; i++ {
		fmt.Fprintf(&sb, "event: msg\ndata: payload-%d\n\n", i)
	}
	sseStream100 = sb.String()
}

func benchSseParseStream() {
	_ = sseParseAll(sseStream100)
}

func benchSseFeed() {
	// Simulate incremental feed of 10KB
	var sb strings.Builder
	for i := 0; i < 100; i++ {
		sb.WriteString("data: ")
		sb.WriteString(strings.Repeat("x", 90))
		sb.WriteString("\n\n")
	}
	stream := sb.String()
	chunkSize := len(stream) / 10
	// Simulate feeding chunks and parsing
	var full strings.Builder
	for i := 0; i < 10; i++ {
		start := i * chunkSize
		end_ := start + chunkSize
		if end_ > len(stream) {
			end_ = len(stream)
		}
		full.WriteString(stream[start:end_])
	}
	_ = sseParseAll(full.String())
}

// ===== Multipart =====

var multipartBody3 []byte
var multipartBodyLarge []byte

func initMultipart() {
	boundary := "----WebKitFormBoundary7MA4YWxkTrZu0gW"
	var buf bytes.Buffer
	w := multipart.NewWriter(&buf)
	w.SetBoundary(boundary)
	w.WriteField("field1", "value1")
	w.WriteField("field2", "value2")
	part, _ := w.CreateFormFile("file", "test.bin")
	part.Write(bytes.Repeat([]byte("A"), 1024))
	w.Close()
	multipartBody3 = buf.Bytes()

	// Large
	var buf2 bytes.Buffer
	w2 := multipart.NewWriter(&buf2)
	w2.SetBoundary("----Boundary10K")
	part2, _ := w2.CreateFormFile("bigfile", "big.dat")
	part2.Write(bytes.Repeat([]byte("B"), 10240))
	w2.Close()
	multipartBodyLarge = buf2.Bytes()
}

func benchMultipartParse() {
	boundary := "----WebKitFormBoundary7MA4YWxkTrZu0gW"
	r := multipart.NewReader(bytes.NewReader(multipartBody3), boundary)
	for {
		p, err := r.NextPart()
		if err != nil {
			break
		}
		buf := make([]byte, 16384)
		for {
			_, err := p.Read(buf)
			if err != nil {
				break
			}
		}
	}
}

func benchMultipartExtractBoundary() {
	ct := "multipart/form-data; boundary=----WebKitFormBoundary7MA4YWxkTrZu0gW"
	idx := strings.Index(ct, "boundary=")
	if idx >= 0 {
		_ = ct[idx+9:]
	}
}

func benchMultipartLarge() {
	boundary := "----Boundary10K"
	r := multipart.NewReader(bytes.NewReader(multipartBodyLarge), boundary)
	for {
		p, err := r.NextPart()
		if err != nil {
			break
		}
		buf := make([]byte, 16384)
		for {
			_, err := p.Read(buf)
			if err != nil {
				break
			}
		}
	}
}

// ===== WebSocket =====

var wsPayload64 []byte
var wsPayload4K []byte

func initWs() {
	wsPayload64 = make([]byte, 64)
	for i := range wsPayload64 {
		wsPayload64[i] = byte(i % 256)
	}
	wsPayload4K = make([]byte, 4096)
	for i := range wsPayload4K {
		wsPayload4K[i] = byte((i * 7) % 256)
	}
}

func wsEncodeFrame(payload []byte, masked bool) []byte {
	payloadLen := len(payload)
	headerLen := 2
	if payloadLen < 126 {
		// no extended
	} else if payloadLen <= 65535 {
		headerLen += 2
	} else {
		headerLen += 8
	}
	if masked {
		headerLen += 4
	}
	frame := make([]byte, headerLen+payloadLen)
	frame[0] = 0x81 // FIN + TEXT
	if payloadLen < 126 {
		frame[1] = byte(payloadLen)
	} else if payloadLen <= 65535 {
		frame[1] = 126
		binary.BigEndian.PutUint16(frame[2:], uint16(payloadLen))
	} else {
		frame[1] = 127
		binary.BigEndian.PutUint64(frame[2:], uint64(payloadLen))
	}
	if masked {
		frame[1] |= 0x80
		maskKey := [4]byte{0x12, 0x34, 0x56, 0x78}
		pos := headerLen - 4
		copy(frame[pos:], maskKey[:])
		for i, b := range payload {
			frame[headerLen+i] = b ^ maskKey[i%4]
		}
	} else {
		copy(frame[headerLen:], payload)
	}
	return frame
}

func wsDecodeFrame(data []byte) ([]byte, bool) {
	if len(data) < 2 {
		return nil, false
	}
	masked := (data[1] & 0x80) != 0
	payloadLen := int(data[1] & 0x7F)
	pos := 2
	if payloadLen == 126 {
		payloadLen = int(binary.BigEndian.Uint16(data[pos:]))
		pos += 2
	} else if payloadLen == 127 {
		payloadLen = int(binary.BigEndian.Uint64(data[pos:]))
		pos += 8
	}
	var maskKey [4]byte
	if masked {
		copy(maskKey[:], data[pos:pos+4])
		pos += 4
	}
	payload := make([]byte, payloadLen)
	copy(payload, data[pos:pos+payloadLen])
	if masked {
		for i := range payload {
			payload[i] ^= maskKey[i%4]
		}
	}
	return payload, true
}

func benchWsEncodeSmall() {
	_ = wsEncodeFrame(wsPayload64, true)
}

func benchWsDecodeSmall() {
	frame := wsEncodeFrame(wsPayload64, true)
	_, _ = wsDecodeFrame(frame)
}

func benchWsEncodeLarge() {
	_ = wsEncodeFrame(wsPayload4K, true)
}

func benchWsMask() {
	data := make([]byte, 4096)
	copy(data, wsPayload4K)
	maskKey := [4]byte{0x12, 0x34, 0x56, 0x78}
	for i := range data {
		data[i] ^= maskKey[i%4]
	}
}

func benchWsAcceptKey() {
	key := "dGhlIHNhbXBsZSBub25jZQ=="
	guid := "258EAFA5-E914-47DA-95CA-5AB0F964E80E"
	h := sha1.New()
	h.Write([]byte(key + guid))
	_ = base64.StdEncoding.EncodeToString(h.Sum(nil))
}

func benchWsEncodeSmallServer() {
	_ = wsEncodeFrame(wsPayload64, false)
}

func benchWsDecodeSmallServer() {
	frame := wsEncodeFrame(wsPayload64, false)
	_, _ = wsDecodeFrame(frame)
}

// ===== Main =====

func main() {
	_ = rand.Int // suppress unused import
	initSseStream()
	initMultipart()
	initWs()

	fmt.Println("=== Go stdlib protocol benchmark ===")
	fmt.Println()

	fmt.Println("--- Cookie ---")
	bench("ParseCookieHeader (5 cookies)", benchParseCookieHeader)
	bench("BuildSetCookie (all attrs)", benchBuildSetCookie)
	bench("ParseCookieHeader (10 cookies)", benchParseCookieHeader10)
	fmt.Println()

	fmt.Println("--- SSE ---")
	bench("SseParseEvent (single)", benchSseParseEvent)
	bench("SseParseStream (100 events)", benchSseParseStream)
	bench("SseFeed (10KB incremental)", benchSseFeed)
	fmt.Println()

	fmt.Println("--- Multipart ---")
	bench("MultipartParse (3 fields, 1KB)", benchMultipartParse)
	bench("MultipartExtractBoundary", benchMultipartExtractBoundary)
	bench("MultipartLarge (10KB file)", benchMultipartLarge)
	fmt.Println()

	fmt.Println("--- WebSocket (client/masked) ---")
	bench("WsEncodeSmall (64B, masked)", benchWsEncodeSmall)
	bench("WsDecodeSmall (64B, masked)", benchWsDecodeSmall)
	bench("WsEncodeLarge (4KB, masked)", benchWsEncodeLarge)
	bench("WsMask (4KB payload)", benchWsMask)
	bench("WsAcceptKey (SHA1+Base64)", benchWsAcceptKey)
	fmt.Println()

	fmt.Println("--- WebSocket (server/unmasked) ---")
	bench("WsEncodeSmall (64B, unmasked)", benchWsEncodeSmallServer)
	bench("WsDecodeSmall (64B, unmasked)", benchWsDecodeSmallServer)
	fmt.Println()

	fmt.Println("done.")
}
