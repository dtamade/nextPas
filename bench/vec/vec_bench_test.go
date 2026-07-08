package vec

import (
	"fmt"
	"testing"
)

// --- Array Fill 1M elements (8MB) ---
func BenchmarkArrayFill_1M(b *testing.B) {
	arr := make([]int64, 1000000)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for i := range arr {
			arr[i] = 0
		}
	}
}

// --- Array Sum 1M elements ---
func BenchmarkArraySum_1M(b *testing.B) {
	arr := make([]int64, 1000000)
	for i := range arr {
		arr[i] = int64(i)
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var sum int64
		for i := 0; i < len(arr); i++ {
			sum += arr[i]
		}
		_ = sum
	}
}

// --- Array Reverse 1M elements ---
func BenchmarkArrayReverse_1M(b *testing.B) {
	arr := make([]int64, 1000000)
	for i := range arr {
		arr[i] = int64(i)
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for i, j := 0, len(arr)-1; i < j; i, j = i+1, j-1 {
			arr[i], arr[j] = arr[j], arr[i]
		}
	}
}

// --- Array Scan 1000 lookups in 100k ---
func BenchmarkArrayScan_100k(b *testing.B) {
	arr := make([]int64, 100000)
	for i := range arr {
		arr[i] = int64(i*3 + 7)
	}
	targets := make([]int64, 1000)
	for i := range targets {
		targets[i] = int64((i*7919)%100000)*3 + 7
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for _, t := range targets {
			for j := 0; j < len(arr); j++ {
				if arr[j] == t {
					break
				}
			}
		}
	}
}

func TestMain(m *testing.M) {
	m.Run()
	fmt.Println("vec/array bench: use 'go test -bench=.' to run benchmarks")
}
