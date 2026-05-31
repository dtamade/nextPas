package main

import (
	"crypto/ecdh"
	"crypto/rand"
	"crypto/sha256"
	"fmt"
	"golang.org/x/crypto/hkdf"
	"io"
	"time"
)

func benchKeyExchange(iters int) {
	// Pre-generate a "server" key
	serverKey, _ := ecdh.X25519().GenerateKey(rand.Reader)
	serverPub := serverKey.PublicKey()

	start := time.Now()
	for i := 0; i < iters; i++ {
		// Client generates key pair
		clientKey, _ := ecdh.X25519().GenerateKey(rand.Reader)

		// ECDHE
		shared, _ := clientKey.ECDH(serverPub)

		// HKDF-Extract + Expand (simulate TLS 1.3 key schedule)
		salt := make([]byte, 32)
		hkdfReader := hkdf.New(sha256.New, shared, salt, []byte("tls13 derived"))
		key := make([]byte, 16)
		io.ReadFull(hkdfReader, key)
		_ = key
	}
	elapsed := time.Since(start)
	usPerOp := float64(elapsed.Microseconds()) / float64(iters)
	fmt.Printf("  Go X25519 + HKDF key exchange: %8.1f us/op  (%d iters)\n", usPerOp, iters)
}

func main() {
	fmt.Println("=== Go TLS Key Exchange Benchmark ===")
	fmt.Println()
	benchKeyExchange(100)
	benchKeyExchange(500)
	benchKeyExchange(2000)
}
