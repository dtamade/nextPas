package main

// io_bench_test.go
// Go file I/O benchmark — matches Pascal io_bench.pas parameters

import (
	"bufio"
	"fmt"
	"os"
	"testing"
)

const (
	FILE_1MB  = 1024 * 1024
	FILE_10MB = 10 * 1024 * 1024
	IO_ROUNDS = 5
)

var tempPath = "/tmp/go_io_bench.dat"

func makeData(size int) []byte {
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

// --- Write 1MB (os.WriteFile — equivalent to Pascal WriteFile) ---

func BenchmarkWrite1MB(b *testing.B) {
	data := makeData(FILE_1MB)
	for n := 0; n < b.N; n++ {
		os.WriteFile(tempPath, data, 0644)
	}
}

// --- Read 1MB (os.ReadFile — equivalent to Pascal ReadFile) ---

func BenchmarkRead1MB(b *testing.B) {
	data := makeData(FILE_1MB)
	os.WriteFile(tempPath, data, 0644)
	for n := 0; n < b.N; n++ {
		read, _ := os.ReadFile(tempPath)
		_ = checksum(read)
	}
}

// --- Write 10MB ---

func BenchmarkWrite10MB(b *testing.B) {
	data := makeData(FILE_10MB)
	for n := 0; n < b.N; n++ {
		os.WriteFile(tempPath, data, 0644)
	}
}

// --- Read 10MB ---

func BenchmarkRead10MB(b *testing.B) {
	data := makeData(FILE_10MB)
	os.WriteFile(tempPath, data, 0644)
	for n := 0; n < b.N; n++ {
		read, _ := os.ReadFile(tempPath)
		_ = checksum(read)
	}
}

// --- Write Text (bufio.Writer with line-by-line) ---

func makeLines() string {
	s := ""
	for i := 0; i < 10000; i++ {
		s += "Hello, World! This is a benchmark line. \n"
	}
	return s
}

func BenchmarkWriteText(b *testing.B) {
	lines := makeLines()
	textPath := tempPath + ".txt"
	for n := 0; n < b.N; n++ {
		f, _ := os.Create(textPath)
		w := bufio.NewWriter(f)
		w.WriteString(lines)
		w.Flush()
		f.Close()
	}
}

// --- Read Text (bufio.Scanner line-by-line) ---

func BenchmarkReadText(b *testing.B) {
	lines := makeLines()
	textPath := tempPath + ".txt"
	os.WriteFile(textPath, []byte(lines), 0644)
	for n := 0; n < b.N; n++ {
		read, _ := os.ReadFile(textPath)
		_ = len(read)
	}
}

func main() {
	fmt.Println("Use: go test -bench=. -benchtime=3s")
}
