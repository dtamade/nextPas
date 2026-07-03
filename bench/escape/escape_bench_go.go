package main

import (
	"fmt"
	"strings"
	"time"
)

const N = 10000

var samples = [10]string{
	"Hello World",
	"line1\nline2\nline3",
	`C:\Users\test\file.txt`,
	`<script>alert("xss")</script>`,
	"a=b&c=d&e=f",
	"no escaping needed here",
	"\x01\x02\x03\x00text after null",
	"tabs\tand\tmore\ttabs",
	`quote "inside" and 'single'`,
	`mix: <>&"'=end`,
}

var data [N]string

func initData() {
	for i := 0; i < N; i++ {
		data[i] = samples[i%10]
	}
}

// CountBranch — count chars needing escape (branch-based)
func benchCountBranch() int {
	count := 0
	for i := 0; i < N; i++ {
		s := data[i]
		for _, c := range s {
			if c == '"' || c == '\\' || c < 32 || c == 127 {
				count++
			}
		}
	}
	return count
}

// Escape using strings.Builder with pre-scan
func benchEscapeBuilder() int {
	total := 0
	for i := 0; i < N; i++ {
		s := data[i]
		extra := 0
		for _, c := range s {
			if c == '"' || c == '\\' || c < 32 || c == 127 {
				if c == '\n' || c == '\r' || c == '\t' || c == '"' || c == '\\' {
					extra++
				} else {
					extra += 3
				}
			}
		}
		var b strings.Builder
		b.Grow(len(s) + extra)
		for _, c := range s {
			if c == '"' || c == '\\' || c < 32 || c == 127 {
				b.WriteByte('\\')
				switch c {
				case '"':
					b.WriteByte('"')
				case '\\':
					b.WriteByte('\\')
				case '\n':
					b.WriteByte('n')
				case '\r':
					b.WriteByte('r')
				case '\t':
					b.WriteByte('t')
				default:
					b.WriteString("x0")
					b.WriteByte("0123456789abcdef"[c>>4])
				}
			} else {
				b.WriteByte(byte(c))
			}
		}
		total += b.Len()
	}
	return total
}

// Escape using bytes.Buffer (pre-allocated)
func benchEscapeBuffer() int {
	total := 0
	for i := 0; i < N; i++ {
		s := data[i]
		buf := make([]byte, 0, len(s)+len(s)/4+16)
		for _, c := range s {
			if c == '"' || c == '\\' || c < 32 || c == 127 {
				buf = append(buf, '\\')
				switch c {
				case '"':
					buf = append(buf, '"')
				case '\\':
					buf = append(buf, '\\')
				case '\n':
					buf = append(buf, 'n')
				case '\r':
					buf = append(buf, 'r')
				case '\t':
					buf = append(buf, 't')
				default:
					buf = append(buf, 'x', '0', "0123456789abcdef"[c>>4])
				}
			} else {
				buf = append(buf, byte(c))
			}
		}
		total += len(buf)
	}
	return total
}

// StringReplace equivalent
func benchStringReplace() int {
	total := 0
	for i := 0; i < N; i++ {
		s := data[i]
		s = strings.ReplaceAll(s, `\`, `\\`)
		s = strings.ReplaceAll(s, `"`, `\"`)
		s = strings.ReplaceAll(s, "\n", `\n`)
		s = strings.ReplaceAll(s, "\r", `\r`)
		s = strings.ReplaceAll(s, "\t", `\t`)
		total += len(s)
	}
	return total
}

func benchmark(name string, fn func() int, bytesPerOp int) {
	warmup := 3
	for w := 0; w < warmup; w++ {
		fn()
	}

	var best time.Duration
	var bestN int
	for attempt := 0; attempt < 10; attempt++ {
		start := time.Now()
		iters := 0
		d := time.Duration(0)
		for d < 200*time.Millisecond {
			fn()
			iters++
			d = time.Since(start)
		}
		nsPerOp := d / time.Duration(iters)
		if best == 0 || nsPerOp < best {
			best = nsPerOp
			bestN = iters
		}
	}
	fmt.Printf("%40s  %6d iters  %10.1f ns/op  %10.0f ops/s\n",
		name, bestN, float64(best.Nanoseconds()), 1e9/float64(best.Nanoseconds()))
}

func main() {
	initData()
	benchmark("Escape/CountBranch/10K", benchCountBranch, 40)
	benchmark("Escape/Builder/10K", benchEscapeBuilder, 40)
	benchmark("Escape/Buffer/10K", benchEscapeBuffer, 40)
	benchmark("Escape/StringReplace/10K", benchStringReplace, 40)
}
