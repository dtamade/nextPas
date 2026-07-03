package main

import (
	"fmt"
	"strconv"
	"time"
)

const N = 100000

var data [N]string
var results [N]int

func initData() {
	for i := 0; i < N; i++ {
		data[i] = strconv.Itoa(i * 37 % 10000000)
	}
}

// Go: strconv.Atoi
func benchAtoi() {
	for i := 0; i < N; i++ {
		v, _ := strconv.Atoi(data[i])
		results[i] = v
	}
}

// Go: manual parse
func parseUint32(s string) uint32 {
	var r uint32
	for i := 0; i < len(s); i++ {
		c := uint32(s[i]) - uint32('0')
		if c > 9 {
			break
		}
		r = r*10 + c
	}
	return r
}

func benchManualParse() {
	for i := 0; i < N; i++ {
		results[i] = int(parseUint32(data[i]))
	}
}

// Go: manual parse without break (no error check)
func parseUint32Strict(s string) uint32 {
	var r uint32
	for i := 0; i < len(s); i++ {
		r = r*10 + uint32(s[i]-'0')
	}
	return r
}

func benchStrictParse() {
	for i := 0; i < N; i++ {
		results[i] = int(parseUint32Strict(data[i]))
	}
}

// Go: block parse (4 chars at a time)
func parseUint32Block(s string) uint32 {
	var r uint32
	j := 0
	n := len(s)
	for j+3 < n {
		r = r*10000 +
			uint32(s[j]-'0')*1000 +
			uint32(s[j+1]-'0')*100 +
			uint32(s[j+2]-'0')*10 +
			uint32(s[j+3]-'0')
		j += 4
	}
	for j < n {
		r = r*10 + uint32(s[j]-'0')
		j++
	}
	return r
}

func benchBlockParse() {
	for i := 0; i < N; i++ {
		results[i] = int(parseUint32Block(data[i]))
	}
}

// Go: FormatInt
func benchItoa() {
	for i := 0; i < N; i++ {
		_ = strconv.Itoa(results[i])
	}
}

func benchmark(name string, fn func()) {
	for w := 0; w < 3; w++ {
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
	benchmark("StrConv/Atoi/100K", benchAtoi)
	benchmark("StrConv/ManualParse/100K", benchManualParse)
	benchmark("StrConv/StrictParse/100K", benchStrictParse)
	benchmark("StrConv/BlockParse/100K", benchBlockParse)
	benchmark("StrConv/Itoa/100K", benchItoa)
}
