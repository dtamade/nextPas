package f64ops

import "math"
import "testing"

const (
	n     = 10000
	iters = 10000
)

var (
	a, b, c [n]float64
	sink    float64
)

func init() {
	for i := 0; i < n; i++ {
		a[i] = float64(i)*0.001 + 0.5
		b[i] = float64(n-i)*0.001 + 0.3
	}
}

func BenchmarkEuclideanDist(bm *testing.B) {
	for nn := 0; nn < bm.N; nn++ {
		sum := 0.0
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				diff := a[i] - b[i]
				sum += diff * diff
			}
		}
		sink = math.Sqrt(sum)
	}
}

func BenchmarkWeightedSum(bm *testing.B) {
	for nn := 0; nn < bm.N; nn++ {
		sum := 0.0
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				c[i] = a[i] + b[i]
				sum += a[i] * b[i]
			}
		}
		sink = sum + c[0]
	}
}

func BenchmarkClampNormalize(bm *testing.B) {
	for nn := 0; nn < bm.N; nn++ {
		sum := 0.0
		for iter := 0; iter < iters; iter++ {
			lo, hi := a[0], a[0]
			for i := 1; i < n; i++ {
				if a[i] < lo {
					lo = a[i]
				}
				if a[i] > hi {
					hi = a[i]
				}
			}
			rng := hi - lo
			if rng == 0 {
				rng = 1
			}
			for i := 0; i < n; i++ {
				c[i] = (a[i] - lo) / rng
				sum += c[i]
			}
		}
		sink = sum
	}
}

func BenchmarkFMAccum(bm *testing.B) {
	for nn := 0; nn < bm.N; nn++ {
		sum := 0.0
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				sum += a[i]*b[i] + c[i]
			}
		}
		sink = sum
	}
}

func BenchmarkDAXPY(bm *testing.B) {
	alpha := 2.71828
	for nn := 0; nn < bm.N; nn++ {
		sum := 0.0
		for iter := 0; iter < iters; iter++ {
			for i := 0; i < n; i++ {
				c[i] = alpha*a[i] + b[i]
				sum += c[i]
			}
		}
		sink = sum
	}
}
