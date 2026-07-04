package enumarray

import "testing"

const (
	tokenN   = 1000000
	sortN    = 100000
)

var (
	gTokens    []int
	gResult    int64
	gSortCopy  []int
	gSortTmp   []int
)

func init() {
	gTokens = make([]int, tokenN)
	for i := range gTokens {
		gTokens[i] = i % 20
	}
	gSortCopy = make([]int, sortN)
	gSortTmp = make([]int, sortN)
	for i := 0; i < sortN; i++ {
		gSortCopy[i] = 19 - (i % 20)
	}
}

func BenchmarkTraverse(b *testing.B) {
	for i := 0; i < b.N; i++ {
		count := int64(0)
		for j := 0; j < tokenN; j++ {
			v := gTokens[j]
			if v == 3 || v == 4 || v == 13 {
				count++
			}
		}
		gResult = count
	}
}

func BenchmarkFilterCount(b *testing.B) {
	for i := 0; i < b.N; i++ {
		count := int64(0)
		for j := 0; j < tokenN; j++ {
			if gTokens[j] >= 5 {
				count++
			}
		}
		gResult = count
	}
}

func BenchmarkSumOrdinals(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sum := int64(0)
		for j := 0; j < tokenN; j++ {
			sum += int64(gTokens[j])
		}
		gResult = sum
	}
}

func quickSortGo(a []int, lo, hi int) {
	if lo >= hi {
		return
	}
	pivot := a[(lo+hi)/2]
	i, j := lo, hi
	for i <= j {
		for a[i] < pivot {
			i++
		}
		for a[j] > pivot {
			j--
		}
		if i <= j {
			a[i], a[j] = a[j], a[i]
			i++
			j--
		}
	}
	if lo < j {
		quickSortGo(a, lo, j)
	}
	if i < hi {
		quickSortGo(a, i, hi)
	}
}

func BenchmarkQuickSort(b *testing.B) {
	for i := 0; i < b.N; i++ {
		copy(gSortTmp, gSortCopy)
		quickSortGo(gSortTmp, 0, sortN-1)
	}
}

var gSetResult int

func BenchmarkSetFilter(b *testing.B) {
	for i := 0; i < b.N; i++ {
		count := 0
		for j := 0; j < sortN; j++ {
			v := gSortTmp[j]
			if v == 5 || v == 6 || v == 10 || v == 11 || v == 13 {
				count++
			}
		}
		gSetResult = count
	}
}
