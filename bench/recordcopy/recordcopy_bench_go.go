package main

import (
	"fmt"
	"time"
)

const N = 100000

type Vec3 struct{ X, Y, Z float32 }

type Transform struct {
	M [16]float32
}

type Particle struct {
	Pos   Vec3
	Vel   Vec3
	Accel Vec3
	Rot   Transform
	Mass  float32
	Charge byte
	Active bool
}

var srcPart, dstPart [N]Particle
var srcMat, dstMat [N]Transform
var srcVec, dstVec [N]Vec3

func init() {
	for i := 0; i < N; i++ {
		srcPart[i] = Particle{
			Pos: Vec3{float32(i) * 0.1, float32(i) * 0.2, float32(i) * 0.3},
			Mass: 1.0, Active: true,
		}
		srcMat[i].M[0] = 1
		srcMat[i].M[5] = 1
		srcMat[i].M[10] = 1
		srcMat[i].M[15] = 1
		srcVec[i] = Vec3{float32(i), float32(i + 1), float32(i + 2)}
	}
}

func benchParticleCopy() int {
	for i := 0; i < N; i++ {
		dstPart[i] = srcPart[i]
	}
	if dstPart[0].Active { return 1 }
	return 0
}

func benchMatCopy() int {
	for i := 0; i < N; i++ {
		dstMat[i] = srcMat[i]
	}
	return int(dstMat[0].M[0])
}

func benchMatUpdate() int {
	for i := 0; i < N; i++ {
		m := srcMat[i]
		m.M[0] *= 1.1
		m.M[5] *= 1.1
		m.M[10] *= 1.1
		m.M[15] *= 1.1
		dstMat[i] = m
	}
	return int(dstMat[0].M[0])
}

func benchVecCopy() int {
	for i := 0; i < N; i++ {
		dstVec[i] = srcVec[i]
	}
	return int(dstVec[0].X)
}

func benchmark(name string, fn func() int) {
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
	benchmark("Copy/ParticleCopy/100K", benchParticleCopy)
	benchmark("Copy/MatCopy/100K", benchMatCopy)
	benchmark("Copy/MatUpdate/100K", benchMatUpdate)
	benchmark("Copy/VecCopy/100K", benchVecCopy)
}
