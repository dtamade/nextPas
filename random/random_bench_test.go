package main

import (
	"math/rand"
	"testing"
)

const N1M = 1000000

var gResult int64

func BenchmarkRandomInt_1M(b *testing.B) {
	rng := rand.New(rand.NewSource(42))
	for i := 0; i < b.N; i++ {
		var s int64
		for j := 0; j < N1M; j++ {
			s += rng.Int63n(int64(1<<31 - 1))
		}
		gResult = s
	}
}

func BenchmarkRandomFloat_1M(b *testing.B) {
	rng := rand.New(rand.NewSource(42))
	for i := 0; i < b.N; i++ {
		var s float64
		for j := 0; j < N1M; j++ {
			s += rng.Float64()
		}
		gResult = int64(s)
	}
}
