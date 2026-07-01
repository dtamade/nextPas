package recops

import (
	"fmt"
	"math/rand"
	"testing"
)

const (
	benchN    = 10000
	benchIter = 1000
)

type BenchRec struct {
	A, B int64
	C, D int32
	E, F float64
}

var benchData []BenchRec
var benchDst []BenchRec

func init() {
	benchData = make([]BenchRec, benchN)
	benchDst = make([]BenchRec, benchN)
	r := rand.New(rand.NewSource(42))
	for i := range benchData {
		v := r.Int63()
		benchData[i] = BenchRec{
			A: v,
			B: v / 3,
			C: int32(v & 0x7FFFFFFF),
			D: int32((v >> 32) & 0x7FFFFFFF),
			E: float64(v%10000) * 0.0001,
			F: float64(v%7777) * 0.0001,
		}
	}
}

func BenchmarkRecFilter(b *testing.B) {
	for n := 0; n < b.N; n++ {
		count := 0
		for i := 0; i < benchIter; i++ {
			thresh := int64(i) * 1000
			for j := 0; j < benchN; j++ {
				if benchData[j].A > thresh {
					benchDst[count%benchN] = benchData[j]
					count++
				}
			}
		}
		_ = count
	}
}

func BenchmarkRecCopy(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < benchIter; i++ {
			copy(benchDst, benchData)
		}
		_ = benchDst[0].A
	}
}

func BenchmarkRecFieldSum(b *testing.B) {
	for n := 0; n < b.N; n++ {
		sum := int64(0)
		for i := 0; i < benchIter; i++ {
			for j := 0; j < benchN; j++ {
				sum += benchData[j].A
			}
		}
		_ = sum
	}
}

func BenchmarkRecBuild(b *testing.B) {
	for n := 0; n < b.N; n++ {
		for i := 0; i < benchIter; i++ {
			for j := 0; j < benchN; j++ {
				v := benchData[j].A + benchData[j].B
				benchDst[j].A = v
				benchDst[j].B = v * 2
				benchDst[j].C = benchData[j].C
				benchDst[j].D = benchData[j].D
				benchDst[j].E = benchData[j].E + benchData[j].F
				benchDst[j].F = benchData[j].E * benchData[j].F
			}
		}
		_ = benchDst[0].A
	}
}

func TestBenchPrint(t *testing.T) {
	fmt.Println("RecOps benchmarks compiled successfully")
}
