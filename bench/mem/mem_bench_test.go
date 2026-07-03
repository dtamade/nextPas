package main

// mem_bench_test.go
// Go memory allocator benchmark — matches Pascal mem_bench.pas parameters

import (
	"fmt"
	"sync"
	"testing"
	"unsafe"
)

const (
	ALLOC_N    = 10000
	SMALL_SIZE = 64
	LARGE_SIZE = 1024
	POOL_N     = 100000
)

// Force heap allocation by storing to global
var sink []byte
var sinkPool unsafe.Pointer

// --- Alloc/Free 64B (make + force heap escape) ---

func BenchmarkAlloc64(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < ALLOC_N; i++ {
			p := make([]byte, SMALL_SIZE)
			sink = p // force heap escape
		}
	}
	_ = sink
}

// --- Alloc/Free 1KB ---

func BenchmarkAlloc1K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < ALLOC_N; i++ {
			p := make([]byte, LARGE_SIZE)
			sink = p
		}
	}
	_ = sink
}

// --- Batch Alloc 64B × 100 then release ---

func BenchmarkBatch64(b *testing.B) {
	for n := 0; n < b.N; n++ {
		batch := make([][]byte, 0, 100)
		for i := 0; i < ALLOC_N; i++ {
			batch = append(batch, make([]byte, SMALL_SIZE))
			if len(batch) == 100 {
				batch = batch[:0]
			}
		}
	}
}

// --- Pool Get/Put 64B × 100000 ---

func BenchmarkPool64(b *testing.B) {
	pool := sync.Pool{
		New: func() interface{} {
			p := make([]byte, SMALL_SIZE)
			return &p
		},
	}
	for n := 0; n < b.N; n++ {
		for i := 0; i < POOL_N; i++ {
			p := pool.Get()
			pool.Put(p)
		}
	}
}

func main() {
	fmt.Println("Use: go test -bench=. -benchtime=3s")
}
