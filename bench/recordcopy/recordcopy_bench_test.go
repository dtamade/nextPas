package recordcopy

import "testing"

const N = 100000

type Vec3 struct{ X, Y, Z float32 }

type Transform struct {
	M [16]float32
}

type Particle struct {
	Pos    Vec3
	Vel    Vec3
	Accel  Vec3
	Rot    Transform
	Mass   float32
	Charge byte
	Active bool
}

var srcPart, dstPart [N]Particle
var srcMat, dstMat [N]Transform
var srcVec, dstVec [N]Vec3
var sink int

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

func BenchmarkParticleAssign(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < N; i++ {
			dstPart[i] = srcPart[i]
		}
	}
	sink = int(dstPart[0].Mass)
}

func BenchmarkMatAssign(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < N; i++ {
			dstMat[i] = srcMat[i]
		}
	}
	sink = int(dstMat[0].M[0])
}

func BenchmarkMatMove(b *testing.B) {
	for n := 0; n < b.N; n++ {
		copy(dstMat[:], srcMat[:])
	}
	sink = int(dstMat[0].M[0])
}

func BenchmarkMatUpdate(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < N; i++ {
			m := srcMat[i]
			m.M[0] *= 1.1
			m.M[5] *= 1.1
			m.M[10] *= 1.1
			m.M[15] *= 1.1
			dstMat[i] = m
		}
	}
	sink = int(dstMat[0].M[0])
}

func BenchmarkMatFields(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < N; i++ {
			dstMat[i].M[0] = srcMat[i].M[0]
			dstMat[i].M[1] = srcMat[i].M[1]
			dstMat[i].M[2] = srcMat[i].M[2]
			dstMat[i].M[3] = srcMat[i].M[3]
			dstMat[i].M[4] = srcMat[i].M[4]
			dstMat[i].M[5] = srcMat[i].M[5]
			dstMat[i].M[6] = srcMat[i].M[6]
			dstMat[i].M[7] = srcMat[i].M[7]
			dstMat[i].M[8] = srcMat[i].M[8]
			dstMat[i].M[9] = srcMat[i].M[9]
			dstMat[i].M[10] = srcMat[i].M[10]
			dstMat[i].M[11] = srcMat[i].M[11]
			dstMat[i].M[12] = srcMat[i].M[12]
			dstMat[i].M[13] = srcMat[i].M[13]
			dstMat[i].M[14] = srcMat[i].M[14]
			dstMat[i].M[15] = srcMat[i].M[15]
		}
	}
	sink = int(dstMat[0].M[0])
}

func BenchmarkVecAssign(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < N; i++ {
			dstVec[i] = srcVec[i]
		}
	}
	sink = int(dstVec[0].X)
}
