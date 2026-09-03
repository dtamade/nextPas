package main

import (
	"embed"
	"fmt"
	"time"
)

//go:embed testdata/file0000.bin
var embeddedFS embed.FS

const warmupIters = 50
const dur = 2000 * time.Millisecond

func printResult(name string, iters uint64, elapsed time.Duration) {
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-30s %8d iters  %8.2f ms  %10.1f ns/op\n", name, iters, float64(elapsed.Milliseconds()), nsPerOp)
}

func benchEmbedReadFile(duration time.Duration) {
	for i := 0; i < warmupIters; i++ {
		embeddedFS.ReadFile("testdata/file0000.bin")
	}
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		embeddedFS.ReadFile("testdata/file0000.bin")
		iters++
	}
	elapsed := time.Since(start)
	printResult("go-embed/FS-4k", iters, elapsed)
}

func benchEmbedOpenRead(duration time.Duration) {
	// startup path: Open + ReadAll (mirrors ResPackOpen+Find)
	for i := 0; i < warmupIters; i++ {
		f, _ := embeddedFS.Open("testdata/file0000.bin")
		buf := make([]byte, 4096)
		f.Read(buf)
		f.Close()
	}
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		f, _ := embeddedFS.Open("testdata/file0000.bin")
		buf := make([]byte, 4096)
		f.Read(buf)
		f.Close()
		iters++
	}
	elapsed := time.Since(start)
	printResult("go-embed/Open+Read-4k", iters, elapsed)
}

func main() {
	fmt.Println("=== Go embed.FS Benchmarks (same payload as nextpas bench_servevfs 4KiB) ===")
	fmt.Println()
	benchEmbedReadFile(dur)
	benchEmbedOpenRead(dur)
	fmt.Println()
	fmt.Println("Note: numbers are same-host with nextpas bench_servevfs ~7µs; expect ~7.2µs ±30%")
}
