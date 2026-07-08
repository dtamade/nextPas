package format

import (
	"fmt"
	"strconv"
	"testing"
)

const fmtN = 100000

var fmtNames []string
var fmtValues []int
var fmtFloats []float64

func init() {
	fmtNames = make([]string, fmtN)
	fmtValues = make([]int, fmtN)
	fmtFloats = make([]float64, fmtN)
	for i := 0; i < fmtN; i++ {
		fmtNames[i] = "item_" + strconv.Itoa(i)
		fmtValues[i] = i
		fmtFloats[i] = float64(i) * 3.14159
	}
}

func BenchmarkFormatInt100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < fmtN; i++ {
			s = "Value: " + strconv.Itoa(fmtValues[i])
		}
		_ = s
	}
}

func BenchmarkFormatStr100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < fmtN; i++ {
			s = "Name: " + fmtNames[i]
		}
		_ = s
	}
}

func BenchmarkFormatMulti100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < fmtN; i++ {
			s = fmtNames[i] + "=" + strconv.Itoa(fmtValues[i]) + " (" + strconv.FormatFloat(fmtFloats[i], 'f', -1, 64) + ")"
		}
		_ = s
	}
}

func BenchmarkFormatHex100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < fmtN; i++ {
			s = fmt.Sprintf("%.8X", fmtValues[i])
		}
		_ = s
	}
}
