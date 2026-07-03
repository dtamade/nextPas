package bytewise

import "testing"

const (
	n   = 100_000
	sz  = 4096
	textLen  = 1024 * 100
	numIters = 1000
)

var (
	ga, gb, gc [sz]byte
	textBuf    [textLen]byte
	sink       int
)

func init() {
	for i := 0; i < sz; i++ {
		ga[i] = byte(i*7 + 13)
		gb[i] = byte(i*3 + 29)
	}
	for j := 0; j < textLen; j++ {
		if j%6 == 0 {
			textBuf[j] = ' '
		} else if j%50 == 0 {
			textBuf[j] = '\n'
		} else {
			textBuf[j] = byte('A' + j%26)
		}
	}
}

func BenchmarkMemZero(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < n; j++ {
			clear(gc[:])
		}
	}
	sink = int(gc[0])
}

func BenchmarkBufferXor(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < n; j++ {
			for k := 0; k < sz; k++ {
				gc[k] = ga[k] ^ gb[k]
			}
		}
	}
	sink = int(gc[0])
}

func BenchmarkWordCount(b *testing.B) {
	for i := 0; i < b.N; i++ {
		count := 0
		for j := 0; j < numIters; j++ {
			for k := 0; k < textLen; k++ {
				if textBuf[k] == ' ' {
					count++
				}
			}
		}
		sink = count
	}
}

func BenchmarkBufferAnd(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < n; j++ {
			for k := 0; k < sz; k++ {
				gc[k] = ga[k] & gb[k]
			}
		}
		sink = int(gc[0])
	}
}

func BenchmarkBufferNot(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < n; j++ {
			for k := 0; k < sz; k++ {
				gc[k] = ^ga[k]
			}
		}
		sink = int(gc[0])
	}
}
