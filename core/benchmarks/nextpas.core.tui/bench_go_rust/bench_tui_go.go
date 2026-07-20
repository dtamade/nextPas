// Simplified TUI kernels matching nextpas scorecard / bench methodology.
// NOT a full tcell/ratatui port.
package main

import (
	"fmt"
	"time"
)

const (
	W             = 200
	H             = 50
	DiffIters     = 2000
	ParseIters    = 5_000_000
	LayoutIters   = 1_000_000
	OverlayIters  = 200_000
	OvW           = 40
	OvH           = 12
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

// Geometry stub: three vertical bands with fixed top/bottom height 3.
func layoutVSplit3(totalH int) (h0, h1, h2 int) {
	h0, h2 = 3, 3
	h1 = totalH - h0 - h2
	if h1 < 0 {
		h1 = 0
	}
	return
}

// Marked overlay merge stub over byte grid.
func overlayMerge(base, dest, marks []byte, markCh byte) int {
	n := 0
	for i := range base {
		if marks[i] != 0 {
			dest[i] = markCh
			n++
		} else {
			dest[i] = base[i]
		}
	}
	return n
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

	t0 = time.Now()
	for i := 0; i < LayoutIters; i++ {
		a, b, c := layoutVSplit3(60)
		sink += a + b + c
	}
	report("LayoutVSplit3", time.Since(t0), LayoutIters)

	baseOv := make([]byte, OvW*OvH)
	destOv := make([]byte, OvW*OvH)
	marks := make([]byte, OvW*OvH)
	for i := range baseOv {
		baseOv[i] = '.'
	}
	// mark two cells like SetString "OV"
	marks[2] = 1
	marks[3] = 1

	t0 = time.Now()
	for i := 0; i < OverlayIters; i++ {
		sink += overlayMerge(baseOv, destOv, marks, 'O')
	}
	report("OverlayMerge 40x12", time.Since(t0), OverlayIters)
	_ = sink
}
