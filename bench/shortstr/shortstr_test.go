package shortstr

import (
	"testing"
)

var sinkInt int64

func BenchmarkCopy_100K(b *testing.B) {
	s1 := "Hello World! This is a test of short string copy operations, 255 max."
	for n := 0; n < b.N; n++ {
		for i := 0; i < 100000; i++ {
			s2 := s1
			if s2[0] == 'H' {
				sinkInt++
			}
			_ = s2
		}
	}
}

func BenchmarkAppend_1K(b *testing.B) {
	chunk := "abcdefghij" // 10 chars
	for n := 0; n < b.N; n++ {
		s := ""
		for i := 0; i < 1000; i++ {
			s += chunk
		}
		sinkInt += int64(len(s))
	}
}

func BenchmarkCompare_100K(b *testing.B) {
	a := "abcdefghijklmnopqrstuvwxyz0123456789"
	bb := "abcdefghijklmnopqrstuvwxyz0123456789"
	for n := 0; n < b.N; n++ {
		r := 0
		for i := 0; i < 100000; i++ {
			if a == bb {
				r++
			}
			bb = string(rune('a'+byte(i%26))) + bb[1:]
		}
		sinkInt += int64(r)
	}
}
