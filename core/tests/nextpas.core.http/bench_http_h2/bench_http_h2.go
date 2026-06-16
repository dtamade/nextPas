package main

import (
	"fmt"
	"time"

	"golang.org/x/net/http2/hpack"
)

// Simple flow state to match nextPas TH2FlowState
type flowState struct {
	initialWindowSize uint32
	availableWindow   int64
	reservedBytes     uint32
	inFlightBytes     uint32
}

func (f *flowState) init(w uint32) {
	f.initialWindowSize = w
	f.availableWindow = int64(w)
	f.reservedBytes = 0
	f.inFlightBytes = 0
}

func (f *flowState) tryReserve(b uint32) bool {
	if b == 0 {
		return true
	}
	if int64(b) > f.availableWindow {
		return false
	}
	f.availableWindow -= int64(b)
	f.reservedBytes += b
	return true
}

func (f *flowState) commitSend(b uint32) {
	if b == 0 {
		return
	}
	if b > f.reservedBytes {
		panic("commit exceeds reserved")
	}
	f.reservedBytes -= b
	f.inFlightBytes += b
}

func (f *flowState) onWindowUpdate(inc uint32) {
	f.availableWindow += int64(inc)
}

func (f *flowState) onDataReceived(b uint32) {
	f.availableWindow -= int64(b)
	f.inFlightBytes += b
}

func (f *flowState) onDataConsumed(b uint32) {
	f.inFlightBytes -= b
	f.availableWindow += int64(b)
}

func benchHPACKEncode() {
	const iterations = 50000
	headers := []hpack.HeaderField{
		{Name: ":method", Value: "POST"},
		{Name: ":path", Value: "/api/v1/users"},
		{Name: ":authority", Value: "example.com"},
		{Name: "content-type", Value: "application/json"},
		{Name: "content-length", Value: "42"},
	}

	var encoder *hpack.Encoder
	var buf []byte
	start := time.Now()
	for i := 0; i < iterations; i++ {
		buf = buf[:0]
		encoder = hpack.NewEncoder(&byteBuffer{buf: buf[:0]})
		for _, h := range headers {
			encoder.WriteField(h)
		}
	}
	elapsed := time.Since(start)
	avgNs := elapsed.Nanoseconds() / int64(iterations)
	fmt.Println("--- HPACK Encode ---")
	fmt.Println("Iterations:", iterations)
	fmt.Println("Total time:", elapsed.Microseconds(), "us")
	fmt.Println("Avg:", avgNs, "ns/op")
	fmt.Println("Ops/sec:", int64(iterations)*1e9/elapsed.Nanoseconds())
}

func benchHPACKDecode() {
	const iterations = 50000
	headers := []hpack.HeaderField{
		{Name: ":method", Value: "POST"},
		{Name: ":path", Value: "/api/v1/users"},
		{Name: ":authority", Value: "example.com"},
		{Name: "content-type", Value: "application/json"},
		{Name: "content-length", Value: "42"},
	}

	// Encode once to get the block
	buf := &byteBuffer{buf: make([]byte, 0, 4096)}
	enc := hpack.NewEncoder(buf)
	for _, h := range headers {
		enc.WriteField(h)
	}
	block := buf.Bytes()

	start := time.Now()
	dec := hpack.NewDecoder(4096, nil)
	for i := 0; i < iterations; i++ {
		hfs, err := dec.DecodeFull(block)
		if err != nil {
			panic(err)
		}
		_ = hfs
	}
	elapsed := time.Since(start)
	avgNs := elapsed.Nanoseconds() / int64(iterations)
	fmt.Println("--- HPACK Decode ---")
	fmt.Println("Iterations:", iterations)
	fmt.Println("Total time:", elapsed.Microseconds(), "us")
	fmt.Println("Avg:", avgNs, "ns/op")
	fmt.Println("Ops/sec:", int64(iterations)*1e9/elapsed.Nanoseconds())
}

func benchFrameEncode() {
	const iterations = 100000
	payload := make([]byte, 128)
	for i := 0; i < len(payload); i++ {
		payload[i] = byte(i)
	}

	frame := make([]byte, 9+128)
	start := time.Now()
	for i := 0; i < iterations; i++ {
		// Encode 9-byte header + payload (DATA frame, stream 1)
		frame[0] = 0
		frame[1] = 0
		frame[2] = 128 // payload length = 128
		frame[3] = 0   // DATA frame type
		frame[4] = 0   // flags
		frame[5] = 0
		frame[6] = 0
		frame[7] = 0
		frame[8] = 1 // stream ID = 1
		copy(frame[9:], payload)
	}
	elapsed := time.Since(start)
	avgNs := elapsed.Nanoseconds() / int64(iterations)
	if avgNs < 1 {
		avgNs = 1
	}
	fmt.Println("--- Frame Encode ---")
	fmt.Println("Iterations:", iterations)
	fmt.Println("Frame size: 128+9 bytes")
	fmt.Println("Avg:", avgNs, "ns/op")
	fmt.Println("Ops/sec:", int64(iterations)*1e9/elapsed.Nanoseconds())
}

func benchFrameDecode() {
	const iterations = 100000
	payload := make([]byte, 128)
	for i := 0; i < len(payload); i++ {
		payload[i] = byte(i)
	}

	frame := make([]byte, 9+128)
	frame[0] = 0
	frame[1] = 0
	frame[2] = 128
	frame[3] = 0
	frame[4] = 0
	frame[5] = 0
	frame[6] = 0
	frame[7] = 0
	frame[8] = 1
	copy(frame[9:], payload)

	var streamID uint32
	var frameType byte
	var flags byte
	var framePayload []byte

	start := time.Now()
	for i := 0; i < iterations; i++ {
		// Decode frame header
		_ = uint32(frame[0])<<16 | uint32(frame[1])<<8 | uint32(frame[2])
		frameType = frame[3]
		flags = frame[4]
		streamID = (uint32(frame[5]&0x7f) << 24) | (uint32(frame[6]) << 16) | (uint32(frame[7]) << 8) | uint32(frame[8])
		framePayload = frame[9 : 9+128]
	}
	_ = streamID
	_ = frameType
	_ = flags
	_ = framePayload

	elapsed := time.Since(start)
	avgNs := elapsed.Nanoseconds() / int64(iterations)
	if avgNs < 1 {
		avgNs = 1
	}
	fmt.Println("--- Frame Decode ---")
	fmt.Println("Iterations:", iterations)
	fmt.Println("Frame size: 128+9 bytes")
	fmt.Println("Avg:", avgNs, "ns/op")
	fmt.Println("Ops/sec:", int64(iterations)*1e9/elapsed.Nanoseconds())
}

func benchFlowControl() {
	const iterations = 100000
	var f flowState
	f.init(65535)

	start := time.Now()
	for i := 0; i < iterations; i++ {
		f.tryReserve(256)
		f.commitSend(256)
		f.onWindowUpdate(256)
		f.onDataReceived(256)
		f.onDataConsumed(256)
	}
	elapsed := time.Since(start)
	totalOps := iterations * 5
	avgNs := elapsed.Nanoseconds() / int64(totalOps)
	if avgNs < 1 {
		avgNs = 1
	}
	fmt.Println("--- Flow Control (5 ops/iteration) ---")
	fmt.Println("Iterations:", iterations)
	fmt.Println("Total flow ops:", totalOps)
	fmt.Println("Avg per single op:", avgNs, "ns")
	fmt.Println("Flow ops/sec:", int64(totalOps)*1e9/elapsed.Nanoseconds())
}

// byteBuffer implements io.Writer for hpack.Encoder
type byteBuffer struct {
	buf []byte
}

func (b *byteBuffer) Write(p []byte) (n int, err error) {
	b.buf = append(b.buf, p...)
	return len(p), nil
}

func (b *byteBuffer) Bytes() []byte { return b.buf }

func main() {
	fmt.Println("=== Go H2 Benchmarks ===")
	fmt.Println()

	benchHPACKEncode()
	benchHPACKDecode()
	benchFrameEncode()
	benchFrameDecode()
	benchFlowControl()

	fmt.Println()
	fmt.Println("All benchmarks completed.")
}
