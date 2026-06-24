package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
	"unsafe"
)

const (
	BenchIterations = 1000
	SmallSize       = 64
	MediumSize      = 1024
	BatchCount      = 10000
	ReuseCycles     = 100
)

type BenchResult struct {
	Name      string
	TotalNs   int64
	NsPerOp   float64
	OpsPerSec float64
}

func printResult(r BenchResult) {
	fmt.Printf("  %-45s %12.0f ns/op  %12.0f ops/s\n", r.Name, r.NsPerOp, r.OpsPerSec)
}

// Simple bump arena for Go benchmark (mimics our TVirtualArena)
type BumpArena struct {
	buf      []byte
	offset   int
	capacity int
}

func NewBumpArena(capacity int) *BumpArena {
	buf := make([]byte, capacity)
	return &BumpArena{buf: buf, offset: 0, capacity: capacity}
}

func (a *BumpArena) Alloc(size int) unsafe.Pointer {
	if a.offset+size > a.capacity {
		return nil
	}
	ptr := unsafe.Pointer(&a.buf[a.offset])
	a.offset += size
	return ptr
}

func (a *BumpArena) Reset() {
	a.offset = 0
}

// Benchmark: Go runtime malloc + free
func benchGoMallocSmall() BenchResult {
	var r BenchResult
	r.Name = "Go runtime make([]byte, 64B) x10000"
	t0 := time.Now().UnixNano()
	for i := 0; i < BenchIterations; i++ {
		for j := 0; j < BatchCount; j++ {
			_ = make([]byte, SmallSize)
		}
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(BenchIterations*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

// Benchmark: Go runtime batch malloc + free (GC handles cleanup)
func benchGoBatchSmall() BenchResult {
	var r BenchResult
	r.Name = "Go runtime batch make 64B x10000"
	t0 := time.Now().UnixNano()
	for i := 0; i < BenchIterations; i++ {
		ptrs := make([][]byte, BatchCount)
		for j := 0; j < BatchCount; j++ {
			ptrs[j] = make([]byte, SmallSize)
		}
		_ = ptrs // prevent optimization
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(BenchIterations*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

// Benchmark: BumpArena alloc
func benchBumpArenaAlloc() BenchResult {
	var r BenchResult
	r.Name = "Go BumpArena Alloc 64B x10000"
	arena := NewBumpArena(BatchCount * SmallSize * 2)
	t0 := time.Now().UnixNano()
	for i := 0; i < BenchIterations; i++ {
		arena.Reset()
		for j := 0; j < BatchCount; j++ {
			arena.Alloc(SmallSize)
		}
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(BenchIterations*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

// Benchmark: BumpArena reset+reuse cycles
func benchBumpArenaResetReuse() BenchResult {
	var r BenchResult
	r.Name = "Go BumpArena reset+reuse cycles x1000"
	arena := NewBumpArena(BatchCount * SmallSize * 2)
	t0 := time.Now().UnixNano()
	for i := 0; i < ReuseCycles; i++ {
		for j := 0; j < BatchCount; j++ {
			arena.Alloc(SmallSize)
		}
		arena.Reset()
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(ReuseCycles*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

// Benchmark: Go sync.Pool reuse (simulates arena-like reuse)
func benchSyncPoolReuse() BenchResult {
	var r BenchResult
	r.Name = "Go sync.Pool reuse 64B x10000"
	pool := &sync.Pool{
		New: func() interface{} {
			return make([]byte, SmallSize)
		},
	}
	t0 := time.Now().UnixNano()
	for i := 0; i < BenchIterations; i++ {
		for j := 0; j < BatchCount; j++ {
			buf := pool.Get().([]byte)
			pool.Put(buf)
		}
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(BenchIterations*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

// Benchmark: unsafe.Pointer arithmetic (zero-overhead bump)
func benchUnsafeBumpSmall() BenchResult {
	var r BenchResult
	r.Name = "Go unsafe bump 64B x10000"
	buf := make([]byte, BatchCount*SmallSize*2)
	t0 := time.Now().UnixNano()
	for i := 0; i < BenchIterations; i++ {
		offset := 0
		for j := 0; j < BatchCount; j++ {
			_ = unsafe.Pointer(&buf[offset])
			offset += SmallSize
		}
	}
	t1 := time.Now().UnixNano()
	r.TotalNs = t1 - t0
	r.NsPerOp = float64(r.TotalNs) / float64(BenchIterations*BatchCount)
	r.OpsPerSec = 1e9 / r.NsPerOp
	return r
}

func main() {
	fmt.Println("=== Go Arena Benchmark ===")
	fmt.Printf("  Iterations: %d, Batch: %d, Size: %dB\n", BenchIterations, BatchCount, SmallSize)
	fmt.Println()

	// Force GC before benchmarks
	runtime.GC()
	runtime.GC()

	results := []BenchResult{
		benchGoMallocSmall(),
		benchGoBatchSmall(),
		benchBumpArenaAlloc(),
		benchBumpArenaResetReuse(),
		benchSyncPoolReuse(),
		benchUnsafeBumpSmall(),
	}

	fmt.Println("--- Results ---")
	for _, r := range results {
		printResult(r)
	}
	fmt.Println()
	fmt.Println("Done.")
}
