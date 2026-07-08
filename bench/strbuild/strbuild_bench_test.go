package strbuild

import (
	"fmt"
	"strconv"
	"strings"
	"testing"
)

const sbN = 100000

var sbParts []string

func init() {
	sbParts = make([]string, sbN)
	for i := 0; i < sbN; i++ {
		sbParts[i] = "item_" + strconv.Itoa(i)
	}
}

func BenchmarkBuilderAppend100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sb strings.Builder
		sb.Grow(sbN * 16)
		for i := 0; i < sbN; i++ {
			sb.WriteString(sbParts[i])
			sb.WriteByte(',')
		}
		_ = sb.Len()
	}
}

func BenchmarkBuilderIntAppend100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sb strings.Builder
		sb.Grow(sbN * 16)
		for i := 0; i < sbN; i++ {
			sb.WriteString(strconv.Itoa(i))
			sb.WriteByte(',')
		}
		_ = sb.Len()
	}
}

func BenchmarkConcat100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < sbN; i++ {
			s += sbParts[i] + ","
		}
		if s == "" {
			fmt.Println()
		}
	}
}

func BenchmarkBuilderLarge100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sb strings.Builder
		sb.Grow(sbN * 32)
		for i := 0; i < sbN; i++ {
			sb.WriteString("line_")
			sb.WriteString(strconv.Itoa(i))
			sb.WriteString(": value=")
			sb.WriteString(strconv.FormatFloat(float64(i)*3.14, 'f', -1, 64))
			sb.WriteByte('\n')
		}
		_ = sb.Len()
	}
}
