package main

import (
	"fmt"
	"time"
)

const (
	SIZE_4K   = 4096
	SIZE_16K  = 16384
	SIZE_64K  = 65536
	SIZE_256K = 262144
)

var (
	gSrc4K   [SIZE_4K]byte
	gDst4K   [SIZE_4K]byte
	gSrc16K  [SIZE_16K]byte
	gDst16K  [SIZE_16K]byte
	gSrc64K  [SIZE_64K]byte
	gDst64K  [SIZE_64K]byte
	gSrc256K [SIZE_256K]byte
	gDst256K [SIZE_256K]byte
)

func init() {
	for i := 0; i < SIZE_256K; i++ {
		if i < SIZE_4K {
			gSrc4K[i] = byte(i*7 + 3)
		}
		if i < SIZE_16K {
			gSrc16K[i] = byte(i*13 + 5)
		}
		if i < SIZE_64K {
			gSrc64K[i] = byte(i*17 + 11)
		}
		gSrc256K[i] = byte(i*19 + 7)
	}
}

func benchMove4K(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		copy(gDst4K[:], gSrc4K[:])
	}
	return time.Since(start)
}

func benchMove16K(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		copy(gDst16K[:], gSrc16K[:])
	}
	return time.Since(start)
}

func benchMove64K(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		copy(gDst64K[:], gSrc64K[:])
	}
	return time.Since(start)
}

func benchMove256K(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		copy(gDst256K[:], gSrc256K[:])
	}
	return time.Since(start)
}

func benchMove4KLoop(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < 100; i++ {
			copy(gDst4K[:], gSrc4K[:])
		}
	}
	return time.Since(start)
}

func benchMove16KLoop(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < 100; i++ {
			copy(gDst16K[:], gSrc16K[:])
		}
	}
	return time.Since(start)
}

func benchMove64KLoop(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < 100; i++ {
			copy(gDst64K[:], gSrc64K[:])
		}
	}
	return time.Since(start)
}

func benchMove256KLoop(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < 100; i++ {
			copy(gDst256K[:], gSrc256K[:])
		}
	}
	return time.Since(start)
}

func runBench(name string, fn func(int) time.Duration) {
	fn(1000)
	iters := 1000
	d := fn(iters)
	for d < 200*time.Millisecond {
		iters *= 2
		d = fn(iters)
	}
	fmt.Printf("%-20s %6d iters  %10.1f ns/op\n", name, iters, float64(d)/float64(iters))
}

func main() {
	runBench("Move/4K", benchMove4K)
	runBench("Move/16K", benchMove16K)
	runBench("Move/64K", benchMove64K)
	runBench("Move/256K", benchMove256K)
	runBench("Move4K/x100", benchMove4KLoop)
	runBench("Move16K/x100", benchMove16KLoop)
	runBench("Move64K/x100", benchMove64KLoop)
	runBench("Move256K/x100", benchMove256KLoop)
}
