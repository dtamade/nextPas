package main

import (
	"container/heap"
	"fmt"
	"math/rand"
	"time"
)

const (
	N1K   = 1000
	N10K  = 10000
	N100K = 100000
)

var keys [N100K]int32

func genData() {
	for i := 0; i < N100K; i++ {
		keys[i] = int32(N100K - i)
	}
}

// IntHeap implements heap.Interface
type IntHeap []int32

func (h IntHeap) Len() int            { return len(h) }
func (h IntHeap) Less(i, j int) bool  { return h[i] < h[j] }
func (h IntHeap) Swap(i, j int)       { h[i], h[j] = h[j], h[i] }
func (h *IntHeap) Push(x interface{}) { *h = append(*h, x.(int32)) }
func (h *IntHeap) Pop() interface{} {
	old := *h
	n := len(old)
	x := old[n-1]
	*h = old[:n-1]
	return x
}

func bench(name string, iters int, fn func()) {
	for i := 0; i < 3; i++ {
		fn()
	}
	start := time.Now()
	for i := 0; i < iters; i++ {
		fn()
	}
	dur := time.Since(start)
	nsPerOp := float64(dur.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-30s %10d iters  %10.1f ns/op\n", name, iters, nsPerOp)
}

func main() {
	genData()
	fmt.Println("=== Go pqueue_bench ===")
	fmt.Println()

	// Push
	fmt.Println("[Push]")
	bench("Push/1K", 10000, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N1K; i++ {
			heap.Push(h, keys[i])
		}
	})
	bench("Push/10K", 1000, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N10K; i++ {
			heap.Push(h, keys[i])
		}
	})
	bench("Push/100K", 100, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N100K; i++ {
			heap.Push(h, keys[i])
		}
	})

	// Pop (push then pop all)
	fmt.Println()
	fmt.Println("[Pop]")
	bench("Pop/1K", 10000, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N1K; i++ {
			heap.Push(h, keys[i])
		}
		for i := 0; i < N1K; i++ {
			heap.Pop(h)
		}
	})
	bench("Pop/10K", 1000, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N10K; i++ {
			heap.Push(h, keys[i])
		}
		for i := 0; i < N10K; i++ {
			heap.Pop(h)
		}
	})
	bench("Pop/100K", 100, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N100K; i++ {
			heap.Push(h, keys[i])
		}
		for i := 0; i < N100K; i++ {
			heap.Pop(h)
		}
	})

	// Interleaved push/pop
	fmt.Println()
	fmt.Println("[Interleaved]")
	bench("Interleaved/1K", 5000, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N1K; i++ {
			heap.Push(h, keys[i])
			if i&3 == 0 {
				heap.Pop(h)
			}
		}
	})
	bench("Interleaved/10K", 500, func() {
		h := &IntHeap{}
		heap.Init(h)
		for i := 0; i < N10K; i++ {
			heap.Push(h, keys[i])
			if i&3 == 0 {
				heap.Pop(h)
			}
		}
	})

	_ = rand.Int()
}
