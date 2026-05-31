package main

import (
	"fmt"
	"strconv"
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

var sink string
var sinkInt int64
var sinkFloat float64

func main() {
	fmt.Println("=== Go strconv benchmark ===")
	fmt.Println()

	buf := make([]byte, 0, 64)

	bench("FormatInt(42)", func() {
		buf = strconv.AppendInt(buf[:0], 42, 10)
	})
	bench("FormatInt(1234567890)", func() {
		buf = strconv.AppendInt(buf[:0], 1234567890, 10)
	})
	bench("FormatInt(MaxInt64)", func() {
		buf = strconv.AppendInt(buf[:0], 9223372036854775807, 10)
	})
	bench("FormatInt(-1234567890)", func() {
		buf = strconv.AppendInt(buf[:0], -1234567890, 10)
	})
	bench("FormatUint(MaxUint64)", func() {
		buf = strconv.AppendUint(buf[:0], 18446744073709551615, 10)
	})
	bench("ParseInt(\"42\")", func() {
		sinkInt, _ = strconv.ParseInt("42", 10, 64)
	})
	bench("ParseInt(\"1234567890\")", func() {
		sinkInt, _ = strconv.ParseInt("1234567890", 10, 64)
	})
	bench("ParseInt(MaxInt64)", func() {
		sinkInt, _ = strconv.ParseInt("9223372036854775807", 10, 64)
	})
	bench("FormatFloat(pi)", func() {
		buf = strconv.AppendFloat(buf[:0], 3.141592653589793, 'g', -1, 64)
	})
	bench("ParseFloat(\"3.14...\")", func() {
		sinkFloat, _ = strconv.ParseFloat("3.141592653589793", 64)
	})
	bench("FormatUint(hex)", func() {
		buf = strconv.AppendUint(buf[:0], 0xDEADBEEFCAFE, 16)
	})

	fmt.Println()
	_ = sink
	_ = sinkInt
	_ = sinkFloat
}
