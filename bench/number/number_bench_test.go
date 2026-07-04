package number

import (
	"fmt"
	"strconv"
	"testing"
)

const benchN = 1_000_000

var benchStrs []string
var benchInts []int64
var benchFloats []float64

func init() {
	benchStrs = make([]string, benchN)
	benchInts = make([]int64, benchN)
	benchFloats = make([]float64, benchN)
	for i := 0; i < benchN; i++ {
		benchInts[i] = int64(i)
		benchStrs[i] = strconv.Itoa(i)
		benchFloats[i] = float64(i) * 3.14159
	}
}

func BenchmarkIntToStr1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink string
		for i := 0; i < benchN; i++ {
			sink = strconv.FormatInt(benchInts[i], 10)
		}
		if sink == "" {
			fmt.Println()
		}
	}
}

func BenchmarkStrToInt1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink int64
		for i := 0; i < benchN; i++ {
			sink, _ = strconv.ParseInt(benchStrs[i], 10, 64)
		}
		if sink == 0 {
			fmt.Println()
		}
	}
}

func BenchmarkIntToHex1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink string
		for i := 0; i < benchN; i++ {
			sink = strconv.FormatInt(benchInts[i], 16)
		}
		if sink == "" {
			fmt.Println()
		}
	}
}

func BenchmarkUIntToStr1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink string
		for i := 0; i < benchN; i++ {
			sink = strconv.FormatUint(uint64(benchInts[i]), 10)
		}
		if sink == "" {
			fmt.Println()
		}
	}
}

func BenchmarkTryStrToInt1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink int64
		for i := 0; i < benchN; i++ {
			v, err := strconv.ParseInt(benchStrs[i], 10, 64)
			if err == nil {
				sink = v
			}
		}
		if sink == 0 {
			fmt.Println()
		}
	}
}

func BenchmarkFloatToStr1M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sink string
		for i := 0; i < benchN; i++ {
			sink = strconv.FormatFloat(benchFloats[i], 'f', -1, 64)
		}
		if sink == "" {
			fmt.Println()
		}
	}
}
