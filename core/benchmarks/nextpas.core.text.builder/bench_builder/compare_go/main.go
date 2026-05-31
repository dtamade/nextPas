package main

import (
	"fmt"
	"strconv"
	"strings"
	"time"
)

const (
	samples  = 3
	targetNs = 50_000_000
)

func bench(name string, f func()) {
	for i := 0; i < 3; i++ { f() }
	iters := 10
	for {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		elapsed := time.Since(start).Nanoseconds()
		if elapsed >= targetNs { break }
		iters = int(float64(iters) * float64(targetNs) / float64(elapsed))
		if iters < 10 { iters = 10 }
		if iters > 10000 { iters = 10000; break }
	}
	times := make([]time.Duration, samples)
	for s := 0; s < samples; s++ {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		times[s] = time.Since(start)
	}
	for i := 0; i < samples-1; i++ {
		for j := i + 1; j < samples; j++ {
			if times[j] < times[i] { times[i], times[j] = times[j], times[i] }
		}
	}
	ns := float64(times[samples/2].Nanoseconds()) / float64(iters)
	ops := 1_000_000_000.0 / ns
	fmt.Printf("  %-35s %6d iters %12.1f ns/op %12.0f ops/s\n", name, iters, ns, ops)
}

var sink int

func main() {
	fmt.Println("=== Go strings.Builder benchmark ===")
	fmt.Println()

	bench("WriteString short (3x)", func() {
		var b strings.Builder
		b.WriteString("hello")
		b.WriteString(" ")
		b.WriteString("world")
		sink = b.Len()
	})

	bench("WriteString 100x", func() {
		var b strings.Builder
		b.Grow(1024)
		for i := 0; i < 100; i++ {
			b.WriteString("abcdefghij")
		}
		sink = b.Len()
	})

	bench("WriteByte 1000x", func() {
		var b strings.Builder
		b.Grow(1024)
		for i := 0; i < 1000; i++ {
			b.WriteByte('x')
		}
		sink = b.Len()
	})

	bench("WriteInt 100x", func() {
		var b strings.Builder
		b.Grow(512)
		for i := 1; i <= 100; i++ {
			b.WriteString(strconv.FormatInt(int64(i)*12345, 10))
		}
		sink = b.Len()
	})

	bench("Mixed (HTTP header)", func() {
		var b strings.Builder
		b.Grow(256)
		b.WriteString("HTTP/1.1 ")
		b.WriteString(strconv.Itoa(200))
		b.WriteString(" OK")
		b.WriteByte('\r')
		b.WriteByte('\n')
		b.WriteString("Content-Length: ")
		b.WriteString(strconv.Itoa(1024))
		b.WriteByte('\r')
		b.WriteByte('\n')
		b.WriteByte('\r')
		b.WriteByte('\n')
		sink = b.Len()
	})

	bench("String() (43 bytes)", func() {
		var b strings.Builder
		b.WriteString("The quick brown fox jumps over the lazy dog")
		_ = b.String()
	})

	bench("Grow from 16 to 800", func() {
		var b strings.Builder
		for i := 0; i < 50; i++ {
			b.WriteString("0123456789abcdef")
		}
		sink = b.Len()
	})

	fmt.Println()
	_ = sink
}
