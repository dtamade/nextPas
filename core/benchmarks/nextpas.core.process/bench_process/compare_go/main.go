package main

import (
	"fmt"
	"os/exec"
	"time"
)

func main() {
	fmt.Println("=== Go process scorecard (host) ===")
	n := 200
	start := time.Now()
	for i := 0; i < n; i++ {
		_, _ = exec.LookPath("sh")
	}
	elapsed := time.Since(start)
	fmt.Printf("LookPath(sh): n=%d total_ms=%d avg_us=%d\n", n, elapsed.Milliseconds(), elapsed.Microseconds()/int64(n))

	n = 50
	start = time.Now()
	for i := 0; i < n; i++ {
		cmd := exec.Command("/bin/true")
		_ = cmd.Run()
	}
	elapsed = time.Since(start)
	fmt.Printf("exec.Command(/bin/true).Run: n=%d total_ms=%d avg_us=%d\n", n, elapsed.Milliseconds(), elapsed.Microseconds()/int64(n))

	start = time.Now()
	for i := 0; i < n; i++ {
		cmd := exec.Command("/bin/echo", "x")
		_, _ = cmd.Output()
	}
	elapsed = time.Since(start)
	fmt.Printf("exec.Command(echo x).Output: n=%d total_ms=%d avg_us=%d\n", n, elapsed.Milliseconds(), elapsed.Microseconds()/int64(n))
}
