package main

import (
	"fmt"
	"math/rand"
	"time"
)

const (
	N10K  = 10000
	N100K = 100000
)

var (
	sorted10K  [N10K]int32
	sorted100K [N100K]int32
	out        [N100K]int32
)

func genData() {
	for i := 0; i < N10K; i++ {
		sorted10K[i] = int32(i*3 + 1)
	}
	for i := 0; i < N100K; i++ {
		sorted100K[i] = int32(i*2 + 1)
	}
}

func sortedIntersect(dst, a, b []int32) int {
	i, j, k := 0, 0, 0
	for i < len(a) && j < len(b) {
		if a[i] == b[j] {
			dst[k] = a[i]
			k++
			i++
			j++
		} else if a[i] < b[j] {
			i++
		} else {
			j++
		}
	}
	return k
}

func sortedIntersectCount(a, b []int32) int {
	i, j, k := 0, 0, 0
	for i < len(a) && j < len(b) {
		if a[i] == b[j] {
			k++
			i++
			j++
		} else if a[i] < b[j] {
			i++
		} else {
			j++
		}
	}
	return k
}

func sortedUnion(dst, a, b []int32) int {
	i, j, k := 0, 0, 0
	for i < len(a) && j < len(b) {
		if a[i] == b[j] {
			dst[k] = a[i]
			k++
			i++
			j++
		} else if a[i] < b[j] {
			dst[k] = a[i]
			k++
			i++
		} else {
			dst[k] = b[j]
			k++
			j++
		}
	}
	for i < len(a) {
		dst[k] = a[i]
		k++
		i++
	}
	for j < len(b) {
		dst[k] = b[j]
		k++
		j++
	}
	return k
}

// map-based intersection
func mapIntersect(a, b []int32) int {
	m := make(map[int32]struct{}, len(a))
	for _, v := range a {
		m[v] = struct{}{}
	}
	c := 0
	for _, v := range b {
		if _, ok := m[v]; ok {
			c++
		}
	}
	return c
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
	fmt.Println("=== Go setops_bench ===")
	fmt.Println()

	fmt.Println("[Intersection]")
	bench("Merge/10Kx100K", 10000, func() {
		c := sortedIntersect(out[:], sorted10K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Merge/100Kx100K", 5000, func() {
		c := sortedIntersect(out[:], sorted100K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Count/10Kx100K", 10000, func() {
		c := sortedIntersectCount(sorted10K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Count/100Kx100K", 5000, func() {
		c := sortedIntersectCount(sorted100K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Map/10Kx100K", 5000, func() {
		c := mapIntersect(sorted10K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Map/100Kx100K", 1000, func() {
		c := mapIntersect(sorted100K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})

	fmt.Println()
	fmt.Println("[Union]")
	bench("Merge/10Kx100K", 10000, func() {
		c := sortedUnion(out[:], sorted10K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})
	bench("Merge/100Kx100K", 5000, func() {
		c := sortedUnion(out[:], sorted100K[:], sorted100K[:])
		if c < 0 {
			fmt.Println(c)
		}
	})

	_ = rand.Int()
}
