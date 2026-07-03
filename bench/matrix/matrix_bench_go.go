// Matrix benchmark — Go
package main

import (
	"fmt"
	"time"
)

const (
	N128 = 128
	N256 = 256
	N512 = 512
)

var (
	a128, b128, c128 [N128][N128]int64
	a256, b256, c256 [N256][N256]int64
	a512, b512, c512 [N512][N512]int64
)

func initData() {
	for i := 0; i < N128; i++ {
		for j := 0; j < N128; j++ {
			a128[i][j] = int64(i*N128 + j + 1)
			b128[i][j] = int64((i + 1) * (j + 1))
		}
	}
	for i := 0; i < N256; i++ {
		for j := 0; j < N256; j++ {
			a256[i][j] = int64(i*N256 + j + 1)
			b256[i][j] = int64((i + 1) * (j + 1))
		}
	}
	for i := 0; i < N512; i++ {
		for j := 0; j < N512; j++ {
			a512[i][j] = int64(i*N512 + j + 1)
			b512[i][j] = int64((i + 1) * (j + 1))
		}
	}
}

func main() {
	initData()
	fmt.Println("=== Matrix Benchmark (Go) ===")

	// MatMul 128x128
	rounds := 10
	start := time.Now()
	for r := 0; r < rounds; r++ {
		for i := 0; i < N128; i++ {
			for j := 0; j < N128; j++ {
				var sum int64
				for k := 0; k < N128; k++ {
					sum += a128[i][k] * b128[k][j]
				}
				c128[i][j] = sum
			}
		}
	}
	elapsed := time.Since(start)
	bytes128 := int64(N128) * N128 * N128 * 2 * 8
	fmt.Printf("MatMul/128:  %d iters in %v (%.1f ms/iter, %.3f GB/s)\n",
		rounds, elapsed,
		float64(elapsed.Milliseconds())/float64(rounds),
		float64(bytes128*int64(rounds))/elapsed.Seconds()/1e9)

	// MatAdd 512x512
	rounds = 100
	start = time.Now()
	for r := 0; r < rounds; r++ {
		for i := 0; i < N512; i++ {
			for j := 0; j < N512; j++ {
				c512[i][j] = a512[i][j] + b512[i][j]
			}
		}
	}
	elapsed = time.Since(start)
	bytes512 := int64(N512) * N512 * 3 * 8
	fmt.Printf("MatAdd/512:  %d iters in %v (%.1f ms/iter, %.3f GB/s)\n",
		rounds, elapsed,
		float64(elapsed.Milliseconds())/float64(rounds),
		float64(bytes512*int64(rounds))/elapsed.Seconds()/1e9)

	// Transpose 512x512
	rounds = 100
	start = time.Now()
	for r := 0; r < rounds; r++ {
		c512 = a512
		for i := 0; i < N512; i++ {
			for j := i + 1; j < N512; j++ {
				c512[i][j], c512[j][i] = c512[j][i], c512[i][j]
			}
		}
	}
	elapsed = time.Since(start)
	bytesT := int64(N512) * N512 * 2 * 8
	fmt.Printf("Transpose/512: %d iters in %v (%.1f ms/iter, %.3f GB/s)\n",
		rounds, elapsed,
		float64(elapsed.Milliseconds())/float64(rounds),
		float64(bytesT*int64(rounds))/elapsed.Seconds()/1e9)

	// MatMul 256x256
	rounds = 5
	start = time.Now()
	for r := 0; r < rounds; r++ {
		for i := 0; i < N256; i++ {
			for j := 0; j < N256; j++ {
				var sum int64
				for k := 0; k < N256; k++ {
					sum += a256[i][k] * b256[k][j]
				}
				c256[i][j] = sum
			}
		}
	}
	elapsed = time.Since(start)
	bytes256 := int64(N256) * N256 * N256 * 2 * 8
	fmt.Printf("MatMul/256:  %d iters in %v (%.1f ms/iter, %.3f GB/s)\n",
		rounds, elapsed,
		float64(elapsed.Milliseconds())/float64(rounds),
		float64(bytes256*int64(rounds))/elapsed.Seconds()/1e9)
}
