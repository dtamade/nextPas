package main

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strconv"
	"time"
)

const warmupIters = 50
const dur = 2000 * time.Millisecond

func printResult(name string, iters uint64, elapsed time.Duration, bytes uint64) {
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	mbps := float64(bytes) / 1048576.0 / elapsed.Seconds()
	fmt.Printf("  %-30s %8d iters  %8.2f ms  %10.1f ns/op  %10.1f MB/s\n",
		name, iters, float64(elapsed.Milliseconds()), nsPerOp, mbps)
}

func printOpsResult(name string, iters uint64, elapsed time.Duration) {
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-30s %8d iters  %8.2f ms  %10.1f ns/op\n",
		name, iters, float64(elapsed.Milliseconds()), nsPerOp)
}

func formatSize(size int) string {
	if size >= 1048576 {
		return strconv.Itoa(size/1048576) + "MB"
	}
	if size >= 1024 {
		return strconv.Itoa(size/1024) + "KB"
	}
	return strconv.Itoa(size) + "B"
}

func benchReadFile(tmpDir string, size int, duration time.Duration) {
	path := tmpDir + "/bench_read_" + strconv.Itoa(size) + ".bin"
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i & 0xFF)
	}
	os.WriteFile(path, data, 0644)

	// warmup
	for i := 0; i < warmupIters; i++ {
		os.ReadFile(path)
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		os.ReadFile(path)
		bytes += uint64(size)
		iters++
	}
	elapsed := time.Since(start)
	printResult("ReadFile "+formatSize(size), iters, elapsed, bytes)
	os.Remove(path)
}

func benchWriteFile(tmpDir string, size int, duration time.Duration) {
	path := tmpDir + "/bench_write_" + strconv.Itoa(size) + ".bin"
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i & 0xFF)
	}

	// warmup
	for i := 0; i < warmupIters; i++ {
		os.WriteFile(path, data, 0644)
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		os.WriteFile(path, data, 0644)
		bytes += uint64(size)
		iters++
	}
	elapsed := time.Since(start)
	printResult("WriteFile "+formatSize(size), iters, elapsed, bytes)
	os.Remove(path)
}

func benchCopyFile(tmpDir string, size int, duration time.Duration) {
	src := tmpDir + "/bench_copy_src_" + strconv.Itoa(size) + ".bin"
	dst := tmpDir + "/bench_copy_dst_" + strconv.Itoa(size) + ".bin"
	data := make([]byte, size)
	for i := range data {
		data[i] = byte(i & 0xFF)
	}
	os.WriteFile(src, data, 0644)

	// warmup
	for i := 0; i < warmupIters; i++ {
		cpFile(src, dst)
		os.Remove(dst)
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		cpFile(src, dst)
		os.Remove(dst)
		bytes += uint64(size)
		iters++
	}
	elapsed := time.Since(start)
	printResult("CopyFile "+formatSize(size), iters, elapsed, bytes)
	os.Remove(src)
}

func cpFile(src, dst string) {
	in, _ := os.Open(src)
	defer in.Close()
	out, _ := os.Create(dst)
	defer out.Close()
	io.Copy(out, in)
}

func benchReadDir(tmpDir string, fileCount int, duration time.Duration) {
	dir := tmpDir + "/bench_readdir_" + strconv.Itoa(fileCount)
	os.MkdirAll(dir, 0755)
	for i := 0; i < fileCount; i++ {
		os.WriteFile(dir+"/f"+strconv.Itoa(i)+".txt", []byte{0}, 0644)
	}

	// warmup
	for i := 0; i < warmupIters; i++ {
		os.ReadDir(dir)
	}

	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		os.ReadDir(dir)
		iters++
	}
	elapsed := time.Since(start)
	printOpsResult("ReadDir "+strconv.Itoa(fileCount)+" files", iters, elapsed)
	os.RemoveAll(dir)
}

func createWalkTree(base string, width, depth int) {
	os.MkdirAll(base, 0755)
	for i := 0; i < width; i++ {
		os.WriteFile(base+"/f"+strconv.Itoa(i)+".txt", []byte{0}, 0644)
	}
	if depth > 1 {
		for i := 0; i < width; i++ {
			createWalkTree(base+"/d"+strconv.Itoa(i), width, depth-1)
		}
	}
}

func benchWalk(tmpDir string, width, depth int, duration time.Duration) {
	walkDir := tmpDir + "/bench_walk_w" + strconv.Itoa(width) + "_d" + strconv.Itoa(depth)
	createWalkTree(walkDir, width, depth)

	// warmup
	for i := 0; i < warmupIters; i++ {
		count := 0
		filepath.Walk(walkDir, func(path string, info os.FileInfo, err error) error {
			count++
			return nil
		})
	}

	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		count := 0
		filepath.Walk(walkDir, func(path string, info os.FileInfo, err error) error {
			count++
			return nil
		})
		iters++
	}
	elapsed := time.Since(start)
	printOpsResult(fmt.Sprintf("Walk w=%d d=%d", width, depth), iters, elapsed)
	os.RemoveAll(walkDir)
}

func benchPathJoin(components int, duration time.Duration) {
	parts := make([]string, components)
	for i := range parts {
		parts[i] = "component" + strconv.Itoa(i)
	}

	// warmup
	for i := 0; i < warmupIters; i++ {
		filepath.Join(parts...)
	}

	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		filepath.Join(parts...)
		iters++
	}
	elapsed := time.Since(start)
	printOpsResult("PathJoin "+strconv.Itoa(components)+" parts", iters, elapsed)
}

func benchScanFileLines(tmpDir string, lineCount int, duration time.Duration) {
	path := tmpDir + "/bench_scan_" + strconv.Itoa(lineCount) + ".txt"
	f, _ := os.Create(path)
	for i := 0; i < lineCount; i++ {
		fmt.Fprintf(f, "line %d some padding text to make lines longer for realistic testing\n", i)
	}
	f.Close()

	// warmup
	for i := 0; i < warmupIters; i++ {
		f2, _ := os.Open(path)
		scanner := bufio.NewScanner(f2)
		for scanner.Scan() {
			_ = scanner.Text()
		}
		f2.Close()
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		f2, _ := os.Open(path)
		scanner := bufio.NewScanner(f2)
		for scanner.Scan() {
			bytes += uint64(len(scanner.Text()))
		}
		f2.Close()
		iters++
	}
	elapsed := time.Since(start)
	printResult("ScanFileLines "+strconv.Itoa(lineCount)+" lines", iters, elapsed, bytes)
	os.Remove(path)
}

func main() {
	tmpDir, _ := os.MkdirTemp("", "go_fs_bench_")
	defer os.RemoveAll(tmpDir)

	fmt.Println("=== Go stdlib fs IO Benchmarks ===")
	fmt.Println()

	fmt.Println("--- ReadFile ---")
	benchReadFile(tmpDir, 1024, dur)
	benchReadFile(tmpDir, 65536, dur)
	benchReadFile(tmpDir, 1048576, dur)
	benchReadFile(tmpDir, 16777216, dur)

	fmt.Println()
	fmt.Println("--- WriteFile ---")
	benchWriteFile(tmpDir, 1024, dur)
	benchWriteFile(tmpDir, 65536, dur)
	benchWriteFile(tmpDir, 1048576, dur)
	benchWriteFile(tmpDir, 16777216, dur)

	fmt.Println()
	fmt.Println("--- CopyFile ---")
	benchCopyFile(tmpDir, 1024, dur)
	benchCopyFile(tmpDir, 65536, dur)
	benchCopyFile(tmpDir, 1048576, dur)
	benchCopyFile(tmpDir, 16777216, dur)

	fmt.Println()
	fmt.Println("--- ReadDir ---")
	benchReadDir(tmpDir, 10, dur)
	benchReadDir(tmpDir, 100, dur)
	benchReadDir(tmpDir, 1000, dur)

	fmt.Println()
	fmt.Println("--- Walk ---")
	benchWalk(tmpDir, 3, 3, dur)
	benchWalk(tmpDir, 3, 10, dur)

	fmt.Println()
	fmt.Println("--- PathJoin ---")
	benchPathJoin(2, dur)
	benchPathJoin(5, dur)

	fmt.Println()
	fmt.Println("--- ScanFileLines ---")
	benchScanFileLines(tmpDir, 100, dur)
	benchScanFileLines(tmpDir, 10000, dur)

	fmt.Println()
	fmt.Println("Done.")
}
