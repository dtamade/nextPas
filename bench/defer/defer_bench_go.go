package main

import (
	"fmt"
	"time"
)

const N = 100000

var (
	gData [N]int
	gSink int
)

func init() {
	for i := 0; i < N; i++ {
		gData[i] = i
	}
}

func benchNoDefer(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += gData[i]
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchDeferOuter(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		func() {
			defer func() {}()
			for i := 0; i < N; i++ {
				sum += gData[i]
			}
		}()
	}
	gSink = sum
	return time.Since(start)
}

func benchDeferCall(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += getVal(i)
		}
	}
	gSink = sum
	return time.Since(start)
}

func getVal(i int) int {
	return gData[i]
}

func benchDeferCallOuter(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		func() {
			defer func() {}()
			for i := 0; i < N; i++ {
				sum += getVal(i)
			}
		}()
	}
	gSink = sum
	return time.Since(start)
}

func runBench(name string, fn func(int) time.Duration) {
	fn(10)
	iters := 10
	d := fn(iters)
	for d < 200*time.Millisecond {
		iters *= 2
		d = fn(iters)
	}
	fmt.Printf("%-20s %6d iters  %10.1f ns/op\n", name, iters, float64(d)/float64(iters))
}

func main() {
	runBench("NoDefer/100K", benchNoDefer)
	runBench("DeferOuter/100K", benchDeferOuter)
	runBench("Call/100K", benchDeferCall)
	runBench("CallDeferOuter/100K", benchDeferCallOuter)
}
