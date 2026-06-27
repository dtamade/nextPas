package main

import (
	"fmt"
	"sync"
	"time"
)

const (
	BLOCK_SIZE    = 64
	POOL_CAPACITY = 4096
	RING_CAPACITY = 1024
	ITERS         = 1000000
)

func benchGetMemFreeMem() {
	start := time.Now()
	for i := 0; i < ITERS; i++ {
		b := make([]byte, BLOCK_SIZE)
		_ = b
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(ITERS)
	fmt.Printf("  Go make/free_64B            %10d iters  %8.1f ns/op\n", ITERS, nsPerOp)
}

func benchSyncPool() {
	pool := &sync.Pool{
		New: func() interface{} {
			b := make([]byte, BLOCK_SIZE)
			return &b
		},
	}
	start := time.Now()
	for i := 0; i < ITERS; i++ {
		obj := pool.Get()
		pool.Put(obj)
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(ITERS)
	fmt.Printf("  Go sync.Pool Get/Put_64B    %10d iters  %8.1f ns/op\n", ITERS, nsPerOp)
}

func benchChan() {
	ch := make(chan int, RING_CAPACITY)
	start := time.Now()
	for i := 0; i < ITERS; i++ {
		ch <- i
		<-ch
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(ITERS)
	fmt.Printf("  Go chan send/recv_int       %10d iters  %8.1f ns/op\n", ITERS, nsPerOp)
}

func main() {
	fmt.Println("--- Go pool/buffer benchmarks ---")
	benchGetMemFreeMem()
	benchSyncPool()
	benchChan()
}
