// Localhost sequential Dial peer for nextpas dial_ops_per_s.
// truth=same-host-order-of-magnitude; not Happy Eyeballs dual-stack race.
package main

import (
	"fmt"
	"net"
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
	const n = 200
	start := time.Now()
	ok := 0
	for i := 0; i < n; i++ {
		c, err := net.DialTimeout("tcp", addr, 2*time.Second)
		if err == nil {
			ok++
			c.Close()
		}
	}
	sec := time.Since(start).Seconds()
	if sec <= 0 {
		sec = 1e-9
	}
	fmt.Printf("metric=dial_ops_per_s lang=go value=%.1f note=net.DialTimeout_localhost ok=%d/%d\n",
		float64(ok)/sec, ok, n)
}
