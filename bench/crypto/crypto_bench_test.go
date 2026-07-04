package main

// crypto_bench_test.go
// Go crypto hash benchmark — matches Pascal crypto_bench.pas parameters

import (
	"crypto/md5"
	"crypto/sha256"
	"crypto/sha512"
	"fmt"
	"testing"
)

const (
	HASH_SMALL_N    = 10000
	HASH_SMALL_SIZE = 1
	HASH_LARGE_N    = 1000
	HASH_LARGE_SIZE = 1024
)

func makePayload(size int) []byte {
	b := make([]byte, size)
	for i := range b {
		b[i] = byte(i & 0xFF)
	}
	return b
}

func checksum(b []byte) byte {
	var x byte
	for _, v := range b {
		x ^= v
	}
	return x
}

// --- MD5 ---

func BenchmarkMD5Small(b *testing.B) {
	data := make([]byte, HASH_SMALL_SIZE)
	data[0] = 0x42
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_SMALL_N; i++ {
			h := md5.Sum(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

func BenchmarkMD5Large(b *testing.B) {
	data := makePayload(HASH_LARGE_SIZE)
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_LARGE_N; i++ {
			h := md5.Sum(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

// --- SHA-256 ---

func BenchmarkSHA256Small(b *testing.B) {
	data := make([]byte, HASH_SMALL_SIZE)
	data[0] = 0x42
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_SMALL_N; i++ {
			h := sha256.Sum256(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

func BenchmarkSHA256Large(b *testing.B) {
	data := makePayload(HASH_LARGE_SIZE)
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_LARGE_N; i++ {
			h := sha256.Sum256(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

// --- SHA-512 ---

func BenchmarkSHA512Small(b *testing.B) {
	data := make([]byte, HASH_SMALL_SIZE)
	data[0] = 0x42
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_SMALL_N; i++ {
			h := sha512.Sum512(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

func BenchmarkSHA512Large(b *testing.B) {
	data := makePayload(HASH_LARGE_SIZE)
	for n := 0; n < b.N; n++ {
		var dummy byte
		for i := 0; i < HASH_LARGE_N; i++ {
			h := sha512.Sum512(data)
			dummy ^= checksum(h[:])
		}
		_ = dummy
	}
}

func main() {
	fmt.Println("Use: go test -bench=. -benchtime=3s")
}
