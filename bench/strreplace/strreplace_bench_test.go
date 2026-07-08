package strreplace

import (
	"fmt"
	"strings"
	"testing"
)

const (
	srN     = 500
	srIters = 100
)

var (
	srShortHay = func() []string {
		r := make([]string, srN)
		for i := range r {
			s := ""
			for len(s) < 50 {
				s += "ab cd ef gh "
			}
			r[i] = s
		}
		return r
	}()
	srLongHay = func() []string {
		r := make([]string, srN)
		for i := range r {
			r[i] = "the quick brown fox jumps over the lazy dog and the fox is quick again and the end"
		}
		return r
	}()
	srResult string
	srSink   int64
)

func benchReplaceNoMatch(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for iter := 0; iter < srIters; iter++ {
			for i := 0; i < srN; i++ {
				srResult = strings.Replace(srShortHay[i], "ZZZZ", "YY", -1)
				srSink += int64(len(srResult))
			}
		}
	}
}

func benchReplaceShortAll(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for iter := 0; iter < srIters; iter++ {
			for i := 0; i < srN; i++ {
				srResult = strings.Replace(srShortHay[i], "ab", "XY", -1)
				srSink += int64(len(srResult))
			}
		}
	}
}

func benchReplaceLongAll(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for iter := 0; iter < srIters; iter++ {
			for i := 0; i < srN; i++ {
				srResult = strings.Replace(srLongHay[i], "the", "THE", -1)
				srSink += int64(len(srResult))
			}
		}
	}
}

func benchReplaceCharAll(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for iter := 0; iter < srIters; iter++ {
			for i := 0; i < srN; i++ {
				srResult = strings.Replace(srShortHay[i], "a", "Z", -1)
				srSink += int64(len(srResult))
			}
		}
	}
}

func benchReplaceWord(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for iter := 0; iter < srIters; iter++ {
			for i := 0; i < srN; i++ {
				srResult = strings.Replace(srLongHay[i], "quick", "SLOW", -1)
				srSink += int64(len(srResult))
			}
		}
	}
}

func TestRun(t *testing.T) {
	_ = fmt.Sprintf("%d", srSink)
}

func BenchmarkReplaceNoMatch(b *testing.B)  { benchReplaceNoMatch(b) }
func BenchmarkReplaceShortAll(b *testing.B) { benchReplaceShortAll(b) }
func BenchmarkReplaceLongAll(b *testing.B)  { benchReplaceLongAll(b) }
func BenchmarkReplaceCharAll(b *testing.B)  { benchReplaceCharAll(b) }
func BenchmarkReplaceWord(b *testing.B)     { benchReplaceWord(b) }
