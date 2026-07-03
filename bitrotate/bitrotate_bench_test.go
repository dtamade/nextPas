package main

import (
	"math/bits"
	"testing"
)

const N1M = 1000000

var gResult uint64

func BenchmarkRol64_1M(b *testing.B) {
	for i := 0; i < b.N; i++ {
		v := uint64(0x123456789ABCDEF0)
		for j := 0; j < N1M; j++ {
			v = bits.RotateLeft64(v, (j&31)+1)
		}
		gResult = v
	}
}

func BenchmarkRor64_1M(b *testing.B) {
	for i := 0; i < b.N; i++ {
		v := uint64(0x123456789ABCDEF0)
		for j := 0; j < N1M; j++ {
			v = bits.RotateLeft64(v, -((j & 31) + 1))
		}
		gResult = v
	}
}
