package main

import (
	"crypto/sha256"
	"fmt"
	"time"
)

func benchSHA256(size int, duration time.Duration) {
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i & 0xFF)
	}

	// warmup
	for i := 0; i < 50; i++ {
		sha256.Sum256(data)
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		sha256.Sum256(data)
		bytes += uint64(size)
		iters++
	}
	elapsed := time.Since(start)
	mbps := float64(bytes) / 1048576.0 / elapsed.Seconds()
	fmt.Printf("  SHA-256 %6d bytes: %8.1f MB/s  (%d iters, %d ms)\n",
		size, mbps, iters, elapsed.Milliseconds())
}

func main() {
	fmt.Println("=== SHA-256 Benchmark (Go stdlib) ===")
	fmt.Println()

	benchSHA256(64, 2*time.Second)
	benchSHA256(256, 2*time.Second)
	benchSHA256(1024, 2*time.Second)
	benchSHA256(4096, 2*time.Second)
	benchSHA256(8192, 2*time.Second)
	benchSHA256(16384, 2*time.Second)
	benchSHA256(65536, 2*time.Second)
	benchSHA256(1048576, 2*time.Second)

	fmt.Println()
	fmt.Println("Done.")
}
