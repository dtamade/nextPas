package main

import (
	"fmt"
	"math"
	"time"
)

const N = 100000

type Shape interface {
	Area() float64
	Perimeter() float64
	Kind() int
}

type Circle struct{ Radius float64 }
func (c Circle) Area() float64      { return math.Pi * c.Radius * c.Radius }
func (c Circle) Perimeter() float64 { return 2 * math.Pi * c.Radius }
func (c Circle) Kind() int          { return 0 }

type Rect struct{ W, H float64 }
func (r Rect) Area() float64      { return r.W * r.H }
func (r Rect) Perimeter() float64 { return 2 * (r.W + r.H) }
func (r Rect) Kind() int          { return 1 }

type Triangle struct{ A, B, C float64 }
func (t Triangle) Area() float64 {
	s := (t.A + t.B + t.C) * 0.5
	return math.Sqrt(s * (s - t.A) * (s - t.B) * (s - t.C))
}
func (t Triangle) Perimeter() float64 { return t.A + t.B + t.C }
func (t Triangle) Kind() int          { return 2 }

var shapes [N]Shape

func init() {
	for i := 0; i < N; i++ {
		switch i % 3 {
		case 0:
			shapes[i] = Circle{Radius: 1.0 + float64(i)*0.001}
		case 1:
			shapes[i] = Rect{W: 1.0 + float64(i)*0.001, H: 2.0 + float64(i)*0.001}
		case 2:
			shapes[i] = Triangle{A: 3, B: 4, C: 5}
		}
	}
}

func benchArea() float64 {
	sum := 0.0
	for i := 0; i < N; i++ {
		sum += shapes[i].Area()
	}
	return sum
}

func benchPerimeter() float64 {
	sum := 0.0
	for i := 0; i < N; i++ {
		sum += shapes[i].Perimeter()
	}
	return sum
}

func benchKind() int {
	sum := 0
	for i := 0; i < N; i++ {
		sum += shapes[i].Kind()
	}
	return sum
}

// Direct call baseline (single concrete type)
func benchDirectArea() float64 {
	c := Circle{Radius: 1.5}
	sum := 0.0
	for i := 0; i < N; i++ {
		sum += c.Area()
	}
	return sum
}

func benchmark(name string, fn func() float64) {
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
	benchmark("Interfaced/Area/100K", func() float64 { return benchArea() })
	benchmark("Interfaced/Perimeter/100K", func() float64 { return benchPerimeter() })
	benchmark("Interfaced/Kind/100K", func() float64 { return float64(benchKind()) })
	benchmark("Direct/Area/100K", func() float64 { return benchDirectArea() })
}
