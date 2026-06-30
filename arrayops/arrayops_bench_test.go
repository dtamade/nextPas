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
	sinkF float64
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

func BenchmarkArraySum(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var a [arrArr]int64
		for i := 0; i < arrArr; i++ {
			a[i] = int64(i)
		}
		for i := 0; i < arrN; i++ {
			s := int64(0)
			for j := 0; j < arrArr; j++ {
				s += a[j]
			}
			sinkI = int(s)
		}
	}
}

func BenchmarkLinearSearch(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var a [arrArr]int
		for i := 0; i < arrArr; i++ {
			a[i] = i*3 + 7
		}
		for i := 0; i < arrN; i++ {
			found := -1
			for j := 0; j < arrArr; j++ {
				if a[j] == 29998 {
					found = j
					break
				}
			}
			sinkI = found
		}
	}
}

func BenchmarkCountEven(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var a [arrArr]int
		for i := 0; i < arrArr; i++ {
			a[i] = i
		}
		for i := 0; i < arrN; i++ {
			count := 0
			for j := 0; j < arrArr; j++ {
				if a[j]&1 == 0 {
					count++
				}
			}
			sinkI = count
		}
	}
}

func BenchmarkFloatArraySum(b *testing.B) {
	var a [arrArr]float64
	for i := 0; i < arrArr; i++ {
		a[i] = float64(i) * 0.5
	}
	for n := 0; n < b.N; n++ {
		for i := 0; i < arrN; i++ {
			s := float64(0)
			for j := 0; j < arrArr; j++ {
				s += a[j]
			}
			sinkF = s
		}
	}
}

func BenchmarkFloatArrayDot(b *testing.B) {
	var a, b2 [arrArr]float64
	for i := 0; i < arrArr; i++ {
		a[i] = float64(i) * 0.5
		b2[i] = float64(i) * 0.3
	}
	for n := 0; n < b.N; n++ {
		for i := 0; i < arrN; i++ {
			s := float64(0)
			for j := 0; j < arrArr; j++ {
				s += a[j] * b2[j]
			}
			sinkF = s
		}
	}
}
