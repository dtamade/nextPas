package text

import (
	"encoding/base64"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
	"testing"
)

// --- IntToStr equivalent: format 100k integers ---
func BenchmarkIntToStr_100k(b *testing.B) {
	ints := make([]int, 100000)
	for i := range ints {
		ints[i] = i
	}
	results := make([]string, 100000)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for i, v := range ints {
			results[i] = strconv.Itoa(v)
		}
	}
	_ = results
}

// --- Base64 encode 4KB ---
func BenchmarkBase64Enc_4KB(b *testing.B) {
	src := make([]byte, 4096)
	for i := range src {
		src[i] = byte(i % 256)
	}
	buf := make([]byte, base64.StdEncoding.EncodedLen(len(src)))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		base64.StdEncoding.Encode(buf, src)
	}
}

// --- Base64 decode 5.3KB ---
func BenchmarkBase64Dec_5KB(b *testing.B) {
	src := make([]byte, 4096)
	for i := range src {
		src[i] = byte(i % 256)
	}
	encoded := base64.StdEncoding.EncodeToString(src)
	dst := make([]byte, base64.StdEncoding.DecodedLen(len(encoded)))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		base64.StdEncoding.Decode(dst, []byte(encoded))
	}
}

// --- Hex encode 1KB ---
func BenchmarkHexEnc_1KB(b *testing.B) {
	src := make([]byte, 1024)
	for i := range src {
		src[i] = byte(i % 256)
	}
	dst := make([]byte, hex.EncodedLen(len(src)))
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		hex.Encode(dst, src)
	}
}

// --- StringReplace equivalent ---
func BenchmarkStrReplace_10KB(b *testing.B) {
	s := strings.Repeat("x", 100)
	for i := 0; i < 100; i++ {
		s += "Hello World! This is a test string for replacement. "
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		_ = strings.ReplaceAll(s, "Hello", "World")
	}
}

// --- JSON parse 404B object ---
func BenchmarkJSONParse_404B(b *testing.B) {
	s := `{"users":[{"id":1,"name":"Alice","email":"alice@example.com","score":95.5,"active":true},{"id":2,"name":"Bob","email":"bob@example.com","score":87.3,"active":false},{"id":3,"name":"Charlie","email":"charlie@example.com","score":92.1,"active":true},{"id":4,"name":"Diana","email":"diana@example.com","score":88.8,"active":true},{"id":5,"name":"Eve","email":"eve@example.com","score":91.0,"active":false}]}`
	data := []byte(s)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var m map[string]any
		json.Unmarshal(data, &m)
	}
}

// standalone runner
func TestMain(m *testing.M) {
	m.Run()
	fmt.Println("text bench: use 'go test -bench=.' to run benchmarks")
}
