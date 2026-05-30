package main

import (
	"fmt"
	"regexp"
	"time"
)

const inputSize = 10000
const iters = 100

func main() {
	input := make([]byte, inputSize)
	for i := range input { input[i] = byte('a' + i%26) }
	copy(input[5000:], []byte("hello world 2026-05-31 cat"))
	s := string(input)

	fmt.Printf("=== Go regexp Benchmark (input=%d bytes) ===\n\n", inputSize)

	// Literal IsMatch
	re := regexp.MustCompile("hello")
	start := time.Now()
	sink := 0
	for i := 0; i < iters; i++ {
		if re.MatchString(s) { sink++ }
	}
	ns := float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Literal IsMatch:     %10.1f ns/op\n", ns)

	// Digit Find
	re = regexp.MustCompile(`\d+`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		m := re.FindStringIndex(s)
		if m != nil { sink += m[1] - m[0] }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Digit Find:          %10.1f ns/op\n", ns)

	// Alternation
	re = regexp.MustCompile("cat|dog|bird|fish")
	start = time.Now()
	for i := 0; i < iters; i++ {
		if re.MatchString(s) { sink++ }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Alternation (4 alts):%10.1f ns/op\n", ns)

	// Compile
	start = time.Now()
	for i := 0; i < 1000; i++ {
		regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
	}
	ns = float64(time.Since(start).Nanoseconds()) / 1000.0
	fmt.Printf("  Compile (date):      %10.1f ns/op\n", ns)

	_ = sink
}
