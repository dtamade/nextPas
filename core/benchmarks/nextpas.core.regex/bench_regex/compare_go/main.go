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
	copy(input[2000:], []byte("item 42 cost 199 qty 7"))
	copy(input[8000:], []byte("id 12345 ref 9876"))
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
	fmt.Printf("  Literal IsMatch:       %10.1f ns/op\n", ns)

	// Digit Find
	re = regexp.MustCompile(`\d+`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		m := re.FindStringIndex(s)
		if m != nil { sink += m[1] - m[0] }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Digit Find:            %10.1f ns/op\n", ns)

	// Alternation
	re = regexp.MustCompile("cat|dog|bird|fish")
	start = time.Now()
	for i := 0; i < iters; i++ {
		if re.MatchString(s) { sink++ }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Alternation (4 alts):  %10.1f ns/op\n", ns)

	// Compile
	start = time.Now()
	for i := 0; i < 1000; i++ {
		regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
	}
	ns = float64(time.Since(start).Nanoseconds()) / 1000.0
	fmt.Printf("  Compile (date):        %10.1f ns/op\n", ns)

	// IsFullMatch (^pattern$)
	re = regexp.MustCompile(`^[a-z]+$`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		if re.MatchString(s) { sink++ }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  IsFullMatch (^[a-z]+$):%10.1f ns/op\n", ns)

	// Case-insensitive
	re = regexp.MustCompile(`(?i)hello`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		if re.MatchString(s) { sink++ }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Case-Insensitive (?i): %10.1f ns/op\n", ns)

	// Capture groups
	re = regexp.MustCompile(`(\d{4})-(\d{2})-(\d{2})`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		m := re.FindStringSubmatchIndex(s)
		if m != nil { sink += len(m) }
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  Capture Groups (date): %10.1f ns/op\n", ns)

	// FindAll
	re = regexp.MustCompile(`\w+`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		matches := re.FindAllStringIndex(s, -1)
		sink += len(matches)
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  FindAll (\\w+):         %10.1f ns/op\n", ns)

	// ReplaceAll
	re = regexp.MustCompile(`\d+`)
	start = time.Now()
	for i := 0; i < iters; i++ {
		result := re.ReplaceAllString(s, "NUM")
		sink += len(result)
	}
	ns = float64(time.Since(start).Nanoseconds()) / float64(iters)
	fmt.Printf("  ReplaceAll (\\d+->NUM): %10.1f ns/op\n", ns)

	_ = sink
}
