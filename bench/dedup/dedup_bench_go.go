package main

import (
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const (
	N100K = 100000
	N1M   = 1000000
)

var (
	data100K [N100K]int32
	data1M   [N1M]int32
	work     [N1M]int32
)

func genData() {
	for i := 0; i < N100K; i++ {
		data100K[i] = int32(i / 2)
	}
	for i := 0; i < N1M; i++ {
		data1M[i] = int32(i / 2)
	}
}

func sortDedup(data []int32) int {
	copy(work[:len(data)], data)
	sort.Slice(work[:len(data)], func(i, j int) bool {
		return work[i] < work[j]
	})
	k := 0
	prev := work[0] - 1
	for _, v := range data {
		_ = v
	}
	for i := 0; i < len(data); i++ {
		cur := work[i]
		if cur != prev {
			work[k] = cur
			k++
			prev = cur
		}
	}
	return k
}

func mapDedup(data []int32) int {
	m := make(map[int32]struct{}, len(data))
	for _, v := range data {
		m[v] = struct{}{}
	}
	return len(m)
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
	fmt.Println("=== Go dedup_bench ===")
	fmt.Println()

	fmt.Println("[Dedup]")
	bench("SortDedup/100K", 100, func() { sortDedup(data100K[:]) })
	bench("SortDedup/1M", 20, func() { sortDedup(data1M[:]) })
	bench("MapDedup/100K", 100, func() { mapDedup(data100K[:]) })
	bench("MapDedup/1M", 20, func() { mapDedup(data1M[:]) })

	_ = rand.Int()
}
