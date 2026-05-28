package main

import (
	"fmt"
	"sort"
	"time"
)

const N = 100000

func bench(name string, f func()) {
	for i := 0; i < 3; i++ { f() }
	iters := 10
	for {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		elapsed := time.Since(start)
		if elapsed >= 50*time.Millisecond { break }
		if elapsed < time.Millisecond { iters *= 10 } else {
			iters = int(float64(iters) * float64(50*time.Millisecond) / float64(elapsed))
		}
		if iters > 1000 { iters = 1000; break }
	}
	samples := make([]time.Duration, 3)
	for s := range samples {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		samples[s] = time.Since(start)
	}
	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	median := samples[1]
	nsPerOp := float64(median.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-40s %8d iters %10.1f ns/op %14.0f ops/s\n", name, iters, nsPerOp, 1e9/nsPerOp)
}

var sink int64

func main() {
	fmt.Printf("=== Go map[int32]int32 Benchmark (N=%d) ===\n\n", N)

	bench("map put/N=100000", func() {
		m := make(map[int32]int32)
		for i := int32(0); i < N; i++ { m[i] = i }
		sink += int64(len(m))
	})

	bench("map put+prealloc/N=100000", func() {
		m := make(map[int32]int32, N)
		for i := int32(0); i < N; i++ { m[i] = i }
		sink += int64(len(m))
	})

	gmap := make(map[int32]int32, N)
	for i := int32(0); i < N; i++ { gmap[i] = i }

	bench("map get(hit)/N=100000", func() {
		for i := int32(0); i < N; i++ {
			if v, ok := gmap[i]; ok { sink += int64(v) }
		}
	})

	bench("map get(miss)/N=100000", func() {
		for i := int32(N); i < 2*N; i++ {
			if v, ok := gmap[i]; ok { sink += int64(v) }
		}
	})

	bench("map delete/N=100000", func() {
		m := make(map[int32]int32, N)
		for i := int32(0); i < N; i++ { m[i] = i }
		for i := int32(0); i < N; i++ { delete(m, i) }
		sink += int64(len(m))
	})

	if sink == -999 { fmt.Println(sink) }
}
