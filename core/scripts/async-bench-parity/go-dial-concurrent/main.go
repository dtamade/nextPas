// Concurrent localhost Dial peer for dial_concurrent_ops_per_s.
package main

import (
	"fmt"
	"net"
	"sync"
	"sync/atomic"
	"time"
)

func main() {
	ln, err := net.Listen("tcp", "127.0.0.1:0")
	if err != nil {
		panic(err)
	}
	defer ln.Close()
	go func() {
		for {
			c, err := ln.Accept()
			if err != nil {
				return
			}
			c.Close()
		}
	}()

	addr := ln.Addr().String()
	const n = 400
	const w = 16
	var ok atomic.Int64
	sem := make(chan struct{}, w)
	var wg sync.WaitGroup
	start := time.Now()
	for i := 0; i < n; i++ {
		wg.Add(1)
		sem <- struct{}{}
		go func() {
			defer wg.Done()
			defer func() { <-sem }()
			c, err := net.DialTimeout("tcp", addr, 2*time.Second)
			if err == nil {
				ok.Add(1)
				c.Close()
			}
		}()
	}
	wg.Wait()
	sec := time.Since(start).Seconds()
	if sec <= 0 {
		sec = 1e-9
	}
	v := float64(ok.Load()) / sec
	fmt.Printf("metric=dial_concurrent_ops_per_s lang=go value=%.1f note=inflight=%d ok=%d/%d\n",
		v, w, ok.Load(), n)
}
