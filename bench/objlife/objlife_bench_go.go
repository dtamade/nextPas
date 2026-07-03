// Object lifecycle benchmark — Go
package main

import (
	"fmt"
	"time"
)

const N = 100000

type Node struct {
	next  *Node
	value int64
	pad   [48]byte
}

func main() {
	fmt.Println("=== Object Lifecycle Benchmark (Go) ===")

	rounds := 100
	totalOps := int64(rounds * N)

	// AllocFree: allocate N nodes in linked list, then let GC handle
	start := time.Now()
	for r := 0; r < rounds; r++ {
		var head *Node
		for i := 0; i < N; i++ {
			n := &Node{value: int64(i), next: head}
			head = n
		}
		// In Go, we don't explicitly free. The GC handles it.
		// Just nil out the reference.
		head = nil
	}
	elapsed := time.Since(start)
	fmt.Printf("AllocFree:        %d ops in %v (%.1f ns/op)\n", totalOps, elapsed,
		float64(elapsed.Nanoseconds())/float64(totalOps))

	// AllocFreeShuffle: allocate into slice, then nil all
	start = time.Now()
	for r := 0; r < rounds; r++ {
		arr := make([]*Node, N)
		for i := 0; i < N; i++ {
			arr[i] = &Node{value: int64(i)}
		}
		for i := N - 1; i >= 0; i-- {
			arr[i] = nil
		}
	}
	elapsed = time.Since(start)
	fmt.Printf("AllocFreeShuffle: %d ops in %v (%.1f ns/op)\n", totalOps, elapsed,
		float64(elapsed.Nanoseconds())/float64(totalOps))

	// LinkedBuild: build linked list, traverse, discard
	start = time.Now()
	for r := 0; r < rounds; r++ {
		var head *Node
		for i := 0; i < N; i++ {
			n := &Node{value: int64(i), next: head}
			head = n
		}
		sum := int64(0)
		for cur := head; cur != nil; cur = cur.next {
			sum += cur.value
		}
		_ = sum
		head = nil
	}
	elapsed = time.Since(start)
	fmt.Printf("LinkedBuild:      %d ops in %v (%.1f ns/op)\n", totalOps, elapsed,
		float64(elapsed.Nanoseconds())/float64(totalOps))
}
