// Same-host microbench peers for nextpas test_async_bench metrics.
// Not API-equivalent; order-of-magnitude reference only.
package main

import (
	"fmt"
	"sync"
	"time"
)

func benchPostLike() float64 {
	const n = 100000
	ch := make(chan func(), n)
	start := time.Now()
	for i := 0; i < n; i++ {
		ch <- func() {}
	}
	for i := 0; i < n; i++ {
		(<-ch)()
	}
	sec := time.Since(start).Seconds()
	if sec <= 0 {
		return 0
	}
	return float64(n) / sec
}

func benchTimerScheduleLike() float64 {
	const n = 10000
	timers := make([]*time.Timer, 0, n)
	start := time.Now()
	for i := 0; i < n; i++ {
		timers = append(timers, time.NewTimer(time.Second+time.Duration(i)*time.Millisecond))
	}
	sec := time.Since(start).Seconds()
	for _, t := range timers {
		t.Stop()
	}
	if sec <= 0 {
		return 0
	}
	return float64(n) / sec
}

func benchMutex() float64 {
	const n = 100000
	var mu sync.Mutex
	start := time.Now()
	for i := 0; i < n; i++ {
		mu.Lock()
		mu.Unlock()
	}
	sec := time.Since(start).Seconds()
	if sec <= 0 {
		return 0
	}
	return float64(n) / sec
}

func benchChannel() float64 {
	const n = 100000
	ch := make(chan uint32, 1)
	start := time.Now()
	for i := 0; i < n; i++ {
		ch <- uint32(i)
		<-ch
	}
	sec := time.Since(start).Seconds()
	if sec <= 0 {
		return 0
	}
	return float64(n) / sec
}

func main() {
	fmt.Printf("metric=post_ops_per_s lang=go value=%.1f note=chan_post_drain\n", benchPostLike())
	fmt.Printf("metric=timer_schedule_ops_per_s lang=go value=%.1f note=time.NewTimer_create\n", benchTimerScheduleLike())
	fmt.Printf("metric=mutex_ops_per_s lang=go value=%.1f note=sync.Mutex\n", benchMutex())
	fmt.Printf("metric=channel_ops_per_s lang=go value=%.1f note=buffered1_send_recv\n", benchChannel())
}
