package enumarray

import "testing"

const tokenN = 1000000

var gTokens []int
var gResult int64

func init() {
	gTokens = make([]int, tokenN)
	for i := range gTokens {
		gTokens[i] = i % 20
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
