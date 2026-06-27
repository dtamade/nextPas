// bench_sort_comparison.go — Go 跨语言排序基准
//
// 与 nextPas Pascal 基准同场景对比，输出 benchstat 兼容格式。
package main

import (
	"fmt"
	"math/rand"
	"sort"
	"testing"
)

const (
	N      = 1000
	SEED   = 42
)

func initData() []int {
	r := rand.New(rand.NewSource(SEED))
	data := make([]int, N)
	for i := range data {
		data[i] = r.Intn(1000000)
	}
	return data
}

func BenchmarkInsertionSort(b *testing.B) {
	data := initData()
	b.SetBytes(N * 4)
	for n := 0; n < b.N; n++ {
		d := make([]int, len(data))
		copy(d, data)
		for i := 1; i < len(d); i++ {
			key := d[i]
			j := i - 1
			for j >= 0 && d[j] > key {
				d[j+1] = d[j]
				j--
			}
			d[j+1] = key
		}
	}
}

func BenchmarkQuickSort(b *testing.B) {
	data := initData()
	b.SetBytes(N * 4)
	for n := 0; n < b.N; n++ {
		d := make([]int, len(data))
		copy(d, data)
		sort.Ints(d)
	}
}

func BenchmarkMergeSort(b *testing.B) {
	data := initData()
	b.SetBytes(N * 4)

	mergeSort := func(d []int) []int {
		if len(d) <= 1 {
			return d
		}
		mid := len(d) / 2
		left := mergeSort(d[:mid])
		right := mergeSort(d[mid:])
		result := make([]int, 0, len(d))
		i, j := 0, 0
		for i < len(left) && j < len(right) {
			if left[i] <= right[j] {
				result = append(result, left[i])
				i++
			} else {
				result = append(result, right[j])
				j++
			}
		}
		result = append(result, left[i:]...)
		result = append(result, right[j:]...)
		return result
	}

	for n := 0; n < b.N; n++ {
		d := make([]int, len(data))
		copy(d, data)
		mergeSort(d)
	}
}

func main() {
	fmt.Println("=== Go Sort Benchmark ===")
	fmt.Println("Run with: go test -bench=. -benchmem -count=6 | tee go_bench.txt")
	fmt.Println("Then: benchstat go_bench.txt")
}
