// Package main is a Go HTTP/2 cleartext (h2c prior-knowledge) peer for
// nextPas bench_h2_server multiplex scale shape.
//
// Shape (aligned with H2P-1 mid / H2 KPI draft):
//   --connections N --streams S --batches B
//   target_ops = N * S * B
//   each connection: B batches of S concurrent GETs on one h2c connection
//
// Not a claim harness by itself — used with run_h2_comparison.sh.
package main

import (
	"context"
	"crypto/tls"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
	"sync"
	"sync/atomic"
	"time"

	"golang.org/x/net/http2"
	"golang.org/x/net/http2/h2c"
)

const responseBody = "h2-ok"

func rejectPositive(name string, v int) {
	fmt.Fprintf(os.Stderr, "invalid %s: %d; expected positive integer\n", name, v)
	os.Exit(2)
}

func main() {
	connections := flag.Int("connections", 8, "client connections (each owns one h2c conn)")
	streams := flag.Int("streams", 16, "streams per multiplex batch")
	batches := flag.Int("batches", 100, "batches per connection")
	flag.Parse()

	if *connections < 1 {
		rejectPositive("--connections", *connections)
	}
	if *streams < 1 {
		rejectPositive("--streams", *streams)
	}
	if *batches < 1 {
		rejectPositive("--batches", *batches)
	}

	targetOps := *connections * *streams * *batches

	handler := http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/plain")
		_, _ = io.WriteString(w, responseBody)
	})
	h2s := &http2.Server{}
	server := &http.Server{
		Handler: h2c.NewHandler(handler, h2s),
	}

	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		fmt.Fprintf(os.Stderr, "listen: %v\n", err)
		os.Exit(1)
	}
	port := ln.Addr().(*net.TCPAddr).Port
	url := fmt.Sprintf("http://127.0.0.1:%d/", port)

	go func() {
		if serveErr := server.Serve(ln); serveErr != nil && serveErr != http.ErrServerClosed {
			fmt.Fprintf(os.Stderr, "serve: %v\n", serveErr)
		}
	}()
	defer func() {
		ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
		defer cancel()
		_ = server.Shutdown(ctx)
	}()

	// Wait briefly for accept loop.
	time.Sleep(20 * time.Millisecond)

	fmt.Println("=== HTTP/2 Server Scale Harness (Go peer) ===")
	fmt.Println("  mode=multiplex")
	fmt.Println("  backend=net/http+h2c")
	fmt.Printf("  connections=%d\n", *connections)
	fmt.Printf("  streams_per_batch=%d\n", *streams)
	fmt.Printf("  batches_per_conn=%d\n", *batches)
	fmt.Printf("  target_ops=%d\n", targetOps)
	fmt.Printf("  port=%d\n", port)
	fmt.Println()

	var success int64
	var fail int64
	var wg sync.WaitGroup
	start := time.Now()

	for c := 0; c < *connections; c++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			// One Transport per connection ≈ one TCP + h2c session.
			tr := &http2.Transport{
				AllowHTTP: true,
				// Cleartext dial (h2c prior knowledge); DialTLS is the extension
				// point used by AllowHTTP when scheme is http.
				DialTLSContext: func(ctx context.Context, network, addr string, _ *tls.Config) (net.Conn, error) {
					var d net.Dialer
					return d.DialContext(ctx, network, addr)
				},
			}
			client := &http.Client{
				Transport: tr,
				Timeout:   30 * time.Second,
			}
			defer tr.CloseIdleConnections()

			for b := 0; b < *batches; b++ {
				var batchWG sync.WaitGroup
				for s := 0; s < *streams; s++ {
					batchWG.Add(1)
					go func() {
						defer batchWG.Done()
						resp, err := client.Get(url)
						if err != nil {
							atomic.AddInt64(&fail, 1)
							return
						}
						_, readErr := io.Copy(io.Discard, resp.Body)
						closeErr := resp.Body.Close()
						if readErr != nil || closeErr != nil || resp.StatusCode != http.StatusOK {
							atomic.AddInt64(&fail, 1)
							return
						}
						atomic.AddInt64(&success, 1)
					}()
				}
				batchWG.Wait()
			}
		}()
	}
	wg.Wait()
	elapsed := time.Since(start)

	completed := success
	elapsedNs := elapsed.Nanoseconds()
	reqPerSec := int64(0)
	if elapsedNs > 0 {
		reqPerSec = completed * int64(time.Second) / elapsedNs
	}
	stable := 0
	if fail == 0 && completed == int64(targetOps) {
		stable = 1
	}

	fmt.Printf("  elapsed_ms=%d\n", elapsed.Milliseconds())
	fmt.Printf("  req/s=%d\n", reqPerSec)
	fmt.Printf("  stable=%d\n", stable)
	fmt.Println()
	fmt.Println("operation=http.server.h2")
	fmt.Println("impl=go")
	fmt.Println("protocol=h2")
	fmt.Println("mode=multiplex")
	fmt.Println("backend=h2c")
	fmt.Println("cleartext=prior_knowledge")
	fmt.Printf("connections=%d\n", *connections)
	fmt.Printf("streams_per_batch=%d\n", *streams)
	fmt.Printf("batches_per_conn=%d\n", *batches)
	fmt.Printf("target_ops=%d\n", targetOps)
	fmt.Printf("completed=%d\n", completed)
	fmt.Printf("failed=%d\n", fail)
	fmt.Printf("elapsed_ns=%d\n", elapsedNs)
	fmt.Printf("req/s=%d\n", reqPerSec)
	fmt.Printf("stable=%d\n", stable)

	if stable != 1 {
		os.Exit(1)
	}
}
