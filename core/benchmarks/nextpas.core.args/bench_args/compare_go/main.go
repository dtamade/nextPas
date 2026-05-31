package main

import (
	"flag"
	"fmt"
	"os"
	"time"
)

const (
	samples  = 3
	targetNs = 50_000_000
)

func bench(name string, f func()) {
	for i := 0; i < 3; i++ {
		f()
	}
	iters := 10
	for {
		start := time.Now()
		for i := 0; i < iters; i++ {
			f()
		}
		elapsed := time.Since(start).Nanoseconds()
		if elapsed >= targetNs {
			break
		}
		iters = int(float64(iters) * float64(targetNs) / float64(elapsed))
		if iters < 10 {
			iters = 10
		}
		if iters > 1000 {
			iters = 1000
			break
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
	// take median
	for i := 0; i < samples-1; i++ {
		for j := i + 1; j < samples; j++ {
			if times[j] < times[i] {
				times[i], times[j] = times[j], times[i]
			}
		}
	}
	ns := float64(times[samples/2].Nanoseconds()) / float64(iters)
	ops := 1_000_000_000.0 / ns
	fmt.Printf("  %-40s %6d iters %12.1f ns/op %12.0f ops/s\n", name, iters, ns, ops)
}

func main() {
	fmt.Println("=== Go flag benchmark ===")
	fmt.Println()

	bench("ParseEmpty", func() {
		fs := flag.NewFlagSet("test", flag.ContinueOnError)
		fs.SetOutput(os.NewFile(0, os.DevNull))
		fs.Parse([]string{})
	})

	bench("ParseFlags(5)", func() {
		fs := flag.NewFlagSet("test", flag.ContinueOnError)
		fs.SetOutput(os.NewFile(0, os.DevNull))
		fs.Bool("verbose", false, "")
		fs.Bool("debug", false, "")
		fs.Bool("force", false, "")
		fs.Bool("quiet", false, "")
		fs.Bool("recursive", false, "")
		fs.Parse([]string{"-verbose", "-debug", "-force", "-quiet", "-recursive"})
	})

	bench("ParseMixed(compiler-like)", func() {
		fs := flag.NewFlagSet("nextpas", flag.ContinueOnError)
		fs.SetOutput(os.NewFile(0, os.DevNull))
		fs.Bool("verbose", false, "")
		fs.String("output", "a.out", "")
		fs.Int("opt-level", 2, "")
		fs.String("target", "x86_64", "")
		fs.Parse([]string{"-verbose", "-output", "main", "-opt-level", "3", "-target", "aarch64", "input.pas"})
	})

	bench("ParseStringList(10x-I)", func() {
		fs := flag.NewFlagSet("test", flag.ContinueOnError)
		fs.SetOutput(os.NewFile(0, os.DevNull))
		var includes []string
		fs.Func("I", "", func(s string) error { includes = append(includes, s); return nil })
		fs.Parse([]string{"-I", "/a", "-I", "/b", "-I", "/c", "-I", "/d", "-I", "/e",
			"-I", "/f", "-I", "/g", "-I", "/h", "-I", "/i", "-I", "/j"})
	})

	fmt.Println()
}
