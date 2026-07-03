package main

import (
	"testing"
)

const N10M = 10000000

var gResult bool

func BenchmarkSetContains_10M(b *testing.B) {
	s := make(map[byte]bool, 128)
	for i := 0; i < 128; i++ {
		s[byte(i)] = true
	}
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10M; j++ {
			if s[byte(j&255)] {
				c++
			}
		}
		gResult = c > 0
	}
}

func BenchmarkSetContainsSparse_10M(b *testing.B) {
	s := []byte{0, 32, 65, 90, 97, 122, 255}
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10M; j++ {
			ch := byte(j & 255)
			for _, v := range s {
				if ch == v {
					c++
					break
				}
			}
		}
		gResult = c > 0
	}
}
