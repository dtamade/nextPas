package copy

import (
	"bytes"
	"fmt"
	"testing"
)

const copyN = 10000

var (
	copySrc [65536]byte
	copyDst [65536]byte
)

func init() {
	for i := range copySrc {
		copySrc[i] = byte(i & 255)
	}
}

func BenchmarkFill_64B(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			for k := 0; k < 64; k++ {
				copyDst[k] = byte(j)
			}
		}
	}
}

func BenchmarkFill_1KB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			for k := 0; k < 1024; k++ {
				copyDst[k] = byte(j)
			}
		}
	}
}

func BenchmarkFill_64KB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			for k := 0; k < 65536; k++ {
				copyDst[k] = byte(j)
			}
		}
	}
}

func BenchmarkMove_64B(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			copy(copyDst[:64], copySrc[:64])
		}
	}
}

func BenchmarkMove_1KB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			copy(copyDst[:1024], copySrc[:1024])
		}
	}
}

func BenchmarkMove_64KB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			copy(copyDst[:65536], copySrc[:65536])
		}
	}
}

func BenchmarkCompare_Eq1K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			_ = bytes.Equal(copySrc[:1024], copyDst[:1024])
		}
	}
}

func BenchmarkCompare_Diff1K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			copyDst[1023] = byte(j)
			_ = bytes.Equal(copySrc[:1024], copyDst[:1024])
		}
	}
}

func BenchmarkReverse_1KB(b *testing.B) {
	for i := 0; i < b.N; i++ {
		for j := 0; j < copyN; j++ {
			copy(copyDst[:1024], copySrc[:1024])
			for k := 0; k < 512; k++ {
				copyDst[k], copyDst[1023-k] = copyDst[1023-k], copyDst[k]
			}
		}
	}
}

// Run with: go test -bench=. -benchtime=1x
func TestShowInfo(t *testing.T) {
	fmt.Println("copy benchmark: Fill/Move/Compare/Reverse")
}
