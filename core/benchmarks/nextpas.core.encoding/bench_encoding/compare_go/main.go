package main

import (
	"encoding/base64"
	"encoding/hex"
	"fmt"
	"time"
)

const dataSize = 10000
const iters = 1000

func main() {
	data := make([]byte, dataSize)
	for i := range data {
		data[i] = byte(i % 256)
	}
	encoded64 := base64.StdEncoding.EncodeToString(data)
	encodedHex := hex.EncodeToString(data)

	fmt.Printf("=== Go Encoding Benchmark (data=%d bytes) ===\n\n", dataSize)

	// Base64 Encode
	start := time.Now()
	sink := 0
	for i := 0; i < iters; i++ {
		s := base64.StdEncoding.EncodeToString(data)
		sink += len(s)
	}
	ns := float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Base64.Encode: %10.1f ns/op\n", ns)

	// Base64 Decode
	start = time.Now()
	for i := 0; i < iters; i++ {
		d, _ := base64.StdEncoding.DecodeString(encoded64)
		sink += len(d)
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Base64.Decode: %10.1f ns/op\n", ns)

	// Hex Encode
	start = time.Now()
	for i := 0; i < iters; i++ {
		s := hex.EncodeToString(data)
		sink += len(s)
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Hex.Encode:    %10.1f ns/op\n", ns)

	// Hex Decode
	start = time.Now()
	for i := 0; i < iters; i++ {
		d, _ := hex.DecodeString(encodedHex)
		sink += len(d)
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Hex.Decode:    %10.1f ns/op\n", ns)

	_ = sink
}
