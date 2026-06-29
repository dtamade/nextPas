package main

import (
	"fmt"
	"math/bits"
	"time"
)

const N = 100000

var (
	gData [N]uint64
	gSink uint64
)

func init() {
	for i := 0; i < N; i++ {
		gData[i] = uint64(i)*6364136223846793005 + 1442695040888963407
	}
}

func benchPopCnt64(iters int) time.Duration {
	var sum uint64
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += uint64(bits.OnesCount64(gData[i]))
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchPopCntAccum(iters int) time.Duration {
	var sum uint64
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			v := gData[i]
			sum += uint64(bits.OnesCount64(v))
			v ^= 0xFFFFFFFFFFFFFFFF
			sum += uint64(bits.OnesCount64(v))
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchBitReverse(iters int) time.Duration {
	var sum uint64
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			v := gData[i]
			sum += bits.Reverse64(v)
		}
	}
	gSink = sum
	return time.Since(start)
}

func runBench(name string, fn func(int) time.Duration) {
	// warmup
	fn(5)
	// measure
	best := time.Duration(1<<63 - 1)
	var bestIters int
	for _, iters := range []int{10, 50, 100, 500} {
		d := fn(iters)
		nsOp := float64(d) / float64(iters) / float64(N)
		if nsOp > 0 && d < best {
			best = d
			bestIters = iters
		}
	}
	nsPerOp := float64(best) / float64(bestIters) / float64(N)
	fmt.Printf("%-20s %6d iters  %8.1f ns/op  (total=%v, N=%d)\n", name, bestIters, nsPerOp, best, N)
}

func main() {
	runBench("PopCnt/100K", benchPopCnt64)
	runBench("PopCntAccum/200K", benchPopCntAccum)
	runBench("BitReverse/100K", benchBitReverse)
}
