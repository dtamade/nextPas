package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

// Q5 matched scenarios vs nextpas TLockFreeChannel (same OPS/CAPACITY).
const Ops = 1000000
const Capacity = 1024

var sink uint64

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

// C1: buffered chan 1P+1C (closest Go peer to TLockFreeChannel 1P+1C).
func benchC1() uint64 {
	ch := make(chan uint64, Capacity)
	var wg sync.WaitGroup
	var sum uint64

	start := time.Now()
	wg.Add(2)
	go func() {
		defer wg.Done()
		for value := uint64(1); value <= Ops; value++ {
			ch <- value
		}
	}()
	go func() {
		defer wg.Done()
		for i := 0; i < Ops; i++ {
			sum += <-ch
		}
	}()
	wg.Wait()

	printResult("C1 chan uint64 1P+1C", time.Since(start), Ops)
	return sum
}

// C2: buffered chan 2P+2C.
func benchC2() uint64 {
	ch := make(chan uint64, Capacity)
	results := make(chan uint64, 2)
	var wg sync.WaitGroup

	start := time.Now()
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for value := uint64(1); value <= Ops/2; value++ {
				ch <- value
			}
		}()
	}
	for i := 0; i < 2; i++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			localSum := uint64(0)
			for j := 0; j < Ops/2; j++ {
				localSum += <-ch
			}
			results <- localSum
		}()
	}
	wg.Wait()
	close(results)

	sum := uint64(0)
	for value := range results {
		sum += value
	}
	printResult("C2 chan uint64 2P+2C", time.Since(start), Ops)
	return sum
}

func main() {
	fmt.Println("=== Q5 Go matched suite (chan vs nextpas Channel) ===")
	fmt.Println("Platform:", runtime.GOOS, runtime.GOARCH)
	fmt.Println("Compiler: go build (gc)")
	fmt.Printf("Input: OPS=%d CAPACITY=%d scenarios=C1 1P+1C, C2 2P+2C\n", Ops, Capacity)
	fmt.Println("Peer: nextpas TLockFreeChannel (bounded sequence channel)")
	fmt.Println("Honesty: not bit-identical to lockfree channel; same-host relative only + envelope.")
	fmt.Println()

	sink = benchC1()
	sink += benchC2()
	runtime.KeepAlive(sink)

	fmt.Println()
	fmt.Printf("Sink: %d\n", sink)
	fmt.Println("Done.")
}
