package main

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"
)

const (
	samples  = 3
	targetNs = 50_000_000
	maxIters = 200000
)

var sinkInt int
var sinkBool bool
var sinkBytes []byte
var sinkString string

func bench(name string, f func()) {
	for i := 0; i < 3; i++ {
		f()
	}

	iters := 100
	for {
		start := time.Now()
		for i := 0; i < iters; i++ {
			f()
		}
		elapsed := time.Since(start).Nanoseconds()
		if elapsed >= targetNs || iters >= maxIters {
			break
		}
		if elapsed <= 0 {
			iters *= 10
		} else {
			iters = int(float64(iters) * float64(targetNs) / float64(elapsed))
		}
		if iters < 100 {
			iters = 100
		}
		if iters > maxIters {
			iters = maxIters
		}
	}

	times := make([]time.Duration, samples)
	for s := 0; s < samples; s++ {
		start := time.Now()
		for i := 0; i < iters; i++ {
			f()
		}
		times[s] = time.Since(start)
	}
	for i := 0; i < samples-1; i++ {
		for j := i + 1; j < samples; j++ {
			if times[j] < times[i] {
				times[i], times[j] = times[j], times[i]
			}
		}
	}
	ns := float64(times[samples/2].Nanoseconds()) / float64(iters)
	ops := 1_000_000_000.0 / ns
	fmt.Printf("  %-40s %8d iters %12.1f ns/op %12.0f ops/s\n", name, iters, ns, ops)
}

func main() {
	jsonValidASCII := []byte(`{"name":"plain text","value":123,"flag":true}`)
	jsonValidUnicode := []byte(`{"name":"中文😀","value":"heart❤️","items":[1,2,3]}`)
	jsonEscapeASCII := "plain text segment-plain text segment-plain text segment"
	jsonEscapeUnicode := "hello 中文 😀 ❤️"
	jsonUnmarshalASCII := []byte(`{"line":"plain","items":[1,2,3],"ok":true}`)
	jsonUnmarshalUnicode := []byte(`{"line":"中文😀","items":["❤️","测试"],"ok":true}`)

	fmt.Println("=== Go benchmark reference: encoding/json + strings.Builder ===")
	fmt.Println()

	fmt.Println("--- json.Valid ---")
	bench("json.Valid ASCII", func() {
		sinkBool = json.Valid(jsonValidASCII)
	})
	bench("json.Valid Unicode", func() {
		sinkBool = json.Valid(jsonValidUnicode)
	})
	fmt.Println()

	fmt.Println("--- json.Marshal (string escaping) ---")
	bench("json.Marshal ASCII string", func() {
		sinkBytes, _ = json.Marshal(jsonEscapeASCII)
	})
	bench("json.Marshal Unicode string", func() {
		sinkBytes, _ = json.Marshal(jsonEscapeUnicode)
	})
	fmt.Println()

	fmt.Println("--- json.Unmarshal ---")
	bench("json.Unmarshal ASCII", func() {
		var v map[string]any
		_ = json.Unmarshal(jsonUnmarshalASCII, &v)
		sinkInt = len(v)
	})
	bench("json.Unmarshal Unicode", func() {
		var v map[string]any
		_ = json.Unmarshal(jsonUnmarshalUnicode, &v)
		sinkInt = len(v)
	})
	fmt.Println()

	fmt.Println("--- strings.Builder.WriteString ---")
	bench("Builder.WriteString short", func() {
		var b strings.Builder
		b.Grow(64)
		b.WriteString("hello")
		b.WriteString(" ")
		b.WriteString("world")
		sinkInt = b.Len()
	})
	bench("Builder.WriteString 10000x", func() {
		var b strings.Builder
		b.Grow(16384)
		for i := 0; i < 10000; i++ {
			b.WriteString("x")
		}
		sinkString = b.String()
	})
	fmt.Println()

	_, _, _, _ = sinkInt, sinkBool, sinkBytes, sinkString
}
