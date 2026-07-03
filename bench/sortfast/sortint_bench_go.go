package main

import (
	"fmt"
	"math/rand"
	"sort"
	"time"
)

const (
	N10K  = 10000
	N100K = 100000
	N1M   = 1000000
)

type Rec64 struct {
	Key   int32
	Value int32
}

type Rec64Slice []Rec64

func (s Rec64Slice) Len() int           { return len(s) }
func (s Rec64Slice) Less(i, j int) bool { return s[i].Key < s[j].Key }
func (s Rec64Slice) Swap(i, j int)      { s[i], s[j] = s[j], s[i] }

var (
	ints10K  [N10K]int32
	ints100K [N100K]int32
	ints1M   [N1M]int32
	recs100K [N100K]Rec64
)

func genData() {
	for i := 0; i < N1M; i++ {
		ints1M[i] = int32(N1M - i)
		if i < N10K {
			ints10K[i] = int32(N10K - i)
		}
		if i < N100K {
			ints100K[i] = int32(N100K - i)
			recs100K[i] = Rec64{int32(N100K - i), int32(i)}
		}
	}
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
	fmt.Println("=== Go sortint_bench ===")
	fmt.Println()

	// Sort Ints
	fmt.Println("[sort.Ints]")
	bench("sort.Ints/10K", 1000, func() {
		tmp := make([]int, N10K)
		for i := range tmp {
			tmp[i] = int(ints10K[i])
		}
		sort.Ints(tmp)
	})
	bench("sort.Ints/100K", 100, func() {
		tmp := make([]int, N100K)
		for i := range tmp {
			tmp[i] = int(ints100K[i])
		}
		sort.Ints(tmp)
	})
	bench("sort.Ints/1M", 10, func() {
		tmp := make([]int, N1M)
		for i := range tmp {
			tmp[i] = int(ints1M[i])
		}
		sort.Ints(tmp)
	})

	// Sort Records
	fmt.Println()
	fmt.Println("[sort.Slice]")
	bench("sort.Slice/Rec100K", 100, func() {
		tmp := make([]Rec64, N100K)
		copy(tmp, recs100K[:])
		sort.Slice(tmp, func(i, j int) bool {
			return tmp[i].Key < tmp[j].Key
		})
	})

	_ = rand.Int()
}
