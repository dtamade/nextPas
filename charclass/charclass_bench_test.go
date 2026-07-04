package main

import (
	"testing"
	
)

const N10K = 10000
const BUF_SIZE = 256

var gBuf [BUF_SIZE]byte
var gResult int

func init() {
	for i := range gBuf {
		gBuf[i] = byte(i)
	}
}

func BenchmarkIsDigit_10K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10K; j++ {
			for k := 0; k < BUF_SIZE; k++ {
				if gBuf[k] >= '0' && gBuf[k] <= '9' {
					c++
				}
			}
		}
		gResult = c
	}
}

func BenchmarkIsAlpha_10K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10K; j++ {
			for k := 0; k < BUF_SIZE; k++ {
				ch := gBuf[k]
				if (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') {
					c++
				}
			}
		}
		gResult = c
	}
}

func BenchmarkIsWhitespace_10K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10K; j++ {
			for k := 0; k < BUF_SIZE; k++ {
				ch := gBuf[k]
				if ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r' {
					c++
				}
			}
		}
		gResult = c
	}
}

func BenchmarkIsHexDigit_10K(b *testing.B) {
	for i := 0; i < b.N; i++ {
		c := 0
		for j := 0; j < N10K; j++ {
			for k := 0; k < BUF_SIZE; k++ {
				ch := gBuf[k]
				if (ch >= '0' && ch <= '9') || (ch >= 'a' && ch <= 'f') || (ch >= 'A' && ch <= 'F') {
					c++
				}
			}
		}
		gResult = c
	}
}
