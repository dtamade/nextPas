package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

func thruput(size, n int, elapsed time.Duration) float64 {
	return float64(size*n) / elapsed.Seconds() / 1024 / 1024
}

func main() {
	fmt.Println("=== Go FS scorecard (aligned methods) ===")
	tmpDir, _ := os.MkdirTemp("", "bench_fs_go")
	defer os.RemoveAll(tmpDir)

	// --- same method as Pascal historical 64KB path (create/write/close loop) ---
	const size64 = 64 * 1024
	const n64 = 200
	data64 := make([]byte, size64)
	for i := range data64 {
		data64[i] = 0xAA
	}
	fpath64 := filepath.Join(tmpDir, "t64.bin")
	start := time.Now()
	for i := 0; i < n64; i++ {
		f, _ := os.Create(fpath64)
		f.Write(data64)
		f.Close()
	}
	fmt.Printf("SeqWrite 64KB x%d: %7.1f MB/s\n", n64, thruput(size64, n64, time.Since(start)))
	start = time.Now()
	for i := 0; i < n64; i++ {
		f, _ := os.Open(fpath64)
		io.ReadAll(f)
		f.Close()
	}
	fmt.Printf("SeqRead  64KB x%d: %7.1f MB/s\n", n64, thruput(size64, n64, time.Since(start)))

	// --- same method as SCORECARD legacy Go 1MB×20 ---
	const size1m = 1024 * 1024
	const n1m = 20
	data1 := make([]byte, size1m)
	for i := range data1 {
		data1[i] = byte(i % 256)
	}
	fpath1 := filepath.Join(tmpDir, "t1m.bin")
	start = time.Now()
	for i := 0; i < n1m; i++ {
		f, _ := os.Create(fpath1)
		f.Write(data1)
		f.Close()
	}
	fmt.Printf("SeqWrite 1MB x%d:  %7.1f MB/s\n", n1m, thruput(size1m, n1m, time.Since(start)))
	start = time.Now()
	for i := 0; i < n1m; i++ {
		f, _ := os.Open(fpath1)
		io.ReadAll(f)
		f.Close()
	}
	fmt.Printf("SeqRead  1MB x%d:  %7.1f MB/s\n", n1m, thruput(size1m, n1m, time.Since(start)))
}
