package main

import (
	"crypto/hmac"
	"crypto/md5"
	"crypto/sha1"
	"crypto/sha256"
	"crypto/sha512"
	"fmt"
	"time"
)

func bench(name string, size int, duration time.Duration, hashFn func([]byte)) {
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i & 0xFF)
	}

	// warmup
	for i := 0; i < 50; i++ {
		hashFn(data)
	}

	var bytes uint64
	start := time.Now()
	for time.Since(start) < duration {
		hashFn(data)
		bytes += uint64(size)
	}
	elapsed := time.Since(start)
	mbps := float64(bytes) / 1048576.0 / elapsed.Seconds()
	fmt.Printf("  %-20s %6d B: %8.1f MB/s\n", name, size, mbps)
}

func main() {
	fmt.Println("=== Go Hash Benchmark (reference) ===")
	fmt.Println()

	sizes := []int{64, 256, 1024, 8192, 1048576}
	dur := time.Second

	fmt.Println("--- SHA-256 ---")
	for _, s := range sizes {
		bench("SHA-256", s, dur, func(d []byte) { sha256.Sum256(d) })
	}

	fmt.Println("\n--- SHA-512 ---")
	for _, s := range sizes {
		bench("SHA-512", s, dur, func(d []byte) { sha512.Sum512(d) })
	}

	fmt.Println("\n--- SHA-384 ---")
	bench("SHA-384", 1024, dur, func(d []byte) { sha512.Sum384(d) })
	bench("SHA-384", 1048576, dur, func(d []byte) { sha512.Sum384(d) })

	fmt.Println("\n--- SHA-1 ---")
	for _, s := range sizes {
		bench("SHA-1", s, dur, func(d []byte) { sha1.Sum(d) })
	}

	fmt.Println("\n--- MD5 ---")
	bench("MD5", 1024, dur, func(d []byte) { md5.Sum(d) })
	bench("MD5", 1048576, dur, func(d []byte) { md5.Sum(d) })

	fmt.Println("\n--- HMAC-SHA-256 ---")
	key := make([]byte, 32)
	for i := range key {
		key[i] = 0xAB
	}
	for _, s := range []int{64, 1024, 8192} {
		bench("HMAC-SHA256", s, dur, func(d []byte) {
			h := hmac.New(sha256.New, key)
			h.Write(d)
			h.Sum(nil)
		})
	}
}
