package main

import (
	"fmt"
	"io"
	"os"
	"path/filepath"
	"time"
)

func main() {
	fmt.Println("=== Go FS Benchmark ===\n")
	tmpDir, _ := os.MkdirTemp("", "bench_fs_go")
	defer os.RemoveAll(tmpDir)

	const size = 1024 * 1024 // 1MB
	data := make([]byte, size)
	for i := range data { data[i] = byte(i % 256) }
	fpath := filepath.Join(tmpDir, "test.bin")

	// Sequential Write
	start := time.Now()
	for iter := 0; iter < 20; iter++ {
		f, _ := os.Create(fpath)
		f.Write(data)
		f.Close()
	}
	elapsed := time.Since(start)
	mbps := float64(size*20) / elapsed.Seconds() / 1024 / 1024
	fmt.Printf("  SeqWrite 1MB x20:  %7.1f MB/s\n", mbps)

	// Sequential Read
	start = time.Now()
	for iter := 0; iter < 20; iter++ {
		f, _ := os.Open(fpath)
		io.ReadAll(f)
		f.Close()
	}
	elapsed = time.Since(start)
	mbps = float64(size*20) / elapsed.Seconds() / 1024 / 1024
	fmt.Printf("  SeqRead 1MB x20:   %7.1f MB/s\n", mbps)

	// Walk directory
	walkDir := filepath.Join(tmpDir, "walk")
	os.MkdirAll(walkDir, 0755)
	for i := 0; i < 3; i++ {
		sub := filepath.Join(walkDir, fmt.Sprintf("d%d", i))
		os.MkdirAll(sub, 0755)
		for j := 0; j < 5; j++ {
			os.WriteFile(filepath.Join(sub, fmt.Sprintf("f%d.txt", j)), []byte("x"), 0644)
		}
	}
	start = time.Now()
	count := 0
	for iter := 0; iter < 1000; iter++ {
		filepath.Walk(walkDir, func(path string, info os.FileInfo, err error) error {
			count++
			return nil
		})
	}
	elapsed = time.Since(start)
	fmt.Printf("  Walk (1000x):      %7.3f ms/iter  (%d entries/iter)\n",
		float64(elapsed.Milliseconds())/1000.0, count/1000)
}
