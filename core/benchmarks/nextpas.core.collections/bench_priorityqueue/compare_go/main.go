package main

import (
	"container/heap"
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const N = 100000

type IntHeap []int32
func (h IntHeap) Len() int           { return len(h) }
func (h IntHeap) Less(i, j int) bool { return h[i] < h[j] }
func (h IntHeap) Swap(i, j int)      { h[i], h[j] = h[j], h[i] }
func (h *IntHeap) Push(x any)        { *h = append(*h, x.(int32)) }
func (h *IntHeap) Pop() any          { old := *h; n := len(old); x := old[n-1]; *h = old[:n-1]; return x }

var randomData [N]int32
var sink int64

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

func main() {
	rng := rand.New(rand.NewSource(42))
	for i := range randomData { randomData[i] = int32(rng.Intn(1000000)) }

	fmt.Printf("=== Go container/heap Benchmark (N=%d) ===\n\n", N)

	bench("heap.Push/N=100000", func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N; i++ { heap.Push(h, randomData[i]) }
		sink += int64(h.Len())
	})

	bench("heap.Pop/N=100000", func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N; i++ { heap.Push(h, randomData[i]) }
		for h.Len() > 0 { sink += int64(heap.Pop(h).(int32)) }
	})

	bench("heap.PushPop interleaved/N=100000", func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N; i++ {
			heap.Push(h, randomData[i])
			if h.Len() > 100 { sink += int64(heap.Pop(h).(int32)) }
		}
	})

	if sink == -999 { fmt.Println(sink) }
}
