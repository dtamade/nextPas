package boolsum

import "testing"

const boolN = 1000000

var gBools []bool
var gResult int64

func init() {
	gBools = make([]bool, boolN)
	for i := range gBools {
		gBools[i] = (i%3 == 0)
	}
}

func BenchmarkBoolSum(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sum := int64(0)
		for j := 0; j < boolN; j++ {
			if gBools[j] {
				sum++
			}
		}
		gResult = sum
	}
}
