package fncall

import (
	"testing"
)

var sinkInt int64

func ackermann(m, n int64) int64 {
	if m == 0 {
		return n + 1
	} else if n == 0 {
		return ackermann(m-1, 1)
	}
	return ackermann(m-1, ackermann(m, n-1))
}

func BenchmarkAckermann_3_5(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt += ackermann(3, 5)
	}
}

func BenchmarkAckermann_3_6(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt += ackermann(3, 6)
	}
}
