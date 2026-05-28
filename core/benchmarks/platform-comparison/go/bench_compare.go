package main

import (
	"crypto/rand"
	"fmt"
	"os"
	"path/filepath"
	"syscall"
	"time"
)

const (
	pathIters = 500000
	fsIters   = 200000
	mmapIters = 10000
	randIters = 200000
	warmup    = 1000
	testFile  = "/tmp/bench_exists_test.txt"
	mmapFile  = "/tmp/bench_mmap_1mb.dat"
)

func emit(op, impl string, iters int, nsPerOp int64) {
	fmt.Printf("%s\t%s\t%d\t%d\n", op, impl, iters, nsPerOp)
}

func benchPathJoin() {
	var s string
	for i := 0; i < warmup; i++ {
		s = filepath.Join("/home/user/projects", "nextpas/core/src/file.pas")
	}
	t0 := time.Now()
	for i := 0; i < pathIters; i++ {
		s = filepath.Join("/home/user/projects", "nextpas/core/src/file.pas")
	}
	elapsed := time.Since(t0)
	_ = s
	emit("path_join", "go", pathIters, elapsed.Nanoseconds()/int64(pathIters))
}

func benchPathBasename() {
	var s string
	for i := 0; i < warmup; i++ {
		s = filepath.Base("/home/user/projects/nextpas/core/src/file.pas")
	}
	t0 := time.Now()
	for i := 0; i < pathIters; i++ {
		s = filepath.Base("/home/user/projects/nextpas/core/src/file.pas")
	}
	elapsed := time.Since(t0)
	_ = s
	emit("path_basename", "go", pathIters, elapsed.Nanoseconds()/int64(pathIters))
}

func benchFileExists() {
	for i := 0; i < warmup; i++ {
		os.Stat(testFile)
	}
	t0 := time.Now()
	for i := 0; i < fsIters; i++ {
		os.Stat(testFile)
	}
	elapsed := time.Since(t0)
	emit("file_exists", "go", fsIters, elapsed.Nanoseconds()/int64(fsIters))
}

func benchMmap() {
	for i := 0; i < warmup; i++ {
		fd, _ := syscall.Open(mmapFile, syscall.O_RDONLY, 0)
		var st syscall.Stat_t
		syscall.Fstat(fd, &st)
		data, _ := syscall.Mmap(fd, 0, int(st.Size), syscall.PROT_READ, syscall.MAP_PRIVATE)
		syscall.Munmap(data)
		syscall.Close(fd)
	}
	t0 := time.Now()
	for i := 0; i < mmapIters; i++ {
		fd, _ := syscall.Open(mmapFile, syscall.O_RDONLY, 0)
		var st syscall.Stat_t
		syscall.Fstat(fd, &st)
		data, _ := syscall.Mmap(fd, 0, int(st.Size), syscall.PROT_READ, syscall.MAP_PRIVATE)
		syscall.Munmap(data)
		syscall.Close(fd)
	}
	elapsed := time.Since(t0)
	emit("mmap_open_close", "go", mmapIters, elapsed.Nanoseconds()/int64(mmapIters))
}

func benchRandom32() {
	buf := make([]byte, 32)
	for i := 0; i < warmup; i++ {
		rand.Read(buf)
	}
	t0 := time.Now()
	for i := 0; i < randIters; i++ {
		rand.Read(buf)
	}
	elapsed := time.Since(t0)
	emit("random_32B", "go", randIters, elapsed.Nanoseconds()/int64(randIters))
}

func main() {
	fmt.Println("operation\timpl\titerations\tns_per_op")
	benchPathJoin()
	benchPathBasename()
	benchFileExists()
	benchMmap()
	benchRandom32()
}
