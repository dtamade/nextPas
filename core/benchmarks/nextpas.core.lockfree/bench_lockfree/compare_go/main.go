package main

import (
	"fmt"
	"runtime"
	"sync"
	"time"
)

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

func benchChannelSPSC() uint64 {
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

	printResult("chan uint64 1P+1C", time.Since(start), Ops)
	return sum
}

func benchChannelMPMC() uint64 {
	ch := make(chan uint64, Capacity)
	results := make(chan uint64, 2)
	var wg sync.WaitGroup

	start := time.Now()
	for producerIndex := 0; producerIndex < 2; producerIndex++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for value := uint64(1); value <= Ops/2; value++ {
				ch <- value
			}
		}()
	}

	for consumerIndex := 0; consumerIndex < 2; consumerIndex++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			localSum := uint64(0)
			for i := 0; i < Ops/2; i++ {
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

	printResult("chan uint64 2P+2C", time.Since(start), Ops)
	return sum
}

func benchChannelSingleThread() uint64 {
	ch := make(chan uint64, Capacity)
	sum := uint64(0)

	start := time.Now()
	for value := uint64(1); value <= Ops; value++ {
		ch <- value
		sum += <-ch
	}

	printResult("chan uint64 1T", time.Since(start), Ops)
	return sum
}

func main() {
	fmt.Println("=== Go channel lockfree comparison (1M ops) ===")
	fmt.Println("Platform:", runtime.GOOS, runtime.GOARCH)
	fmt.Println("Compiler flags: go build (default optimized gc toolchain; recommended manual command)")
	fmt.Println("Input size: OPS=1000000; capacity=1024; scenarios=chan uint64 1P+1C, chan uint64 2P+2C, chan uint64 1T")
	fmt.Println("Baselines: Go channel synchronization primitives only; manual comparison source, not auto-run by Pascal benchmark")
	fmt.Println()

	sink = benchChannelSPSC()
	sink += benchChannelMPMC()
	sink += benchChannelSingleThread()
	runtime.KeepAlive(sink)

	fmt.Println()
	fmt.Printf("Sink: %d\n", sink)
	fmt.Println("Done.")
}
