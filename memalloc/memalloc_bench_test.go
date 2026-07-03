package main

import (
	"testing"
	"unsafe"
)

const N100K = 100000

var gResult interface{}

func BenchmarkMake64_100K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < N100K; j++ {
			p := make([]byte, 64)
			p[0] = 1
			gResult = p
		}
	}
}

func BenchmarkMake1K_100K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < N100K; j++ {
			p := make([]byte, 1024)
			p[0] = 1
			gResult = p
		}
	}
}

func BenchmarkMake4K_100K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < N100K; j++ {
			p := make([]byte, 4096)
			p[0] = 1
			gResult = p
		}
	}
}

func BenchmarkNewStruct_100K(b *testing.B) {
	type Rec struct{ A, B, C, D int64 }
	for i := 0; i < b.N; i++ {
		for j := 0; j < N100K; j++ {
			p := new(Rec)
			p.A = 1
			gResult = unsafe.Pointer(p)
		}
	}
}
