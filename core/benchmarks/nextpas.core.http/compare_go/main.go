// Package main is a Go HTTP/1.1 peer for nextPas bench_http_server.
// Default: cleartext keep-alive (H1 scale KPI).
// --tls: HTTPS ALPN http/1.1 self-signed (C-H1 HTTPS H1 scale KPI).
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
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

const responseBody = "Hello, World!"
const workloadNoUrl = "no_url"
const workloadUrlPath = "url_path"
const workloadAdapterNoUrl = "adapter_no_url"
const workloadResponse1K = "response_1k"
const responseBodyLen = "13"
const responseBody1KLen = "1024"
const validWorkloadsText = "no_url, url_path, adapter_no_url, or response_1k"
const clientReadMode = "http_client_body_drain"

func isValidWorkload(value string) bool {
	return value == workloadNoUrl ||
		value == workloadUrlPath ||
		value == workloadAdapterNoUrl ||
		value == workloadResponse1K
}

func rejectInvalidWorkload(value string) {
	fmt.Fprintf(os.Stderr, "invalid --workload: %s; expected one of: %s\n", value, validWorkloadsText)
	os.Exit(2)
}

func rejectInvalidPositiveOption(name string, value int) {
	fmt.Fprintf(os.Stderr, "invalid %s: %d; expected positive integer\n", name, value)
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
			Organization: []string{"nextpas-h1-bench"},
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

func parseOptions() (int, int, int, string, bool) {
	requests := flag.Int("requests", 20000, "total requests")
	threads := flag.Int("threads", 4, "concurrent keep-alive clients")
	workload := flag.String("workload", workloadNoUrl, "workload: no_url, url_path, adapter_no_url, or response_1k")
	useTLS := flag.Bool("tls", false, "HTTPS ALPN http/1.1 (self-signed); default cleartext")
	flag.Parse()

	if *requests < 1 {
		rejectInvalidPositiveOption("--requests", *requests)
	}
	if *threads < 1 {
		rejectInvalidPositiveOption("--threads", *threads)
	}
	requestedThreads := *threads
	effectiveThreads := requestedThreads
	if effectiveThreads > *requests {
		effectiveThreads = *requests
	}
	if !isValidWorkload(*workload) {
		rejectInvalidWorkload(*workload)
	}

	return *requests, requestedThreads, effectiveThreads, *workload, *useTLS
}

func requestsForThread(index, totalRequests, threads int) int {
	count := totalRequests / threads
	if index < totalRequests%threads {
		count++
	}
	return count
}

// percentileNs matches nextPas bench_http_server nearest-rank:
// index = ceil(pct/100 * N) - 1, clamped to [0, N-1].
func percentileNs(samples []int64, pct int) int64 {
	n := len(samples)
	if n <= 0 {
		return 0
	}
	if n == 1 {
		return samples[0]
	}
	idx := (pct*n+99)/100 - 1
	if idx < 0 {
		idx = 0
	}
	if idx >= n {
		idx = n - 1
	}
	return samples[idx]
}

func meanNs(samples []int64) int64 {
	if len(samples) == 0 {
		return 0
	}
	var sum int64
	for _, v := range samples {
		sum += v
	}
	return sum / int64(len(samples))
}

func runClient(url string, requests int, workload string, useTLS bool, completed *int64, samplesOut *[]int64, samplesMu *sync.Mutex, wg *sync.WaitGroup) {
	defer wg.Done()

	transport := &http.Transport{
		DisableCompression:    true,
		MaxIdleConns:          1,
		MaxIdleConnsPerHost:   1,
		MaxConnsPerHost:       1,
		ResponseHeaderTimeout: 10 * time.Second,
	}
	if useTLS {
		transport.TLSClientConfig = &tls.Config{
			InsecureSkipVerify: true,
			NextProtos:         []string{"http/1.1"},
			MinVersion:         tls.VersionTLS12,
		}
	}
	defer transport.CloseIdleConnections()

	client := &http.Client{
		Transport: transport,
		Timeout:   10 * time.Second,
	}

	local := make([]int64, 0, requests)
	for i := 0; i < requests; i++ {
		request, err := http.NewRequest(http.MethodGet, url, nil)
		if err != nil {
			return
		}
		if workload == workloadAdapterNoUrl {
			request.Header.Set("Connection", "keep-alive")
		}
		t0 := time.Now()
		response, err := client.Do(request)
		if err != nil {
			return
		}
		_, readErr := io.Copy(io.Discard, response.Body)
		closeErr := response.Body.Close()
		t1 := time.Now()
		if readErr != nil || closeErr != nil || response.StatusCode != http.StatusOK {
			return
		}
		if d := t1.Sub(t0).Nanoseconds(); d >= 0 {
			local = append(local, d)
		}
		atomic.AddInt64(completed, 1)
	}

	if len(local) > 0 {
		samplesMu.Lock()
		*samplesOut = append(*samplesOut, local...)
		samplesMu.Unlock()
	}
}

func printResults(requests, requestedThreads, effectiveThreads int, workload string, useTLS bool, completed int64, elapsed time.Duration, samples []int64) {
	elapsedNs := elapsed.Nanoseconds()
	nsPerOp := int64(0)
	reqPerSec := int64(0)
	responseBodyBytes := responseBodyLen
	transport := "cleartext-h1"
	cleartext := "true"
	if useTLS {
		transport = "tls-alpn-http1.1"
		cleartext = "false"
	}

	if workload == workloadResponse1K {
		responseBodyBytes = responseBody1KLen
	}

	if completed > 0 {
		nsPerOp = elapsedNs / completed
	}
	if elapsedNs > 0 {
		reqPerSec = completed * int64(time.Second) / elapsedNs
	}

	sort.Slice(samples, func(i, j int) bool { return samples[i] < samples[j] })
	p50 := percentileNs(samples, 50)
	p99 := percentileNs(samples, 99)
	mean := meanNs(samples)

	fmt.Println("operation=http.server.keepalive")
	fmt.Println("workload=" + workload)
	fmt.Println("impl=go")
	fmt.Println("transport=" + transport)
	fmt.Println("cleartext=" + cleartext)
	fmt.Println("client_read_mode=" + clientReadMode)
	fmt.Println("response_body_bytes=" + responseBodyBytes)
	fmt.Printf("iterations=%d\n", requests)
	fmt.Printf("requested_threads=%d\n", requestedThreads)
	fmt.Printf("effective_threads=%d\n", effectiveThreads)
	fmt.Printf("threads=%d\n", effectiveThreads)
	fmt.Printf("completed=%d\n", completed)
	fmt.Printf("elapsed_ns=%d\n", elapsedNs)
	fmt.Printf("ns/op=%d\n", nsPerOp)
	fmt.Printf("req/s=%d\n", reqPerSec)
	fmt.Printf("latency_samples=%d\n", len(samples))
	fmt.Printf("p50_ns=%d\n", p50)
	fmt.Printf("p99_ns=%d\n", p99)
	fmt.Printf("mean_ns=%d\n", mean)
}

func main() {
	requests, requestedThreads, effectiveThreads, workload, useTLS := parseOptions()

	responseBody1K := strings.Repeat("x", 1024)
	handler := http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
		if workload == workloadUrlPath && request.URL.Path != "/api/v1/users" {
			writer.WriteHeader(http.StatusNotFound)
			return
		}
		body := responseBody
		bodyLen := responseBodyLen
		if workload == workloadResponse1K {
			body = responseBody1K
			bodyLen = responseBody1KLen
		}
		writer.Header().Set("Content-Type", "text/plain")
		writer.Header().Set("Content-Length", bodyLen)
		writer.WriteHeader(http.StatusOK)
		_, _ = io.WriteString(writer, body)
	})

	urlPath := "/"
	if workload == workloadUrlPath {
		urlPath = "/api/v1/users"
	}

	var (
		url     string
		server  *http.Server
		raw     net.Listener
		err     error
	)

	if useTLS {
		cert := mustSelfSignedCert()
		tlsCfg := &tls.Config{
			Certificates: []tls.Certificate{cert},
			NextProtos:   []string{"http/1.1"},
			MinVersion:   tls.VersionTLS12,
		}
		server = &http.Server{
			Handler:   handler,
			TLSConfig: tlsCfg,
		}
		raw, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			panic(err)
		}
		ln := tls.NewListener(raw, tlsCfg)
		port := raw.Addr().(*net.TCPAddr).Port
		url = fmt.Sprintf("https://127.0.0.1:%d%s", port, urlPath)
		go func() {
			if serveErr := server.Serve(ln); serveErr != nil && serveErr != http.ErrServerClosed {
				panic(serveErr)
			}
		}()
	} else {
		server = &http.Server{Handler: handler}
		raw, err = net.Listen("tcp", "127.0.0.1:0")
		if err != nil {
			panic(err)
		}
		url = "http://" + raw.Addr().String() + urlPath
		go func() {
			if serveErr := server.Serve(raw); serveErr != nil && serveErr != http.ErrServerClosed {
				panic(serveErr)
			}
		}()
	}

	var completed int64
	var samples []int64
	var samplesMu sync.Mutex
	var wg sync.WaitGroup

	start := time.Now()
	for i := 0; i < effectiveThreads; i++ {
		wg.Add(1)
		go runClient(url, requestsForThread(i, requests, effectiveThreads), workload, useTLS, &completed, &samples, &samplesMu, &wg)
	}
	wg.Wait()
	elapsed := time.Since(start)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	_ = server.Shutdown(ctx)
	cancel()

	printResults(requests, requestedThreads, effectiveThreads, workload, useTLS, completed, elapsed, samples)
}