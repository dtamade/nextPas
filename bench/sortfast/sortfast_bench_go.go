package main

import (
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const (
	N1K   = 1000
	N10K  = 10000
	N100K = 100000
)

var data1K, data10K, data100K []int

func init() {
	r := rand.New(rand.NewSource(42))
	data100K = make([]int, N100K)
	for i := range data100K {
		data100K[i] = int(r.Uint32() & 0x7FFFFFFF)
	}
	data10K = make([]int, N10K)
	copy(data10K, data100K[:N10K])
	data1K = make([]int, N1K)
	copy(data1K, data100K[:N1K])
}

func benchSort(n int, src []int) {
	dst := make([]int, n)
	copy(dst, src[:n])
	sort.Ints(dst)
	_ = dst[0]
}

func benchmark(name string, fn func()) {
	for w := 0; w < 3; w++ {
		fn()
	}
	var best time.Duration
	var bestN int
	for attempt := 0; attempt < 10; attempt++ {
		start := time.Now()
		iters := 0
		d := time.Duration(0)
		for d < 200*time.Millisecond {
			fn()
			iters++
			d = time.Since(start)
		}
		nsPerOp := d / time.Duration(iters)
		if best == 0 || nsPerOp < best {
			best = nsPerOp
			bestN = iters
		}
	}
	fmt.Printf("%40s  %6d iters  %10.1f ns/op  %10.0f ops/s\n",
		name, bestN, float64(best.Nanoseconds()), 1e9/float64(best.Nanoseconds()))
}

func main() {
	benchmark("GoSort/1K", func() { benchSort(N1K, data1K) })
	benchmark("GoSort/10K", func() { benchSort(N10K, data10K) })
	benchmark("GoSort/100K", func() { benchSort(N100K, data100K) })
}
