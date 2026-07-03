package main

import (
	"fmt"
	"time"
)

const N = 100000

var (
	charToDigit [256]int8
	toUpper     [256]byte
	gText       string
	gResult     [N]byte
	gSink       int
)

func init() {
	for i := 0; i < 256; i++ {
		charToDigit[i] = -1
		toUpper[i] = byte(i)
	}
	for c := byte('0'); c <= '9'; c++ {
		charToDigit[c] = int8(c - '0')
	}
	for c := byte('A'); c <= 'F'; c++ {
		charToDigit[c] = int8(c-'A') + 10
	}
	for c := byte('a'); c <= 'f'; c++ {
		charToDigit[c] = int8(c-'a') + 10
	}
	for c := byte('a'); c <= 'z'; c++ {
		toUpper[c] = c - 32
	}

	buf := make([]byte, N)
	for i := 0; i < N; i++ {
		buf[i] = byte(32 + (i % 95))
	}
	gText = string(buf)
}

func benchHexLookup(iters int) time.Duration {
	var sum int
	start := time.Now()
	for n := 0; n < iters; n++ {
		sum = 0
		for i := 0; i < len(gText); i++ {
			v := charToDigit[gText[i]]
			if v >= 0 {
				sum += int(v)
			}
		}
	}
	gSink = sum
	return time.Since(start)
}

func benchToUpperTable(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < len(gText); i++ {
			gResult[i] = toUpper[gText[i]]
		}
	}
	gSink = int(gResult[0])
	return time.Since(start)
}

func benchToUpperBranch(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < len(gText); i++ {
			ch := gText[i]
			if ch >= 'a' && ch <= 'z' {
				ch -= 32
			}
			gResult[i] = ch
		}
	}
	gSink = int(gResult[0])
	return time.Since(start)
}

func runBench(name string, fn func(int) time.Duration) {
	fn(10)
	iters := 10
	d := fn(iters)
	for d < 200*time.Millisecond {
		iters *= 2
		d = fn(iters)
	}
	fmt.Printf("%-20s %6d iters  %10.1f ns/op\n", name, iters, float64(d)/float64(iters))
}

func main() {
	runBench("HexLookup/100K", benchHexLookup)
	runBench("ToUpper/Table/100K", benchToUpperTable)
	runBench("ToUpper/Branch/100K", benchToUpperBranch)
}
