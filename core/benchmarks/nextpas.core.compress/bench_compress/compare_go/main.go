package main

import (
	"bytes"
	"compress/flate"
	"compress/gzip"
	"fmt"
	"io"
	"time"
)

const (
	dataSize   = 1024 * 1024
	iterations = 20
)

func generateData() []byte {
	data := make([]byte, dataSize)
	for i := range data {
		data[i] = byte((i*7 + i/256) % 251)
	}
	return data
}

func benchDeflateCompress(data []byte) {
	var buf bytes.Buffer
	w, _ := flate.NewWriter(&buf, flate.DefaultCompression)
	w.Write(data)
	w.Close()
	ratio := float64(buf.Len()) / float64(len(data)) * 100

	start := time.Now()
	for i := 0; i < iterations; i++ {
		buf.Reset()
		w.Reset(&buf)
		w.Write(data)
		w.Close()
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Deflate compress   %6.1f MB/s  ratio=%.1f%%\n",
		float64(dataSize*iterations)/1048576.0/elapsed, ratio)
}

func benchDeflateDecompress(data []byte) {
	var buf bytes.Buffer
	w, _ := flate.NewWriter(&buf, flate.DefaultCompression)
	w.Write(data)
	w.Close()
	compressed := buf.Bytes()

	start := time.Now()
	for i := 0; i < iterations; i++ {
		r := flate.NewReader(bytes.NewReader(compressed))
		io.ReadAll(r)
		r.Close()
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Deflate decompress %6.1f MB/s\n",
		float64(dataSize*iterations)/1048576.0/elapsed)
}

func benchGzipCompress(data []byte) {
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	w.Write(data)
	w.Close()
	ratio := float64(buf.Len()) / float64(len(data)) * 100

	start := time.Now()
	for i := 0; i < iterations; i++ {
		buf.Reset()
		w.Reset(&buf)
		w.Write(data)
		w.Close()
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Gzip compress      %6.1f MB/s  ratio=%.1f%%\n",
		float64(dataSize*iterations)/1048576.0/elapsed, ratio)
}

func benchGzipDecompress(data []byte) {
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	w.Write(data)
	w.Close()
	compressed := buf.Bytes()

	start := time.Now()
	for i := 0; i < iterations; i++ {
		r, _ := gzip.NewReader(bytes.NewReader(compressed))
		io.ReadAll(r)
		r.Close()
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Gzip decompress    %6.1f MB/s\n",
		float64(dataSize*iterations)/1048576.0/elapsed)
}

func main() {
	data := generateData()
	fmt.Printf("=== Go compress benchmark (1MB x %d iterations) ===\n\n", iterations)
	benchDeflateCompress(data)
	benchDeflateDecompress(data)
	fmt.Println()
	benchGzipCompress(data)
	benchGzipDecompress(data)
	fmt.Println("\ndone.")
}
