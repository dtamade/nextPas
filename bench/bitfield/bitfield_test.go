package bitfield

import "testing"

var sinkInt int64
const bits = 65536

var bitfield [bits / 8]byte

func init() {
	for i := 0; i < bits; i++ {
		if i%3 == 0 || i%5 == 0 {
			bitfield[i/8] |= 1 << uint(i%8)
		}
	}
}

func BenchmarkPopCount_64K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		c := 0
		for i := 0; i < bits/8; i++ {
			v := bitfield[i]
			for v != 0 {
				c++
				v &= v - 1 // Brian Kernighan
			}
		}
		sinkInt += int64(c)
	}
}

func BenchmarkSetRange_64Kx1K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for j := 0; j < 1000; j++ {
			for i := 0; i < bits; i++ {
				byteIdx := i / 8
				bitIdx := uint(i % 8)
				if i%7 == 0 {
					bitfield[byteIdx] |= 1 << bitIdx
				} else {
					bitfield[byteIdx] &^= 1 << bitIdx
				}
			}
		}
		sinkInt++
	}
}

func BenchmarkTestRange_64Kx1K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		c := 0
		for j := 0; j < 1000; j++ {
			for i := 0; i < bits; i++ {
				if bitfield[i/8]&(1<<uint(i%8)) != 0 {
					c++
				}
			}
		}
		sinkInt += int64(c)
	}
}
