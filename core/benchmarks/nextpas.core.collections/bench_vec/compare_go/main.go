package main

import (
	"fmt"
	"sort"
	"time"
)

const N = 100000

func bench(name string, f func()) {
	// warmup
	for i := 0; i < 3; i++ {
		f()
	}
	// calibrate
	iters := 100
	for {
		start := time.Now()
		for i := 0; i < iters; i++ {
			f()
		}
		elapsed := time.Since(start)
		if elapsed >= 100*time.Millisecond {
			break
		}
		if elapsed < time.Millisecond {
			iters *= 10
		} else {
			iters = int(float64(iters) * float64(100*time.Millisecond) / float64(elapsed))
		}
		if iters > 10000 {
			iters = 10000
			break
		}
	}
	// measure
	samples := make([]time.Duration, 5)
	for s := range samples {
		start := time.Now()
		for i := 0; i < iters; i++ {
			f()
		}
		samples[s] = time.Since(start)
	}
	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	median := samples[2]
	nsPerOp := float64(median.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-40s %12d iters %10.1f ns/op %14.0f ops/s\n", name, iters, nsPerOp, 1e9/nsPerOp)
}

var sink int64

func main() {
	fmt.Printf("=== Go slice Benchmark (N=%d) ===\n\n", N)

	bench("slice.append/N=100000", func() {
		s := make([]int32, 0, 8)
		for i := 0; i < N; i++ {
			s = append(s, int32(i))
		}
		sink += int64(len(s))
	})

	bench("slice.append+prealloc/N=100000", func() {
		s := make([]int32, 0, N)
		for i := 0; i < N; i++ {
			s = append(s, int32(i))
		}
		sink += int64(len(s))
	})

	bench("slice.pop/N=100000", func() {
		s := make([]int32, N)
		for i := 0; i < N; i++ {
			s = s[:len(s)-1]
		}
		sink += int64(len(s))
	})

	data := make([]int32, N)
	for i := range data {
		data[i] = int32(i)
	}

	bench("slice[i] get/N=100000", func() {
		var sum int64
		for i := 0; i < N; i++ {
			sum += int64(data[i])
		}
		sink += sum
	})

	bench("slice insert(mid)/N=1000", func() {
		s := make([]int32, 0, 2000)
		for i := 0; i < 1000; i++ {
			mid := len(s) / 2
			s = append(s, 0)
			copy(s[mid+1:], s[mid:])
			s[mid] = int32(i)
		}
		sink += int64(len(s))
	})

	bench("slice delete(mid)/N=1000", func() {
		s := make([]int32, 1000)
		for i := 0; i < 1000; i++ {
			mid := len(s) / 2
			copy(s[mid:], s[mid+1:])
			s = s[:len(s)-1]
		}
		sink += int64(len(s))
	})

	bench("slice contains/100 lookups", func() {
		for i := 0; i < 100; i++ {
			target := int32(N - 1 - i)
			for j := 0; j < N; j++ {
				if data[j] == target {
					sink++
					break
				}
			}
		}
	})

	bench("slice iterate/N=100000", func() {
		var sum int64
		for _, v := range data {
			sum += int64(v)
		}
		sink += sum
	})

	if sink == -999 {
		fmt.Println(sink)
	}
}
