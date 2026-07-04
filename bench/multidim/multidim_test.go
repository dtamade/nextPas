package multidim

import "testing"

const (
	n       = 1000
	m       = 1000
	accessN = 150
)

var gMatrix [][]float64
var gResult float64

func init() {
	gMatrix = make([][]float64, n)
	for i := range gMatrix {
		gMatrix[i] = make([]float64, m)
	}
}

func BenchmarkRandomRead(b *testing.B) {
	for i := 0; i < b.N; i++ {
		seed := uint32(12345)
		s := 0.0
		for k := 0; k < accessN; k++ {
			seed ^= seed << 13
			seed ^= seed >> 17
			seed ^= seed << 5
			r := int((seed & 0xFFFF)) % n
			c := int((seed>>16)&0xFFFF) % m
			s += gMatrix[r][c]
		}
		gResult = s
	}
}

func BenchmarkRandomWrite(b *testing.B) {
	for i := 0; i < b.N; i++ {
		seed := uint32(12345)
		for k := 0; k < accessN; k++ {
			seed ^= seed << 13
			seed ^= seed >> 17
			seed ^= seed << 5
			r := int((seed & 0xFFFF)) % n
			c := int((seed>>16)&0xFFFF) % m
			gMatrix[r][c] = float64(k)
		}
	}
}

func BenchmarkLinearScan(b *testing.B) {
	for i := 0; i < b.N; i++ {
		s := 0.0
		for r := 0; r < 10; r++ {
			for c := 0; c < m; c++ {
				s += gMatrix[r][c]
			}
		}
		gResult = s
	}
}
