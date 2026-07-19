package main

import (
	"bytes"
	"compress/gzip"
	"compress/zlib"
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

func mustWrite(label string, w io.Writer, data []byte) {
	if _, err := w.Write(data); err != nil {
		panic(label + " write: " + err.Error())
	}
	if c, ok := w.(io.Closer); ok {
		if err := c.Close(); err != nil {
			panic(label + " close: " + err.Error())
		}
	}
}

func mustReadAll(label string, r io.Reader) []byte {
	out, err := io.ReadAll(r)
	if err != nil {
		panic(label + " read: " + err.Error())
	}
	if c, ok := r.(io.Closer); ok {
		if err := c.Close(); err != nil {
			panic(label + " close: " + err.Error())
		}
	}
	return out
}

func mustMatch(label string, data, decompressed []byte) {
	if !bytes.Equal(data, decompressed) {
		panic(label + ": decompressed bytes mismatch")
	}
}

func benchDeflateCompress(data []byte) {
	var buf bytes.Buffer
	w := zlib.NewWriter(&buf)
	mustWrite("Deflate", w, data)
	ratio := float64(buf.Len()) / float64(len(data)) * 100

	start := time.Now()
	for i := 0; i < iterations; i++ {
		buf.Reset()
		w = zlib.NewWriter(&buf)
		mustWrite("Deflate", w, data)
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Deflate compress   %6.1f MB/s  ratio=%.1f%%\n",
		float64(dataSize*iterations)/1048576.0/elapsed, ratio)
}

func benchDeflateDecompress(data []byte) {
	var buf bytes.Buffer
	w := zlib.NewWriter(&buf)
	mustWrite("Deflate", w, data)
	compressed := append([]byte(nil), buf.Bytes()...)

	r, err := zlib.NewReader(bytes.NewReader(compressed))
	if err != nil {
		panic("Deflate reader: " + err.Error())
	}
	decompressed := mustReadAll("Deflate", r)
	mustMatch("Deflate", data, decompressed)

	start := time.Now()
	for i := 0; i < iterations; i++ {
		r, err = zlib.NewReader(bytes.NewReader(compressed))
		if err != nil {
			panic("Deflate reader: " + err.Error())
		}
		mustReadAll("Deflate", r)
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Deflate decompress %6.1f MB/s\n",
		float64(dataSize*iterations)/1048576.0/elapsed)
}

func benchGzipCompress(data []byte) {
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	mustWrite("Gzip", w, data)
	ratio := float64(buf.Len()) / float64(len(data)) * 100

	start := time.Now()
	for i := 0; i < iterations; i++ {
		buf.Reset()
		w = gzip.NewWriter(&buf)
		mustWrite("Gzip", w, data)
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("Gzip compress      %6.1f MB/s  ratio=%.1f%%\n",
		float64(dataSize*iterations)/1048576.0/elapsed, ratio)
}

func benchGzipDecompress(data []byte) {
	var buf bytes.Buffer
	w := gzip.NewWriter(&buf)
	mustWrite("Gzip", w, data)
	compressed := append([]byte(nil), buf.Bytes()...)

	r, err := gzip.NewReader(bytes.NewReader(compressed))
	if err != nil {
		panic("Gzip reader: " + err.Error())
	}
	decompressed := mustReadAll("Gzip", r)
	mustMatch("Gzip", data, decompressed)

	start := time.Now()
	for i := 0; i < iterations; i++ {
		r, err = gzip.NewReader(bytes.NewReader(compressed))
		if err != nil {
			panic("Gzip reader: " + err.Error())
		}
		mustReadAll("Gzip", r)
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
