package arrayops

import "testing"

const (
	arrN   = 100000
	arrSZ  = 4096
	arrArr = 10000
)

var (
	ga    [arrSZ]byte
	sinkI int
)

func init() {
	for i := 0; i < arrSZ; i++ {
		ga[i] = byte((i*7 + 13) & 255)
	}
}

func BenchmarkByteFrequency(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var freq [256]int
		for i := 0; i < arrN; i++ {
			for j := 0; j < arrSZ; j++ {
				freq[ga[j]]++
			}
		}
		sinkI = freq[0]
	}
}

func BenchmarkArrayReverse(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var a [arrArr]int
		for i := 0; i < arrArr; i++ {
			a[i] = i
		}
		for i := 0; i < arrN; i++ {
			for j := 0; j < arrArr/2; j++ {
				a[j], a[arrArr-1-j] = a[arrArr-1-j], a[j]
			}
		}
		sinkI = a[0]
	}
}

func BenchmarkArrayRotate(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var a [arrArr]int
		for i := 0; i < arrArr; i++ {
			a[i] = i
		}
		for i := 0; i < arrN; i++ {
			first := a[0]
			for j := 0; j < arrArr-1; j++ {
				a[j] = a[j+1]
			}
			a[arrArr-1] = first
		}
		sinkI = a[0]
	}
}
