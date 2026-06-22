// bench_test.go — Go benchmarks with dynamic inputs to prevent optimization
package main

import (
	"math"
	"testing"
)

//go:noinline
func assertBool(b *testing.B, v bool) {
	if !v {
		b.Fatal("assertion failed")
	}
}

//go:noinline
func assertEqualInt64(b *testing.B, a, e int64) {
	if a != e {
		b.Fatalf("expected %d, got %d", e, a)
	}
}

//go:noinline
func assertEqualString(b *testing.B, a, e string) {
	if a != e {
		b.Fatalf("expected %q, got %q", e, a)
	}
}

//go:noinline
func assertNear(b *testing.B, a, e, eps float64) {
	if math.Abs(a-e) > eps {
		b.Fatalf("expected %f ± %f, got %f", e, eps, a)
	}
}

func BenchmarkCheckTrue(b *testing.B) {
	for i := 0; i < b.N; i++ {
		assertBool(b, i >= 0) // always true, but compiler can't prove it at compile time
	}
}

func BenchmarkCheckEqualInt64(b *testing.B) {
	v := int64(42)
	for i := 0; i < b.N; i++ {
		assertEqualInt64(b, v, 42)
	}
}

func BenchmarkCheckEqualString(b *testing.B) {
	v := "hello"
	for i := 0; i < b.N; i++ {
		assertEqualString(b, v, "hello")
	}
}

func BenchmarkCheckNear(b *testing.B) {
	v := 3.14
	for i := 0; i < b.N; i++ {
		assertNear(b, v, 3.1400000001, 1e-6)
	}
}
