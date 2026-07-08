package bitpack

import "testing"

const (
	n     = 8192
	iters = 10000
)

var (
	src      [n]byte
	dst      [n]byte
	wordSrc  [n]uint16
	longSrc  [n]uint32
	sink     uint64
)

func init() {
	seed := uint32(42)
	for i := 0; i < n; i++ {
		seed = seed*1103515245 + 12345
		src[i] = byte(seed)
		wordSrc[i] = uint16(seed)
		longSrc[i] = seed
	}
}

func BenchmarkNonZeroCount(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		count := uint64(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				if src[i] != 0 {
					count++
				}
			}
		}
		sink = count
	}
}

func BenchmarkByteSum(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		sum := uint64(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				sum += uint64(src[i])
			}
		}
		sink = sum
	}
}

func BenchmarkByteMax(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		totalMax := uint64(0)
		for iter := 0; iter < iters; iter++ {
			maxVal := byte(0)
			for i := 0; i < n; i++ {
				if src[i] > maxVal {
					maxVal = src[i]
				}
			}
			totalMax += uint64(maxVal)
		}
		sink = totalMax
	}
}

func BenchmarkXorAccum(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		xorVal := byte(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				xorVal ^= src[i]
			}
		}
		sink = uint64(xorVal)
	}
}

func BenchmarkMaskCopy(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		j := 0
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				if src[i] > 128 {
					dst[j&(n-1)] = src[i]
					j++
				}
			}
		}
		sink = uint64(j)
	}
}

func BenchmarkWordSum(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		sum := uint64(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				sum += uint64(wordSrc[i])
			}
		}
		sink = sum
	}
}

func BenchmarkDWordSum(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		sum := uint64(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				sum += uint64(longSrc[i])
			}
		}
		sink = sum
	}
}

func BenchmarkNibbleSwap(b *testing.B) {
	for nn := 0; nn < b.N; nn++ {
		sum := uint64(0)
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				dst[i] = (src[i] << 4) | (src[i] >> 4)
				sum += uint64(dst[i])
			}
		}
		sink = sum
	}
}
