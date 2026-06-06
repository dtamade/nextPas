package main

import (
	"context"
	"flag"
	"fmt"
	"io"
	"net"
	"net/http"
	"os"
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

func parseOptions() (int, int, string) {
	requests := flag.Int("requests", 20000, "total requests")
	threads := flag.Int("threads", 4, "concurrent keep-alive clients")
	workload := flag.String("workload", workloadNoUrl, "workload: no_url, url_path, adapter_no_url, or response_1k")
	flag.Parse()

	if *requests < 1 {
		rejectInvalidPositiveOption("--requests", *requests)
	}
	if *threads < 1 {
		rejectInvalidPositiveOption("--threads", *threads)
	}
	if *threads > *requests {
		*threads = *requests
	}
	if !isValidWorkload(*workload) {
		rejectInvalidWorkload(*workload)
	}

	return *requests, *threads, *workload
}

func requestsForThread(index, totalRequests, threads int) int {
	count := totalRequests / threads
	if index < totalRequests%threads {
		count++
	}
	return count
}

func runClient(url string, requests int, workload string, completed *int64, wg *sync.WaitGroup) {
	defer wg.Done()

	transport := &http.Transport{
		DisableCompression:    true,
		MaxIdleConns:          1,
		MaxIdleConnsPerHost:   1,
		MaxConnsPerHost:       1,
		ResponseHeaderTimeout: 10 * time.Second,
	}
	defer transport.CloseIdleConnections()

	client := &http.Client{
		Transport: transport,
		Timeout:   10 * time.Second,
	}

	for i := 0; i < requests; i++ {
		request, err := http.NewRequest(http.MethodGet, url, nil)
		if err != nil {
			return
		}
		if workload == workloadAdapterNoUrl {
			request.Header.Set("Connection", "keep-alive")
		}
		response, err := client.Do(request)
		if err != nil {
			return
		}
		_, readErr := io.Copy(io.Discard, response.Body)
		closeErr := response.Body.Close()
		if readErr != nil || closeErr != nil || response.StatusCode != http.StatusOK {
			return
		}
		atomic.AddInt64(completed, 1)
	}
}

func printResults(requests, threads int, workload string, completed int64, elapsed time.Duration) {
	elapsedNs := elapsed.Nanoseconds()
	nsPerOp := int64(0)
	reqPerSec := int64(0)

	if completed > 0 {
		nsPerOp = elapsedNs / completed
	}
	if elapsedNs > 0 {
		reqPerSec = completed * int64(time.Second) / elapsedNs
	}

	fmt.Println("operation=http.server.keepalive")
	fmt.Println("workload=" + workload)
	fmt.Println("impl=go")
	fmt.Printf("iterations=%d\n", requests)
	fmt.Printf("threads=%d\n", threads)
	fmt.Printf("completed=%d\n", completed)
	fmt.Printf("elapsed_ns=%d\n", elapsedNs)
	fmt.Printf("ns/op=%d\n", nsPerOp)
	fmt.Printf("req/s=%d\n", reqPerSec)
}

func main() {
	requests, threads, workload := parseOptions()

	listener, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}

	responseBody1K := strings.Repeat("x", 1024)

	server := &http.Server{
		Handler: http.HandlerFunc(func(writer http.ResponseWriter, request *http.Request) {
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
		}),
	}

	go func() {
		if err := server.Serve(listener); err != nil && err != http.ErrServerClosed {
			panic(err)
		}
	}()

	urlPath := "/"
	if workload == workloadUrlPath {
		urlPath = "/api/v1/users"
	}
	url := "http://" + listener.Addr().String() + urlPath
	var completed int64
	var wg sync.WaitGroup

	start := time.Now()
	for i := 0; i < threads; i++ {
		wg.Add(1)
		go runClient(url, requestsForThread(i, requests, threads), workload, &completed, &wg)
	}
	wg.Wait()
	elapsed := time.Since(start)

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	_ = server.Shutdown(ctx)
	cancel()

	printResults(requests, threads, workload, completed, elapsed)
}
