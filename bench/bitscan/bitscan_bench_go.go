package main

import (
	"fmt"
	"math/bits"
	"time"
)

const N = 100000

var (
	gData [N]uint64
	gSink int
)

func init() {
	for i := 0; i < N; i++ {
		gData[i] = uint64(i)*6364136223846793005 + 1442695040888963407 | (1 << (i % 64))
	}
}

func benchTrailingZeros(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += bits.TrailingZeros64(gData[i])
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchLeadingZeros(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += bits.LeadingZeros64(gData[i])
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchTrailLead(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			sum += bits.TrailingZeros64(gData[i]) + bits.LeadingZeros64(gData[i])
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchByteSwap(iters int) time.Duration {
	var sum uint64
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < N; i++ {
			v := gData[i]
			v = (v&0x00000000FFFFFFFF)<<32 | (v&0xFFFFFFFF00000000)>>32
			v = (v&0x0000FFFF0000FFFF)<<16 | (v&0xFFFF0000FFFF0000)>>16
			v = (v&0x00FF00FF00FF00FF)<<8 | (v&0xFF00FF00FF00FF00)>>8
			sum += v
		}
	}
	gSink = int(sum)
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
	runBench("BsfQWord/100K", benchTrailingZeros)
	runBench("BsrQWord/100K", benchLeadingZeros)
	runBench("BsfBsr/100K", benchTrailLead)
	runBench("ByteSwap/100K", benchByteSwap)
}
