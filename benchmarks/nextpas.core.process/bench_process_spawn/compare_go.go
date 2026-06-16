package main

import (
	"fmt"
	"os/exec"
	"time"
)

const warmupIters = 50
const dur = 2000 * time.Millisecond

func printResult(name string, iters uint64, elapsed time.Duration, bytes uint64) {
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	if bytes > 0 {
		mbps := float64(bytes) / 1048576.0 / elapsed.Seconds()
		fmt.Printf("  %-40s %8d iters  %8.2f ms  %10.1f ns/op  %10.1f MB/s\n",
			name, iters, float64(elapsed.Milliseconds()), nsPerOp, mbps)
	} else {
		fmt.Printf("  %-40s %8d iters  %8.2f ms  %10.1f ns/op\n",
			name, iters, float64(elapsed.Milliseconds()), nsPerOp)
	}
}

func benchSpawnWait(duration time.Duration) {
	// warmup
	for i := 0; i < warmupIters; i++ {
		cmd := exec.Command("/bin/true")
		cmd.Run()
	}

	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		cmd := exec.Command("/bin/true")
		cmd.Run()
		iters++
	}
	elapsed := time.Since(start)
	printResult("SpawnWait /bin/true", iters, elapsed, 0)
}

func benchPipeThroughput(size int, duration time.Duration) {
	// warmup
	for i := 0; i < warmupIters; i++ {
		cmd := exec.Command("/bin/dd", "if=/dev/zero",
			"bs="+fmt.Sprint(size), "count=1", "status=none")
		cmd.Output()
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		cmd := exec.Command("/bin/dd", "if=/dev/zero",
			"bs="+fmt.Sprint(size), "count=1", "status=none")
		cmd.Output()
		bytes += uint64(size)
		iters++
	}
	elapsed := time.Since(start)
	printResult(fmt.Sprintf("PipeThroughput dd bs=%d", size), iters, elapsed, bytes)
}

func benchCaptureSize(size int, duration time.Duration) {
	// warmup
	for i := 0; i < warmupIters; i++ {
		cmd := exec.Command("/bin/dd", "if=/dev/zero",
			"bs="+fmt.Sprint(size), "count=1", "status=none")
		cmd.Output()
	}

	var bytes uint64
	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		cmd := exec.Command("/bin/dd", "if=/dev/zero",
			"bs="+fmt.Sprint(size), "count=1", "status=none")
		out, _ := cmd.Output()
		bytes += uint64(len(out))
		iters++
	}
	elapsed := time.Since(start)
	printResult(fmt.Sprintf("CaptureSize dd bs=%d", size), iters, elapsed, bytes)
}

func benchRun100Sequential(duration time.Duration) {
	// warmup
	for i := 0; i < 3; i++ {
		for j := 0; j < 100; j++ {
			cmd := exec.Command("/bin/true")
			cmd.Run()
		}
	}

	var iters uint64
	start := time.Now()
	for time.Since(start) < duration {
		for j := 0; j < 100; j++ {
			cmd := exec.Command("/bin/true")
			cmd.Run()
		}
		iters += 100
	}
	elapsed := time.Since(start)
	printResult("Run100Sequential /bin/true (x100)", iters, elapsed, 0)
}

func main() {
	fmt.Println("=== Go os/exec Process Benchmarks ===")
	fmt.Println()

	fmt.Println("--- SpawnWait ---")
	benchSpawnWait(dur)

	fmt.Println()
	fmt.Println("--- PipeThroughput ---")
	benchPipeThroughput(1024, dur)
	benchPipeThroughput(65536, dur)
	benchPipeThroughput(1048576, dur)

	fmt.Println()
	fmt.Println("--- CaptureSize ---")
	benchCaptureSize(1024, dur)
	benchCaptureSize(65536, dur)
	benchCaptureSize(1048576, dur)

	fmt.Println()
	fmt.Println("--- Run100Sequential ---")
	benchRun100Sequential(dur)

	fmt.Println()
	fmt.Println("Done.")
}
