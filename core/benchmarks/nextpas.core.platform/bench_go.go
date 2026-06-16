package main

import (
	"fmt"
	"os"
	"sync"
	"time"
)

const (
	warmupIters = 1000
	benchIters  = 100000
)

func benchTimerResolution() {
	minDelta := time.Duration(1<<63 - 1)
	for i := 0; i < benchIters; i++ {
		start := time.Now()
		end := time.Now()
		diff := end.Sub(start)
		if diff < minDelta && diff > 0 {
			minDelta = diff
		}
	}
	fmt.Printf("=== Timer Resolution ===\n")
	fmt.Printf("  time.Now() min delta: %v\n", minDelta)
	fmt.Println()
}

func benchMutex() {
	var mu sync.Mutex

	for i := 0; i < warmupIters; i++ {
		mu.Lock()
		mu.Unlock()
	}

	start := time.Now()
	for i := 0; i < benchIters; i++ {
		mu.Lock()
		mu.Unlock()
	}
	elapsed := time.Since(start)

	fmt.Printf("=== Mutex Lock/Unlock ===\n")
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(benchIters)
	opsPerSec := float64(benchIters) / elapsed.Seconds()
	fmt.Printf("  %-35s %10.1f ns/op  %12.0f ops/s\n", "sync.Mutex lock+unlock", nsPerOp, opsPerSec)
	fmt.Println()
}

func benchRwLockRead() {
	var rw sync.RWMutex

	for i := 0; i < warmupIters; i++ {
		rw.RLock()
		rw.RUnlock()
	}

	start := time.Now()
	for i := 0; i < benchIters; i++ {
		rw.RLock()
		rw.RUnlock()
	}
	elapsed := time.Since(start)

	fmt.Printf("=== RwLock Read ===\n")
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(benchIters)
	opsPerSec := float64(benchIters) / elapsed.Seconds()
	fmt.Printf("  %-35s %10.1f ns/op  %12.0f ops/s\n", "sync.RWMutex RLock+RUnlock", nsPerOp, opsPerSec)
	fmt.Println()
}

func benchFileIO() {
	const (
		bufSize = 4096
		ioIters = 10000
	)

	buf := make([]byte, bufSize)
	for i := range buf {
		buf[i] = 0xAA
	}

	path := fmt.Sprintf("/tmp/nextpas_bench_go_%d.tmp", os.Getpid())
	defer os.Remove(path)

	f, err := os.Create(path)
	if err != nil {
		fmt.Printf("  SKIP: cannot create temp file: %v\n", err)
		return
	}

	start := time.Now()
	for i := 0; i < ioIters; i++ {
		f.Write(buf)
	}
	writeElapsed := time.Since(start)
	f.Close()

	fmt.Printf("=== File I/O ===\n")
	nsPerOp := float64(writeElapsed.Nanoseconds()) / float64(ioIters)
	opsPerSec := float64(ioIters) / writeElapsed.Seconds()
	fmt.Printf("  %-35s %10.1f ns/op  %12.0f ops/s\n", "file_write 4KB", nsPerOp, opsPerSec)

	f, err = os.Open(path)
	if err != nil {
		return
	}

	start = time.Now()
	for i := 0; i < ioIters; i++ {
		f.Read(buf)
	}
	readElapsed := time.Since(start)
	f.Close()

	nsPerOp = float64(readElapsed.Nanoseconds()) / float64(ioIters)
	opsPerSec = float64(ioIters) / readElapsed.Seconds()
	fmt.Printf("  %-35s %10.1f ns/op  %12.0f ops/s\n", "file_read 4KB", nsPerOp, opsPerSec)
	fmt.Println()
}

func main() {
	fmt.Println("Go runtime benchmarks")
	fmt.Println("=====================")
	fmt.Println()

	benchTimerResolution()
	benchMutex()
	benchRwLockRead()
	benchFileIO()

	fmt.Println("Done.")
}
