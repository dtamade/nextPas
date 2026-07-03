package except

import (
	"errors"
	"fmt"
	"testing"
)

var exceptSink int64

// ExNoThrow: Go idiomatic error return (no error path)
// 10M iterations with if err != nil check
func BenchmarkExNoThrow(b *testing.B) {
	errNil := errors.New("sentinel") // pre-allocated to avoid allocation in hot path
	work := func(i int) (int, error) {
		return i, nil
	}
	for n := 0; n < b.N; n++ {
		sum := int64(0)
		for iter := 0; iter < 1000; iter++ {
			for i := 0; i < 10000; i++ {
				v, err := work(i)
				if err != nil {
					sum += int64(errNil.Error()[0]) // prevent DCE
				}
				sum += int64(v)
			}
		}
		exceptSink = sum
	}
}

// ExCatchRate: always return error
// 10K total error returns
func BenchmarkExCatchRate(b *testing.B) {
	errSentinel := errors.New("error")
	work := func(i int) (int, error) {
		return 0, errSentinel
	}
	for n := 0; n < b.N; n++ {
		count := int64(0)
		for iter := 0; iter < 100; iter++ {
			for i := 0; i < 100; i++ {
				_, err := work(i)
				if err != nil {
					count++
				}
			}
		}
		exceptSink = count
	}
}

// ExMixed: 1% error rate
// 1M iterations, ~10K errors
func BenchmarkExMixed(b *testing.B) {
	errSentinel := errors.New("error")
	work := func(i int) (int, error) {
		if i%100 == 0 {
			return 0, errSentinel
		}
		return i, nil
	}
	for n := 0; n < b.N; n++ {
		sum := int64(0)
		throwCount := int64(0)
		for iter := 0; iter < 100; iter++ {
			for i := 0; i < 10000; i++ {
				v, err := work(i)
				if err != nil {
					throwCount++
				} else {
					sum += int64(v)
				}
			}
		}
		exceptSink = sum + throwCount
	}
}

// ExFinally: always defer cleanup (10M iterations)
func BenchmarkExFinally(b *testing.B) {
	for n := 0; n < b.N; n++ {
		sum := int64(0)
		for iter := 0; iter < 1000; iter++ {
			for i := 0; i < 10000; i++ {
				cleanup := 0
				func() {
					defer func() { cleanup++ }()
					sum += int64(i)
				}()
				sum += int64(cleanup)
			}
		}
		exceptSink = sum
	}
}

func TestBenchPrint(t *testing.T) {
	fmt.Println("Except benchmarks compiled successfully")
}
