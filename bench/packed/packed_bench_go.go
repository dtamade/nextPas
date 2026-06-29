package main

import (
	"fmt"
	"time"
	"unsafe"
)

const N = 100000

type Particle struct {
	X, Y, Z    float32
	Vx, Vy, Vz float32
	Mass       float32
	Charge     byte
	Active     bool
}

var (
	gSrc [N]Particle
	gDst [N]Particle
	gSum float32
)

func init() {
	for i := 0; i < N; i++ {
		gSrc[i] = Particle{
			X: float32(i) * 1.5, Y: float32(i) * 2.5, Z: float32(i) * 3.5,
			Vx: float32(i) * 0.1, Vy: float32(i) * 0.2, Vz: float32(i) * 0.3,
			Mass: float32(i) * 0.01, Charge: byte(i % 3), Active: (i%7) != 0,
		}
	}
}

func benchPackedCopy(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < N; i++ {
			gDst[i] = gSrc[i]
		}
	}
	return time.Since(start)
}

func benchPackedMove(iters int) time.Duration {
	start := time.Now()
	for n := 0; n < iters; n++ {
		copy(gDst[:], gSrc[:])
	}
	return time.Since(start)
}

func benchPackedUpdate(iters int) time.Duration {
	var lx float32
	start := time.Now()
	for n := 0; n < iters; n++ {
		for i := 0; i < N; i++ {
			gSrc[i].X += gSrc[i].Vx
			gSrc[i].Y += gSrc[i].Vy
			gSrc[i].Z += gSrc[i].Vz
			lx = gSrc[i].X
		}
	}
	gSum = lx
	return time.Since(start)
}

func benchPackedFilter(iters int) time.Duration {
	var count int
	start := time.Now()
	for n := 0; n < iters; n++ {
		count = 0
		for i := 0; i < N; i++ {
			if gSrc[i].Active && gSrc[i].Mass > 0.5 {
				count++
			}
		}
	}
	gSum = float32(count)
	return time.Since(start)
}

func benchPackedCompact(iters int) time.Duration {
	var count int
	start := time.Now()
	for n := 0; n < iters; n++ {
		count = 0
		for i := 0; i < N; i++ {
			if gSrc[i].Active {
				gDst[count] = gSrc[i]
				count++
			}
		}
	}
	gSum = float32(count)
	return time.Since(start)
}

func runBench(name string, fn func(int) time.Duration) {
	fn(100)
	iters := 100
	d := fn(iters)
	for d < 200*time.Millisecond {
		iters *= 2
		d = fn(iters)
	}
	fmt.Printf("%-20s %6d iters  %10.1f ns/op\n", name, iters, float64(d)/float64(iters))
}

func main() {
	fmt.Printf("Go Particle size: %d bytes\n", unsafe.Sizeof(Particle{}))
	runBench("PackedCopy/100K", benchPackedCopy)
	runBench("PackedMove/100K", benchPackedMove)
	runBench("PackedUpdate/100K", benchPackedUpdate)
	runBench("PackedFilter/100K", benchPackedFilter)
	runBench("PackedCompact/100K", benchPackedCompact)
}
