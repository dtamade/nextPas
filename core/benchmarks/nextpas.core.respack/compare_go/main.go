package main

import (
	"embed"
	"fmt"
	"os"
	"syscall"
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
	// Accumulate a checksum over the full contents and print it: without
	// consuming the bytes the optimizer eliminates the read (measured
	// ~1.6µs hollow loop instead of a real ~7µs payload read).
	var acc uint64
	for i := 0; i < warmupIters; i++ {
		data, _ := embeddedFS.ReadFile("testdata/file0000.bin")
		for _, b := range data {
			acc += uint64(b)
		}
	}
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		data, _ := embeddedFS.ReadFile("testdata/file0000.bin")
		for _, b := range data {
			acc += uint64(b)
		}
		iters++
	}
	elapsed := time.Since(start)
	fmt.Printf("  checksum: %016x\n", acc)
	printResult("go-embed/FS-4k", iters, elapsed)
}

func benchEmbedOpenRead(duration time.Duration) {
	// startup path: Open + ReadAll (mirrors ResPackOpen+Find)
	var acc uint64
	for i := 0; i < warmupIters; i++ {
		f, _ := embeddedFS.Open("testdata/file0000.bin")
		buf := make([]byte, 4096)
		n, _ := f.Read(buf)
		for _, b := range buf[:n] {
			acc += uint64(b)
		}
		f.Close()
	}
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		f, _ := embeddedFS.Open("testdata/file0000.bin")
		buf := make([]byte, 4096)
		n, _ := f.Read(buf)
		for _, b := range buf[:n] {
			acc += uint64(b)
		}
		f.Close()
		iters++
	}
	elapsed := time.Since(start)
	fmt.Printf("  checksum: %016x\n", acc)
	printResult("go-embed/Open+Read-4k", iters, elapsed)
}

func main() {
	fmt.Println("=== Go embed.FS Benchmarks (same payload as nextpas bench_servevfs 4KiB) ===")
	fmt.Println()
	benchEmbedReadFile(dur)
	benchEmbedOpenRead(dur)
	fmt.Println()
	benchStartupPackFile()
	fmt.Println()
	benchBulkWrite512()
	fmt.Println()
	fmt.Println("Note: same-host with nextpas benches; payloads: 4KiB testdata file,")
	fmt.Println("1MiB runtime-generated pack file, 512MiB runtime-generated bulk write.")
}

// genPattern fills b with the same deterministic pattern the Pascal benches
// use ((j*31+7) mod 251), so checksum cost is comparable, not identical data.
func genPattern(b []byte, seed int) {
	for j := range b {
		b[j] = byte((j*31 + seed*7) % 251)
	}
}

// Startup peer for Pascal readfile-pack-carrier: 1MiB generated file is
// written once outside timing, then ReadFile+checksum is timed (mirrors
// Pascal ReadFile+Open+Find minus format validation, documented in RESULTS).
func benchStartupPackFile() {
	const size = 1048576
	path := os.TempDir() + "/go-bench-startup.pack"
	blob := make([]byte, size)
	genPattern(blob, 1)
	if err := os.WriteFile(path, blob, 0644); err != nil {
		panic(err)
	}
	blob = nil
	var acc uint64
	for i := 0; i < warmupIters; i++ {
		data, _ := os.ReadFile(path)
		for _, b := range data {
			acc += uint64(b)
		}
	}
	var iters uint64
	start := time.Now()
	for time.Since(start) < dur {
		data, _ := os.ReadFile(path)
		for _, b := range data {
			acc += uint64(b)
		}
		iters++
	}
	elapsed := time.Since(start)
	os.Remove(path)
	fmt.Printf("  checksum: %016x\n", acc)
	printResult("go-startup/readfile-1mb", iters, elapsed)
}

// Bulk-write peer for Pascal writer_memory/writer_dedup: 512MiB assembled
// chunk by chunk with checksum (mirrors Pascal 64x8MiB inputs; Pascal
// additionally sorts/validates/aligns, documented in RESULTS). Input chunks
// are retained like Pascal's caller-held buffers, so peak RSS covers the
// whole end-to-end job on all sides.
func benchBulkWrite512() {
	const total = 536870912
	const chunk = 8 * 1024 * 1024
	buf := make([]byte, 0, total)
	tmp := make([]byte, chunk)
	var retained [][]byte
	var acc uint64
	start := time.Now()
	for off := 0; off < total; off += chunk {
		genPattern(tmp, off/chunk)
		buf = append(buf, tmp...)
		cp := append([]byte(nil), tmp...)
		retained = append(retained, cp)
		for _, b := range tmp {
			acc += uint64(b)
		}
	}
	elapsed := time.Since(start)
	_ = retained
	fmt.Printf("  checksum: %016x\n", acc)
	fmt.Printf("  %-30s %8d bytes  %8.2f ms\n", "go-bulk/write-512mb", len(buf), float64(elapsed.Milliseconds()))
	var ru syscall.Rusage
	syscall.Getrusage(syscall.RUSAGE_SELF, &ru)
	fmt.Printf("  peak rss: %d MB\n", ru.Maxrss/1024)
}
