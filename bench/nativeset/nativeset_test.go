package nativeset

import "testing"

var sinkInt int64

var setA = make(map[uint8]bool, 128)
var setB = make(map[uint8]bool, 128)

func init() {
	for i := 0; i < 128; i++ {
		setA[uint8(i%256)] = true
	}
	for i := 64; i < 192; i++ {
		setB[uint8(i%256)] = true
	}
}

func BenchmarkMembership_256K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		r := 0
		for j := 0; j < 1000; j++ {
			for i := 0; i < 256; i++ {
				if setA[uint8(i)] {
					r++
				}
			}
		}
		sinkInt += int64(r)
	}
}

func BenchmarkIntersection_100K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		r := 0
		for i := 0; i < 100000; i++ {
			c := make(map[uint8]bool, 64)
			for k := range setA {
				if setB[k] {
					c[k] = true
				}
			}
			if c[100] {
				r++
			}
		}
		sinkInt += int64(r)
	}
}

func BenchmarkUnion_100K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		r := 0
		for i := 0; i < 100000; i++ {
			c := make(map[uint8]bool, 192)
			for k := range setA {
				c[k] = true
			}
			for k := range setB {
				c[k] = true
			}
			if c[100] {
				r++
			}
		}
		sinkInt += int64(r)
	}
}
