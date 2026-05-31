package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/ed25519"
	"crypto/rand"
	"fmt"
	"time"

	"golang.org/x/crypto/curve25519"
	"golang.org/x/crypto/pbkdf2"
	"crypto/sha256"
)

func main() {
	fmt.Println("=== Go Crypto Benchmark (reference) ===")
	fmt.Println()
	dur := 2 * time.Second

	// AES-GCM
	fmt.Println("--- AES-GCM ---")
	for _, kl := range []int{16, 32} {
		for _, dl := range []int{64, 1024, 8192} {
			key := make([]byte, kl)
			rand.Read(key)
			nonce := make([]byte, 12)
			rand.Read(nonce)
			plain := make([]byte, dl)
			rand.Read(plain)

			block, _ := aes.NewCipher(key)
			gcm, _ := cipher.NewGCM(block)

			// warmup
			for i := 0; i < 20; i++ {
				gcm.Seal(nil, nonce, plain, nil)
			}

			var ops uint64
			start := time.Now()
			for time.Since(start) < dur {
				gcm.Seal(nil, nonce, plain, nil)
				ops++
			}
			elapsed := time.Since(start)
			mbps := float64(uint64(dl)*ops) / 1048576.0 / elapsed.Seconds()
			fmt.Printf("  AES-%d-GCM %5dB: %8.1f MB/s  (%d ops)\n", kl*8, dl, mbps, ops)
		}
	}

	// X25519
	fmt.Println("\n--- X25519 ---")
	{
		var priv, pub [32]byte
		rand.Read(priv[:])
		curve25519.ScalarBaseMult(&pub, &priv)
		var peer [32]byte
		rand.Read(peer[:])
		curve25519.ScalarBaseMult(&peer, &peer)

		for i := 0; i < 20; i++ {
			curve25519.ScalarMult(new([32]byte), &priv, &peer)
		}
		var ops uint64
		start := time.Now()
		for time.Since(start) < dur {
			curve25519.ScalarMult(new([32]byte), &priv, &peer)
			ops++
		}
		elapsed := time.Since(start)
		fmt.Printf("  X25519 ECDH:       %8d ops/s  (%.1f us/op)\n",
			ops*uint64(time.Second)/uint64(elapsed), float64(elapsed)/float64(ops)/1000)
	}

	// Ed25519
	fmt.Println("\n--- Ed25519 ---")
	{
		pub, priv, _ := ed25519.GenerateKey(rand.Reader)
		msg := []byte("benchmark message for ed25519")
		sig := ed25519.Sign(priv, msg)

		for i := 0; i < 20; i++ {
			ed25519.Sign(priv, msg)
		}
		var ops uint64
		start := time.Now()
		for time.Since(start) < dur {
			ed25519.Sign(priv, msg)
			ops++
		}
		elapsed := time.Since(start)
		fmt.Printf("  Ed25519 Sign:      %8d ops/s  (%.1f us/op)\n",
			ops*uint64(time.Second)/uint64(elapsed), float64(elapsed)/float64(ops)/1000)

		for i := 0; i < 20; i++ {
			ed25519.Verify(pub, msg, sig)
		}
		ops = 0
		start = time.Now()
		for time.Since(start) < dur {
			ed25519.Verify(pub, msg, sig)
			ops++
		}
		elapsed = time.Since(start)
		fmt.Printf("  Ed25519 Verify:    %8d ops/s  (%.1f us/op)\n",
			ops*uint64(time.Second)/uint64(elapsed), float64(elapsed)/float64(ops)/1000)
	}

	// PBKDF2
	fmt.Println("\n--- PBKDF2-SHA256 ---")
	for _, iter := range []int{1000, 10000, 100000} {
		pwd := []byte("password")
		salt := []byte("salt")

		var ops uint64
		start := time.Now()
		for time.Since(start) < dur {
			pbkdf2.Key(pwd, salt, iter, 32, sha256.New)
			ops++
		}
		elapsed := time.Since(start)
		fmt.Printf("  PBKDF2-SHA256 i=%d: %6d ops/s  (%.1f ms/op)\n",
			iter, ops*uint64(time.Second)/uint64(elapsed),
			float64(elapsed)/float64(ops)/float64(time.Millisecond))
	}
}
