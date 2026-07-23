// Package main is a Go HTTP/2 peer for nextPas bench_h2_server scale shapes.
//
// Default: cleartext h2c prior-knowledge (HS-0/HS-1).
// --tls: HTTPS with ALPN h2 and self-signed cert (C-D HTTPS H2 scale KPI).
//
// Shape (aligned with H2P-1 mid / H2 KPI):
//   --connections N --streams S --batches B
//   target_ops = N * S * B
//   each connection: B batches of S concurrent GETs on one H2 connection
//
// Not a claim harness by itself — used with run_h2_comparison.sh.
package main

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/tls"
	"crypto/x509"
	"crypto/x509/pkix"
	"encoding/pem"
	"flag"
	"fmt"
	"io"
	"math/big"
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

func mustSelfSignedCert() tls.Certificate {
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	if err != nil {
		fmt.Fprintf(os.Stderr, "generate key: %v\n", err)
		os.Exit(1)
	}
	serial, err := rand.Int(rand.Reader, big.NewInt(1<<62))
	if err != nil {
		fmt.Fprintf(os.Stderr, "serial: %v\n", err)
		os.Exit(1)
	}
	tmpl := &x509.Certificate{
		SerialNumber: serial,
		Subject: pkix.Name{
			CommonName:   "127.0.0.1",
			Organization: []string{"nextpas-h2-bench"},
		},
		NotBefore:             time.Now().Add(-time.Hour),
		NotAfter:              time.Now().Add(24 * time.Hour),
		KeyUsage:              x509.KeyUsageDigitalSignature | x509.KeyUsageKeyEncipherment,
		ExtKeyUsage:           []x509.ExtKeyUsage{x509.ExtKeyUsageServerAuth},
		BasicConstraintsValid: true,
		IPAddresses:           []net.IP{net.ParseIP("127.0.0.1")},
	}
	der, err := x509.CreateCertificate(rand.Reader, tmpl, tmpl, &key.PublicKey, key)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create cert: %v\n", err)
		os.Exit(1)
	}
	certPEM := pem.EncodeToMemory(&pem.Block{Type: "CERTIFICATE", Bytes: der})
	keyDER, err := x509.MarshalECPrivateKey(key)
	if err != nil {
		fmt.Fprintf(os.Stderr, "marshal key: %v\n", err)
		os.Exit(1)
	}
	keyPEM := pem.EncodeToMemory(&pem.Block{Type: "EC PRIVATE KEY", Bytes: keyDER})
	cert, err := tls.X509KeyPair(certPEM, keyPEM)
	if err != nil {
		fmt.Fprintf(os.Stderr, "x509 key pair: %v\n", err)
		os.Exit(1)
	}
	return cert
}

func main() {
	connections := flag.Int("connections", 8, "client connections (each owns one H2 conn)")
	streams := flag.Int("streams", 16, "streams per multiplex batch")
	batches := flag.Int("batches", 100, "batches per connection")
	useTLS := flag.Bool("tls", false, "HTTPS ALPN h2 (self-signed); default is h2c")
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

	var (
		ln       net.Listener
		url      string
		backend  string
		cleartxt string
		trans    string
		serveErr error
	)

	if *useTLS {
		cert := mustSelfSignedCert()
		tlsCfg := &tls.Config{
			Certificates: []tls.Certificate{cert},
			NextProtos:   []string{http2.NextProtoTLS, "http/1.1"},
			MinVersion:   tls.VersionTLS12,
		}
		server := &http.Server{
			Handler:   handler,
			TLSConfig: tlsCfg,
		}
		if err := http2.ConfigureServer(server, &http2.Server{}); err != nil {
			fmt.Fprintf(os.Stderr, "configure http2: %v\n", err)
			os.Exit(1)
		}
		raw, err := net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			fmt.Fprintf(os.Stderr, "listen: %v\n", err)
			os.Exit(1)
		}
		ln = tls.NewListener(raw, tlsCfg)
		port := raw.Addr().(*net.TCPAddr).Port
		url = fmt.Sprintf("https://127.0.0.1:%d/", port)
		backend = "net/http+tls-h2"
		cleartxt = "false"
		trans = "tls-alpn-h2"
		go func() {
			serveErr = server.Serve(ln)
			if serveErr != nil && serveErr != http.ErrServerClosed {
				fmt.Fprintf(os.Stderr, "serve: %v\n", serveErr)
			}
		}()
		defer func() {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			_ = server.Shutdown(ctx)
		}()
	} else {
		h2s := &http2.Server{}
		server := &http.Server{
			Handler: h2c.NewHandler(handler, h2s),
		}
		var err error
		ln, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			fmt.Fprintf(os.Stderr, "listen: %v\n", err)
			os.Exit(1)
		}
		port := ln.Addr().(*net.TCPAddr).Port
		url = fmt.Sprintf("http://127.0.0.1:%d/", port)
		backend = "net/http+h2c"
		cleartxt = "prior_knowledge"
		trans = "h2c-prior-knowledge"
		go func() {
			serveErr = server.Serve(ln)
			if serveErr != nil && serveErr != http.ErrServerClosed {
				fmt.Fprintf(os.Stderr, "serve: %v\n", serveErr)
			}
		}()
		defer func() {
			ctx, cancel := context.WithTimeout(context.Background(), 2*time.Second)
			defer cancel()
			_ = server.Shutdown(ctx)
		}()
	}

	// Wait briefly for accept loop.
	time.Sleep(20 * time.Millisecond)

	fmt.Println("=== HTTP/2 Server Scale Harness (Go peer) ===")
	fmt.Println("  mode=multiplex")
	fmt.Printf("  backend=%s\n", backend)
	fmt.Printf("  transport=%s\n", trans)
	fmt.Printf("  connections=%d\n", *connections)
	fmt.Printf("  streams_per_batch=%d\n", *streams)
	fmt.Printf("  batches_per_conn=%d\n", *batches)
	fmt.Printf("  target_ops=%d\n", targetOps)
	fmt.Println()

	var success int64
	var fail int64
	var wg sync.WaitGroup
	start := time.Now()

	for c := 0; c < *connections; c++ {
		wg.Add(1)
		go func() {
			defer wg.Done()
			var client *http.Client
			if *useTLS {
				tr := &http2.Transport{
					TLSClientConfig: &tls.Config{
						InsecureSkipVerify: true,
						NextProtos:         []string{http2.NextProtoTLS},
						MinVersion:         tls.VersionTLS12,
					},
				}
				client = &http.Client{
					Transport: tr,
					Timeout:   30 * time.Second,
				}
				defer tr.CloseIdleConnections()
			} else {
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
				client = &http.Client{
					Transport: tr,
					Timeout:   30 * time.Second,
				}
				defer tr.CloseIdleConnections()
			}

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
	fmt.Printf("backend=%s\n", backend)
	fmt.Printf("transport=%s\n", trans)
	fmt.Printf("cleartext=%s\n", cleartxt)
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