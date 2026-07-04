package search

import (
	"fmt"
	"math/rand"
	"testing"
)

const searchN = 100000
const searchQueries = 100000

var searchSorted []int64
var searchQueriesArr []int64

func init() {
	searchSorted = make([]int64, searchN)
	for i := 0; i < searchN; i++ {
		searchSorted[i] = int64(i * 3)
	}
	rng := rand.New(rand.NewSource(12345))
	searchQueriesArr = make([]int64, searchQueries)
	for i := 0; i < searchQueries; i++ {
		searchQueriesArr[i] = int64(rng.Int31n(int32(searchN * 3)))
	}
}

func binarySearch(a []int64, key int64) int {
	lo, hi := 0, len(a)-1
	for lo <= hi {
		mid := lo + (hi-lo)/2
		if a[mid] == key {
			return mid
		} else if a[mid] < key {
			lo = mid + 1
		} else {
			hi = mid - 1
		}
	}
	return -1
}

func BenchmarkBinarySearch100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		found := 0
		for i := 0; i < searchQueries; i++ {
			found = binarySearch(searchSorted, searchQueriesArr[i])
		}
		if found < 0 {
			fmt.Println()
		}
	}
}

func BenchmarkBinarySearchHit100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		found := 0
		for i := 0; i < searchQueries; i++ {
			found = binarySearch(searchSorted, searchSorted[i%searchN])
		}
		if found < 0 {
			fmt.Println()
		}
	}
}
