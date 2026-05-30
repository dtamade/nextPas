package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"time"
)

func main() {
	fmt.Println("=== Go IO Benchmark ===\n")
	tmpDir, _ := os.MkdirTemp("", "bench_io_go")
	defer os.RemoveAll(tmpDir)

	const size = 10 * 1024 * 1024 // 10MB
	data := make([]byte, size)
	for i := range data { data[i] = byte(i % 256) }
	fpath := tmpDir + "/test.bin"

	// BufWriter 4KB
	start := time.Now()
	for iter := 0; iter < 10; iter++ {
		f, _ := os.Create(fpath)
		w := bufio.NewWriterSize(f, 4096)
		w.Write(data)
		w.Flush()
		f.Close()
	}
	elapsed := time.Since(start)
	mbps := float64(size*10) / elapsed.Seconds() / 1024 / 1024
	fmt.Printf("  BufWriter 4KB write 10MB x10: %7.1f MB/s\n", mbps)

	// BufReader 4KB
	os.WriteFile(fpath, data, 0644)
	start = time.Now()
	for iter := 0; iter < 10; iter++ {
		f, _ := os.Open(fpath)
		r := bufio.NewReaderSize(f, 4096)
		io.Copy(io.Discard, r)
		f.Close()
	}
	elapsed = time.Since(start)
	mbps = float64(size*10) / elapsed.Seconds() / 1024 / 1024
	fmt.Printf("  BufReader 4KB read 10MB x10:  %7.1f MB/s\n", mbps)

	// Copy (io.Copy)
	start = time.Now()
	for iter := 0; iter < 10; iter++ {
		src, _ := os.Open(fpath)
		dst, _ := os.Create(fpath + ".copy")
		io.Copy(dst, src)
		dst.Close()
		src.Close()
	}
	elapsed = time.Since(start)
	mbps = float64(size*10) / elapsed.Seconds() / 1024 / 1024
	fmt.Printf("  Copy 10MB x10:                %7.1f MB/s\n", mbps)
}
