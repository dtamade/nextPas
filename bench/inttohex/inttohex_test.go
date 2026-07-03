package inttohex

import (
	"fmt"
	"strconv"
	"testing"
)

const hexN = 500

var gResult string

func BenchmarkSprintfHex64(b *testing.B) {
	for i := 0; i < b.N; i++ {
		s := ""
		for j := 1; j <= hexN; j++ {
			s = fmt.Sprintf("%016x", int64(j)*123456789)
		}
		gResult = s
	}
}

func BenchmarkSprintfHex32(b *testing.B) {
	for i := 0; i < b.N; i++ {
		s := ""
		for j := 1; j <= hexN; j++ {
			s = fmt.Sprintf("%08x", j)
		}
		gResult = s
	}
}

func BenchmarkStrconvHex64(b *testing.B) {
	for i := 0; i < b.N; i++ {
		s := ""
		for j := 1; j <= hexN; j++ {
			s = strconv.FormatInt(int64(j)*123456789, 16)
		}
		gResult = s
	}
}

func BenchmarkStrconvHex32(b *testing.B) {
	for i := 0; i < b.N; i++ {
		s := ""
		for j := 1; j <= hexN; j++ {
			s = strconv.FormatInt(int64(j), 16)
		}
		gResult = s
	}
}
