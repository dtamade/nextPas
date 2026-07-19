// Simplified TUI kernels matching nextpas scorecard SC1–SC3 methodology.
// NOT a full tcell/ratatui port.
package main

import (
	"fmt"
	"time"
)

const (
	W          = 200
	H          = 50
	DiffIters  = 2000
	ParseIters = 5_000_000
)

type cell struct {
	ch byte
}

func newGrid(fill byte) []cell {
	g := make([]cell, W*H)
	for i := range g {
		g[i].ch = fill
	}
	return g
}

func diffCount(a, b []cell) int {
	n := 0
	for i := range a {
		if a[i].ch != b[i].ch {
			n++
		}
	}
	return n
}

func report(name string, d time.Duration, ops int) {
	ns := float64(d.Nanoseconds()) / float64(ops)
	opsS := 0.0
	if ns > 0 {
		opsS = 1e9 / ns
	}
	fmt.Printf("  %-40s %12.1f ns/op  %12.0f ops/s\n", name, ns, opsS)
}

// Minimal CSI up parse: ESC [ A
func parseCsiUp(buf []byte) bool {
	return len(buf) >= 3 && buf[0] == 27 && buf[1] == '[' && buf[2] == 'A'
}

func parseAscii(buf []byte) bool {
	return len(buf) >= 1 && buf[0] >= 32 && buf[0] < 127
}

// sink prevents DCE of pure kernels under -O
var sink int
var sinkB bool

func main() {
	fmt.Println("=== nextpas.core.tui bench_go_rust (Go) ===")

	base := newGrid('b')
	same := newGrid('b')
	dirty := newGrid('b')
	for i := 0; i < 10; i++ {
		row := i * 5
		if row < H {
			for x := 0; x < 5 && x < W; x++ {
				dirty[row*W+x].ch = 'D'
			}
		}
	}

	t0 := time.Now()
	for i := 0; i < DiffIters; i++ {
		sink += diffCount(base, same)
	}
	report("DiffIdentical 200x50", time.Since(t0), DiffIters)

	t0 = time.Now()
	for i := 0; i < DiffIters; i++ {
		sink += diffCount(base, dirty)
	}
	report("DiffDirty10 200x50", time.Since(t0), DiffIters)

	ascii := []byte{'a'}
	csi := []byte{27, '[', 'A'}

	t0 = time.Now()
	for i := 0; i < ParseIters; i++ {
		sinkB = parseAscii(ascii)
		if !sinkB {
			panic("ascii")
		}
	}
	report("ParseAscii", time.Since(t0), ParseIters)

	t0 = time.Now()
	for i := 0; i < ParseIters; i++ {
		sinkB = parseCsiUp(csi)
		if !sinkB {
			panic("csi")
		}
	}
	report("ParseCsiUp", time.Since(t0), ParseIters)
}
