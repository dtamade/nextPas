package main

import (
	"context"
	"fmt"
	"io"
	"log/slog"
	"os"
	"time"
)

const (
	iters   = 1000000
	itersIO = 100000
)

func bench(name string, n int64, elapsed time.Duration) {
	ns := elapsed.Nanoseconds()
	nsPerOp := float64(ns) / float64(n)
	fmt.Printf("  %-40s %10d iters  %8.2f ms  %8.1f ns/op\n",
		name, n, float64(ns)/1e6, nsPerOp)
}

// discardHandler is a no-op handler for measuring pure overhead
type discardHandler struct {
	minLevel slog.Level
}

func (h *discardHandler) Enabled(_ context.Context, level slog.Level) bool {
	return level >= h.minLevel
}

func (h *discardHandler) Handle(_ context.Context, _ slog.Record) error {
	return nil
}

func (h *discardHandler) WithAttrs(_ []slog.Attr) slog.Handler {
	return h
}

func (h *discardHandler) WithGroup(_ string) slog.Handler {
	return h
}

func benchLogDisabled() {
	logger := slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelError}))
	start := time.Now()
	for i := 0; i < iters; i++ {
		logger.Debug("disabled", "key", "value")
	}
	bench("Disabled (below threshold)", int64(iters), time.Since(start))
}

func benchLogSimple() {
	logger := slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelDebug}))
	start := time.Now()
	for i := 0; i < iters; i++ {
		logger.Info("hello")
	}
	bench("Simple Msg (discard)", int64(iters), time.Since(start))
}

func benchLogWithAttrs() {
	logger := slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelDebug}))
	start := time.Now()
	for i := 0; i < iters; i++ {
		logger.Info("test", "key", "value", "count", 42, "ok", true)
	}
	bench("WithAttrs Str+Int+Bool (discard)", int64(iters), time.Since(start))
}

func benchLogText() {
	logger := slog.New(slog.NewTextHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelDebug}))
	start := time.Now()
	for i := 0; i < itersIO; i++ {
		logger.Info("text bench", "key", "value")
	}
	bench("Text handler (discard)", int64(itersIO), time.Since(start))
}

func benchLogJSON() {
	logger := slog.New(slog.NewJSONHandler(io.Discard, &slog.HandlerOptions{Level: slog.LevelDebug}))
	start := time.Now()
	for i := 0; i < itersIO; i++ {
		logger.Info("json bench", "key", "value", "n", 42)
	}
	bench("JSON handler (discard)", int64(itersIO), time.Since(start))
}

func benchLogFile() {
	f, err := os.CreateTemp("", "bench_log_go_*.txt")
	if err != nil {
		panic(err)
	}
	defer os.Remove(f.Name())
	defer f.Close()

	logger := slog.New(slog.NewTextHandler(f, &slog.HandlerOptions{Level: slog.LevelDebug}))
	start := time.Now()
	for i := 0; i < itersIO; i++ {
		logger.Info("file bench", "key", "value", "n", i)
	}
	bench("File handler (/tmp)", int64(itersIO), time.Since(start))
}

func main() {
	fmt.Println("=== Go log/slog benchmarks ===")
	fmt.Println()

	benchLogDisabled()
	benchLogSimple()
	benchLogWithAttrs()
	benchLogText()
	benchLogJSON()
	benchLogFile()

	fmt.Println()
	fmt.Println("Done.")
}
