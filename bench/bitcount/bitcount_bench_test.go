package bitcount

import (
	"fmt"
	"math/bits"
	"testing"
)

const bitcountN = 100000

var bitcountData [bitcountN]uint64
var bitcountSink uint64

func init() {
	for i := 0; i < bitcountN; i++ {
		bitcountData[i] = uint64(i)*6364136223846793005 + 1442695040888963407
	}
}

func BenchmarkPopCnt100K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sum uint64
		for i := 0; i < bitcountN; i++ {
			sum += uint64(bits.OnesCount64(bitcountData[i]))
		}
		bitcountSink = sum
	}
}

func BenchmarkPopCntAccum200K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sum uint64
		for i := 0; i < bitcountN; i++ {
			v := bitcountData[i]
			sum += uint64(bits.OnesCount64(v))
			v ^= 0xFFFFFFFFFFFFFFFF
			sum += uint64(bits.OnesCount64(v))
		}
		bitcountSink = sum
	}
}

func BenchmarkBitReverse100K(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sum uint64
		for i := 0; i < bitcountN; i++ {
			sum += bits.Reverse64(bitcountData[i])
		}
		bitcountSink = sum
	}
}

func TestBenchPrint(t *testing.T) {
	fmt.Println("Bitcount benchmarks compiled successfully")
}
