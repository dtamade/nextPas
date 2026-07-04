package bits

import (
	"math/rand"
	"testing"
)

const bitsN = 100000

type byteSet [32]byte

func setAdd(s *byteSet, v byte) {
	s[v/8] |= 1 << (v % 8)
}

func setHas(s *byteSet, v byte) bool {
	return s[v/8]&(1<<(v%8)) != 0
}

func setUnion(a, b *byteSet) byteSet {
	var r byteSet
	for i := 0; i < 32; i++ {
		r[i] = a[i] | b[i]
	}
	return r
}

func setIntersect(a, b *byteSet) byteSet {
	var r byteSet
	for i := 0; i < 32; i++ {
		r[i] = a[i] & b[i]
	}
	return r
}

func setDifference(a, b *byteSet) byteSet {
	var r byteSet
	for i := 0; i < 32; i++ {
		r[i] = a[i] &^ b[i]
	}
	return r
}

var (
	gSetA, gSetB byteSet
	gValues      []byte
)

func init() {
	rng := rand.New(rand.NewSource(12345))
	gValues = make([]byte, bitsN)
	for i := 0; i < bitsN; i++ {
		v := byte(rng.Intn(256))
		gValues[i] = v
		if i%2 == 0 {
			setAdd(&gSetA, v)
		} else {
			setAdd(&gSetB, v)
		}
	}
}

func BenchmarkUnion100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var r byteSet
		for i := 0; i < bitsN; i++ {
			r = setUnion(&gSetA, &gSetB)
		}
		_ = r[0]
	}
}

func BenchmarkIntersection100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var r byteSet
		for i := 0; i < bitsN; i++ {
			r = setIntersect(&gSetA, &gSetB)
		}
		_ = r[0]
	}
}

func BenchmarkDifference100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var r byteSet
		for i := 0; i < bitsN; i++ {
			r = setDifference(&gSetA, &gSetB)
		}
		_ = r[0]
	}
}

func BenchmarkMembership100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		count := 0
		for i := 0; i < bitsN; i++ {
			if setHas(&gSetA, gValues[i]) {
				count++
			}
		}
		_ = count
	}
}

func BenchmarkBuild100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s byteSet
		for i := 0; i < bitsN; i++ {
			setAdd(&s, gValues[i])
		}
		_ = s[0]
	}
}
