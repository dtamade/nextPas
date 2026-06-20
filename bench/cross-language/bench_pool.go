package main

import (
	"fmt"
	"runtime"
	"sync"
	"sync/atomic"
	"time"
)

const N = 1000000

type TestObj struct {
	Value int
}

func main() {
	fmt.Printf("=== Go sync.Pool Benchmark ===\n")
	fmt.Printf("Go %s, GOMAXPROCS=%d\n\n", runtime.Version(), runtime.GOMAXPROCS(0))

	// --- 1. 直接 alloc/free ---
	t0 := time.Now()
	for i := 0; i < N; i++ {
		obj := &TestObj{Value: i}
		_ = obj
	}
	t1 := time.Now()
	directMs := float64(t1.Sub(t0).Microseconds()) / 1000.0
	fmt.Printf("Direct alloc x%d: %.1f ms (%.0f ops/ms)\n", N, directMs, float64(N)/directMs)

	// --- 2. Pool get/put (single thread) ---
	pool := &sync.Pool{
		New: func() interface{} { return &TestObj{} },
	}
	// warmup
	for i := 0; i < 1000; i++ {
		obj := pool.Get().(*TestObj)
		obj.Value = i
		pool.Put(obj)
	}

	t0 = time.Now()
	for i := 0; i < N; i++ {
		obj := pool.Get().(*TestObj)
		obj.Value = i
		pool.Put(obj)
	}
	t1 = time.Now()
	poolMs := float64(t1.Sub(t0).Microseconds()) / 1000.0
	fmt.Printf("Pool get/put x%d: %.1f ms (%.0f ops/ms)\n", N, poolMs, float64(N)/poolMs)
	fmt.Printf("Pool vs direct: %.1fx\n\n", directMs/poolMs)

	// --- 3. Concurrent pool get/put ---
	for _, threads := range []int{1, 2, 4, 8, 16, 32} {
		perThread := N / threads
		pool = &sync.Pool{
			New: func() interface{} { return &TestObj{} },
		}
		// warmup
		for i := 0; i < 1000; i++ {
			obj := pool.Get().(*TestObj)
			obj.Value = i
			pool.Put(obj)
		}

		var wg sync.WaitGroup
		var ops atomic.Int64
		t0 = time.Now()
		for t := 0; t < threads; t++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for i := 0; i < perThread; i++ {
					obj := pool.Get().(*TestObj)
					obj.Value = i
					pool.Put(obj)
				}
				ops.Add(int64(perThread))
			}()
		}
		wg.Wait()
		t1 = time.Now()
		totalMs := float64(t1.Sub(t0).Microseconds()) / 1000.0
		totalOps := ops.Load()
		fmt.Printf("Pool %2dT x %7d ops: %7.1f ms (%10.0f ops/sec)\n",
			threads, totalOps, totalMs, float64(totalOps)/totalMs*1000)
	}
}
