package main

import (
	"bytes"
	"testing"
)

const (
	N10K = 10000
	SIZE = 4096
)

var gArr [SIZE]byte
var gResult int

func init() {
	for i := range gArr { gArr[i] = byte(i) }
}

func BenchmarkCopyBytes_10K(b *testing.B) {
	var dst [SIZE]byte
	for i := 0; i < b.N; i++ {
		for j := 0; j < N10K; j++ {
			copy(dst[:], gArr[:])
		}
	}
	if dst[0] == 0 { println() }
}

func BenchmarkFillBytes_10K(b *testing.B) {
	var dst [SIZE]byte
	for i := 0; i < b.N; i++ {
		for j := 0; j < N10K; j++ {
			for k := range dst {
				dst[k] = 42
			}
		}
	}
	if dst[0] == 0 { println() }
}

func BenchmarkCompareBytes_10K(b *testing.B) {
	var dst [SIZE]byte
	copy(dst[:], gArr[:])
	for i := 0; i < b.N; i++ {
		for j := 0; j < N10K; j++ {
			if bytes.Equal(gArr[:], dst[:]) {
				gResult = 1
			}
		}
	}
}
