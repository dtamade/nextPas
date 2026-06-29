package sort

import (
	"math/rand"
	"slices"
	"testing"
)

const sortN = 100000
const sortN2 = 1000000

var sortArr []int64
var sortArr2 []int64
var sortSorted []int64
var sortReverse []int64

func init() {
	rng := rand.New(rand.NewSource(12345))
	sortArr = make([]int64, sortN)
	sortArr2 = make([]int64, sortN2)
	sortSorted = make([]int64, sortN)
	sortReverse = make([]int64, sortN)
	for i := 0; i < sortN; i++ {
		sortArr[i] = rng.Int63()
		sortSorted[i] = int64(i)
		sortReverse[i] = int64(sortN - i)
	}
	for i := 0; i < sortN2; i++ {
		sortArr2[i] = rng.Int63()
	}
}

func BenchmarkSort100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		tmp := make([]int64, sortN)
		copy(tmp, sortArr)
		slices.Sort(tmp)
	}
}

func BenchmarkSort1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		tmp := make([]int64, sortN2)
		copy(tmp, sortArr2)
		slices.Sort(tmp)
	}
}

func BenchmarkSortSorted100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		tmp := make([]int64, sortN)
		copy(tmp, sortSorted)
		slices.Sort(tmp)
	}
}

func BenchmarkSortReverse100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		tmp := make([]int64, sortN)
		copy(tmp, sortReverse)
		slices.Sort(tmp)
	}
}
