package main

// conc_bench_test.go
// Go concurrent allocator benchmark — matches Pascal conc_bench.pas parameters

import (
	"fmt"
	"sync"
	"testing"
)

const (
	OPS_PER_THREAD = 100000
	SMALL_SIZE     = 64
	LARGE_SIZE     = 1024
)

var sink [][]byte

func concurrentAlloc(b *testing.B, size int, threads int) {
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var wg sync.WaitGroup
		wg.Add(threads)
		for t := 0; t < threads; t++ {
			go func() {
				defer wg.Done()
				local := make([][]byte, 0, 100)
				for i := 0; i < OPS_PER_THREAD; i++ {
					p := make([]byte, size)
					local = append(local, p)
					if len(local) >= 100 {
						local = local[:0]
					}
				}
			}()
		}
		wg.Wait()
	}
}

func BenchmarkConc64_4(b *testing.B)  { concurrentAlloc(b, SMALL_SIZE, 4) }
func BenchmarkConc64_8(b *testing.B)  { concurrentAlloc(b, SMALL_SIZE, 8) }
func BenchmarkConc64_16(b *testing.B) { concurrentAlloc(b, SMALL_SIZE, 16) }
func BenchmarkConc1K_4(b *testing.B)  { concurrentAlloc(b, LARGE_SIZE, 4) }
func BenchmarkConc1K_8(b *testing.B)  { concurrentAlloc(b, LARGE_SIZE, 8) }
func BenchmarkConc1K_16(b *testing.B) { concurrentAlloc(b, LARGE_SIZE, 16) }

func main() {
	fmt.Println("Use: go test -bench=Conc -benchtime=3s")
}
