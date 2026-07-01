package variant

import "testing"

type shapeKind int

const (
	kindCircle   shapeKind = 0
	kindRect     shapeKind = 1
	kindTriangle shapeKind = 2
)

type shape struct {
	kind   shapeKind
	radius float64 // circle
	width  float64 // rect + triangle base
	height float64 // rect height + triangle height
}

var shapes [10000]shape
var sinkFloat float64

func init() {
	for i := 0; i < 10000; i++ {
		switch i % 3 {
		case 0:
			shapes[i] = shape{kind: kindCircle, radius: float64(i) * 0.5}
		case 1:
			shapes[i] = shape{kind: kindRect, width: float64(i) * 0.5, height: float64(i) * 0.3}
		case 2:
			shapes[i] = shape{kind: kindTriangle, width: float64(i) * 0.5, height: float64(i) * 0.4}
		}
	}
}

func BenchmarkArea_10M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		a := 0.0
		for j := 0; j < 1000; j++ {
			for i := 0; i < 10000; i++ {
				switch shapes[i].kind {
				case kindCircle:
					a += 3.14159 * shapes[i].radius * shapes[i].radius
				case kindRect:
					a += shapes[i].width * shapes[i].height
				case kindTriangle:
					a += 0.5 * shapes[i].width * shapes[i].height
				}
			}
		}
		sinkFloat += a
	}
}

func BenchmarkTagOnly_10M(b *testing.B) {
	for n := 0; n < b.N; n++ {
		c := 0
		for j := 0; j < 1000; j++ {
			for i := 0; i < 10000; i++ {
				switch shapes[i].kind {
				case kindCircle:
					c++
				case kindRect:
					c += 2
				case kindTriangle:
					c += 3
				}
			}
		}
		sinkFloat += float64(c)
	}
}
