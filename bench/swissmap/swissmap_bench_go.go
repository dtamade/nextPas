package main

import (
	"fmt"
	"time"
)

const (
	N1K   = 1000
	N10K  = 10000
	N100K = 100000
)

var keys1K, keys10K, keys100K, shuffledKeys []int

func init() {
	keys100K = make([]int, N100K)
	keys10K = make([]int, N10K)
	keys1K = make([]int, N1K)
	for i := 0; i < N100K; i++ {
		k := int(uint32(i*2654435761) & 0x7FFFFFFF)
		keys100K[i] = k
		if i < N10K {
			keys10K[i] = k
		}
		if i < N1K {
			keys1K[i] = k
		}
	}
	shuffledKeys = make([]int, N100K)
	for i := 0; i < N100K; i++ {
		shuffledKeys[i] = int(uint32((i+N100K)*2654435761) & 0x7FFFFFFF)
	}
}

func benchPut(n int, keys []int) int {
	m := make(map[int]int, n)
	for i := 0; i < n; i++ {
		m[keys[i]] = i
	}
	return m[keys[0]]
}

func benchLookup(n int, keys []int) int {
	m := make(map[int]int, n)
	for i := 0; i < n; i++ {
		m[keys[i]] = i
	}
	sum := 0
	for i := 0; i < n; i++ {
		sum += m[keys[i]]
	}
	return sum
}

func benchMiss(n int, keys []int) int {
	m := make(map[int]int, n)
	for i := 0; i < n; i++ {
		m[keys[i]] = i
	}
	count := 0
	for i := 0; i < n; i++ {
		if _, ok := m[shuffledKeys[i]]; ok {
			count++
		}
	}
	return count
}

func benchmark(name string, fn func() int) {
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
	benchmark("GoMap/Put/1K", func() int { return benchPut(N1K, keys1K) })
	benchmark("GoMap/Put/10K", func() int { return benchPut(N10K, keys10K) })
	benchmark("GoMap/Put/100K", func() int { return benchPut(N100K, keys100K) })
	benchmark("GoMap/Lookup/1K", func() int { return benchLookup(N1K, keys1K) })
	benchmark("GoMap/Lookup/10K", func() int { return benchLookup(N10K, keys10K) })
	benchmark("GoMap/Miss/1K", func() int { return benchMiss(N1K, keys1K) })
}
