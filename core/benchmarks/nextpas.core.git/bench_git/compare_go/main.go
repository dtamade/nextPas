package main

// bench_git Go counterpart — Adler32 64K zero-copy via hash/adler32, same DATA_64K as bench_git.lpr.
// Same-machine A/B normalization: Pascal PByte+Len vs Go hash/adler32.Update vs Rust adler crate.
// Single-source: Go stdlib hash/adler32 (no hand-rolled 65521 loop), zero-copy via slice header.

import (
	"fmt"
	"hash/adler32"
	"testing"
	"time"
)

const data64K = 64 * 1024

var gData64K []byte

func initData() {
	gData64K = make([]byte, data64K)
	for i := 0; i < data64K; i++ {
		gData64K[i] = byte((i*31 + 7) % 251)
	}
}

func benchAdler32PByte() testing.BenchmarkResult {
	return testing.Benchmark(func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			v := adler32.Checksum(gData64K)
			if v == 0 {
				b.Fatalf("unexpected zero")
			}
		}
		b.SetBytes(int64(data64K))
	})
}

func benchAdler32Update() testing.BenchmarkResult {
	// incremental Update path — mirrors PByte reuse
	return testing.Benchmark(func(b *testing.B) {
		for i := 0; i < b.N; i++ {
			h := adler32.New()
			h.Write(gData64K)
			v := h.Sum32()
			if v == 0 {
				b.Fatalf("unexpected zero")
			}
		}
		b.SetBytes(int64(data64K))
	})
}

func main() {
	initData()
	r1 := benchAdler32PByte()
	r2 := benchAdler32Update()
	ns1 := float64(r1.T.Nanoseconds()) / float64(r1.N)
	ns2 := float64(r2.T.Nanoseconds()) / float64(r2.N)
	fmt.Printf("BenchmarkAdler32/PByte64K %d %d ns/op %.2f MB/s (%.0f ops/sec)\n",
		r1.N, int64(ns1), float64(data64K)/ns1*1e9/1e6, 1e9/ns1)
	fmt.Printf("BenchmarkAdler32/Update64K %d %d ns/op %.2f MB/s (%.0f ops/sec)\n",
		r2.N, int64(ns2), float64(data64K)/ns2*1e9/1e6, 1e9/ns2)
	// also emit raw testing.B format for xlang parser
	fmt.Printf("BenchmarkAdler32/PByte64K-%d %d %d ns/op\n", 8, r1.N, int64(ns1))
	fmt.Printf("BenchmarkAdler32/Update64K-%d %d %d ns/op\n", 8, r2.N, int64(ns2))
	_ = time.Now()
}
