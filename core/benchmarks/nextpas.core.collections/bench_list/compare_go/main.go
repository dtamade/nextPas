package main

import (
	"container/list"
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
	fmt.Printf("=== Go container/list Benchmark (N=%d) ===\n\n", N)

	bench("list.PushBack/N=100000", func() {
		l := list.New()
		for i := 0; i < N; i++ { l.PushBack(int32(i)) }
		sink += int64(l.Len())
	})

	bench("list.PushFront/N=100000", func() {
		l := list.New()
		for i := 0; i < N; i++ { l.PushFront(int32(i)) }
		sink += int64(l.Len())
	})

	bench("list.PopFront/N=100000", func() {
		l := list.New()
		for i := 0; i < N; i++ { l.PushBack(int32(i)) }
		for l.Len() > 0 {
			e := l.Front()
			sink += int64(e.Value.(int32))
			l.Remove(e)
		}
	})

	if sink == -999 { fmt.Println(sink) }
}
