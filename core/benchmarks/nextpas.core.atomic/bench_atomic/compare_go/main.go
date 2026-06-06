package main

import (
	"fmt"
	"runtime"
	"sync/atomic"
	"time"
)

const Iters = 1000000

var sink32 int32
var sinkU32 uint32

func printResult(name string, elapsed time.Duration, operations int64) {
	elapsedNs := elapsed.Nanoseconds()
	if elapsedNs <= 0 {
		elapsedNs = 1
	}
	nsPerOp := float64(elapsedNs) / float64(operations)
	mops := float64(operations) / (float64(elapsedNs) / 1_000_000_000.0) / 1_000_000.0
	fmt.Printf("  %-34s %8.2f ms  %6.1f M ops/sec  %5.1f ns/op\n",
		name,
		float64(elapsedNs)/1_000_000.0,
		mops,
		nsPerOp)
}

func benchPlainBaseline() int32 {
	var value int32
	start := time.Now()
	for i := 0; i < Iters; i++ {
		value += int32((i & 1) + 1)
	}
	printResult("Plain local increment 1M", time.Since(start), Iters)
	return value
}

func benchAtomicLoadStore32() int32 {
	var value int32
	var sink int32
	start := time.Now()
	for i := 1; i <= Iters; i++ {
		atomic.StoreInt32(&value, int32(i))
		sink = atomic.LoadInt32(&value)
	}
	printResult("AtomicLoad/Store32 2M", time.Since(start), Iters*2)
	return sink
}

func benchAtomicFetchAdd32() int32 {
	var value int32
	start := time.Now()
	for i := 0; i < Iters; i++ {
		atomic.AddInt32(&value, 1)
	}
	printResult("AtomicFetchAdd32 1M", time.Since(start), Iters)
	return atomic.LoadInt32(&value)
}

func benchAtomicCompareExchange32() int32 {
	var value int32
	start := time.Now()
	for i := 1; i <= Iters; i++ {
		if !atomic.CompareAndSwapInt32(&value, int32(i-1), int32(i)) {
			panic("unexpected compare-and-swap failure")
		}
	}
	printResult("AtomicCompareExchange32 1M", time.Since(start), Iters)
	return atomic.LoadInt32(&value)
}

func benchTypedAtomicUInt32() uint32 {
	var value atomic.Uint32
	start := time.Now()
	for i := 0; i < Iters; i++ {
		value.Add(1)
	}
	printResult("TAtomicUInt32 FetchAdd 1M", time.Since(start), Iters)
	return value.Load()
}

func main() {
	fmt.Println("=== Go sync/atomic comparison (1M iterations) ===")
	fmt.Println("Platform:", runtime.GOOS, runtime.GOARCH)
	fmt.Println("Compiler flags: go build (default optimized gc toolchain; recommended manual command)")
	fmt.Println("Input size: ITERS=1000000; scenarios=plain baseline, AtomicLoad/Store32, AtomicFetchAdd32, AtomicCompareExchange32, TAtomicUInt32")
	fmt.Println("Baselines: Go sync/atomic single-thread operations; manual comparison source, not auto-run by Pascal benchmark")
	fmt.Println()

	sink32 = benchPlainBaseline() ^
		benchAtomicLoadStore32() ^
		benchAtomicFetchAdd32() ^
		benchAtomicCompareExchange32()
	sinkU32 = benchTypedAtomicUInt32()
	runtime.KeepAlive(sink32)
	runtime.KeepAlive(sinkU32)

	fmt.Println()
	fmt.Printf("Sink: %d/%d\n", sink32, sinkU32)
	fmt.Println("Done.")
}
