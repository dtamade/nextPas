package main

import (
	"container/list"
	"fmt"
	"sort"
	"time"
)

const N = 100000

func bench(name string, f func()) {
	for i := 0; i < 3; i++ { f() }
	iters := 10
	for {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		elapsed := time.Since(start)
		if elapsed >= 50*time.Millisecond { break }
		if elapsed < time.Millisecond { iters *= 10 } else {
			iters = int(float64(iters) * float64(50*time.Millisecond) / float64(elapsed))
		}
		if iters > 1000 { iters = 1000; break }
	}
	samples := make([]time.Duration, 3)
	for s := range samples {
		start := time.Now()
		for i := 0; i < iters; i++ { f() }
		samples[s] = time.Since(start)
	}
	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	median := samples[1]
	nsPerOp := float64(median.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-40s %8d iters %10.1f ns/op %14.0f ops/s\n", name, iters, nsPerOp, 1e9/nsPerOp)
}

var sink int64

// Go has no built-in deque. Use container/list as comparison.
// Also compare with slice-based deque (ring buffer).

type RingDeque struct {
	buf        []int32
	head, tail int
	count, cap int
}

func NewRingDeque(cap int) *RingDeque {
	if cap < 8 { cap = 8 }
	return &RingDeque{buf: make([]int32, cap), cap: cap}
}

func (d *RingDeque) PushBack(v int32) {
	if d.count == d.cap {
		newCap := d.cap * 2
		newBuf := make([]int32, newCap)
		for i := 0; i < d.count; i++ {
			newBuf[i] = d.buf[(d.head+i)%d.cap]
		}
		d.buf = newBuf
		d.head = 0
		d.tail = d.count
		d.cap = newCap
	}
	d.buf[d.tail] = v
	d.tail = (d.tail + 1) % d.cap
	d.count++
}

func (d *RingDeque) PushFront(v int32) {
	if d.count == d.cap {
		newCap := d.cap * 2
		newBuf := make([]int32, newCap)
		for i := 0; i < d.count; i++ {
			newBuf[i] = d.buf[(d.head+i)%d.cap]
		}
		d.buf = newBuf
		d.head = 0
		d.tail = d.count
		d.cap = newCap
	}
	d.head = (d.head - 1 + d.cap) % d.cap
	d.buf[d.head] = v
	d.count++
}

func (d *RingDeque) PopFront() int32 {
	v := d.buf[d.head]
	d.head = (d.head + 1) % d.cap
	d.count--
	return v
}

func (d *RingDeque) PopBack() int32 {
	d.tail = (d.tail - 1 + d.cap) % d.cap
	d.count--
	return d.buf[d.tail]
}

func (d *RingDeque) Get(i int) int32 {
	return d.buf[(d.head+i)%d.cap]
}

func main() {
	fmt.Printf("=== Go RingDeque Benchmark (N=%d) ===\n\n", N)

	bench("RingDeque.PushBack/N=100000", func() {
		d := NewRingDeque(8)
		for i := 0; i < N; i++ { d.PushBack(int32(i)) }
		sink += int64(d.count)
	})

	bench("RingDeque.PushFront/N=100000", func() {
		d := NewRingDeque(8)
		for i := 0; i < N; i++ { d.PushFront(int32(i)) }
		sink += int64(d.count)
	})

	bench("RingDeque.PopFront/N=100000", func() {
		d := NewRingDeque(N)
		for i := 0; i < N; i++ { d.PushBack(int32(i)) }
		for i := 0; i < N; i++ { sink += int64(d.PopFront()) }
	})

	bench("RingDeque.PopBack/N=100000", func() {
		d := NewRingDeque(N)
		for i := 0; i < N; i++ { d.PushBack(int32(i)) }
		for i := 0; i < N; i++ { sink += int64(d.PopBack()) }
	})

	gd := NewRingDeque(N)
	for i := 0; i < N; i++ { gd.PushBack(int32(i)) }

	bench("RingDeque.Get/N=100000", func() {
		for i := 0; i < N; i++ { sink += int64(gd.Get(i)) }
	})

	bench("RingDeque.Queue(push+pop)/N=100000", func() {
		d := NewRingDeque(1024)
		for i := 0; i < N; i++ {
			d.PushBack(int32(i))
			if d.count > 512 { sink += int64(d.PopFront()) }
		}
	})

	_ = list.New() // suppress unused import
	if sink == -999 { fmt.Println(sink) }
}
