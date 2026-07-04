package main

import (
	"fmt"
	"time"
)

const N = 100000

var gSink int

func benchBuildAppend(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		arr := make([]int, 0)
		for i := 0; i < N; i++ {
			arr = append(arr, i)
		}
		gSink = len(arr)
	}
	return time.Since(start)
}

func benchBuildPrealloc(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		arr := make([]int, N)
		for i := 0; i < N; i++ {
			arr[i] = i
		}
		gSink = len(arr)
	}
	return time.Since(start)
}

func benchBuildDoubling(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		arr := make([]int, 0, 16)
		for i := 0; i < N; i++ {
			arr = append(arr, i)
		}
		gSink = len(arr)
	}
	return time.Since(start)
}

func benchConcat(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		a := make([]int, N/2)
		b := make([]int, N/2)
		for i := 0; i < N/2; i++ {
			a[i] = i
			b[i] = i + N/2
		}
		c := make([]int, 0, N)
		c = append(c, a...)
		c = append(c, b...)
		gSink = len(c)
	}
	return time.Since(start)
}

func benchSliceCopy(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		src := make([]int, N)
		for i := 0; i < N; i++ {
			src[i] = i
		}
		dst := make([]int, N)
		for i := 0; i < 100; i++ {
			copy(dst, src[i*1000:i*1000+500])
		}
		gSink = len(dst)
	}
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
	runBench("BuildAppend/100K", benchBuildAppend)
	runBench("BuildPrealloc/100K", benchBuildPrealloc)
	runBench("BuildDoubling/100K", benchBuildDoubling)
	runBench("Concat/100K", benchConcat)
	runBench("SliceCopy/100K", benchSliceCopy)
}
