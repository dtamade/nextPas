package main

import (
	"encoding/json"
	"fmt"
	"strconv"
	"time"
)

const smallJSON = `{"name":"Alice","age":30,"active":true,"score":3.14}`
const mediumJSON = `{"users":[{"id":1,"name":"Alice","email":"alice@example.com","age":30},{"id":2,"name":"Bob","email":"bob@example.com","age":25},{"id":3,"name":"Charlie","email":"charlie@example.com","age":35}],"total":3,"page":1,"hasMore":false}`

func buildLargeJSON() string {
	s := `{"items":[`
	for i := 0; i < 100; i++ {
		if i > 0 {
			s += ","
		}
		s += `{"id":` + strconv.Itoa(i) + `,"name":"item_` + strconv.Itoa(i) + `","value":` + fmt.Sprintf("%.1f", float64(i)*1.5) + `,"active":` + strconv.FormatBool(i%2 == 0) + `}`
	}
	s += `],"count":100}`
	return s
}

func bench(name string, input []byte, iterations int) {
	start := time.Now()
	for i := 0; i < iterations; i++ {
		var v interface{}
		json.Unmarshal(input, &v)
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iterations)
	fmt.Printf("  %-45s %8.0f ns/op  (%d bytes)\n", name, nsPerOp, len(input))
}

func benchStringify(name string, input []byte, iterations int) {
	var v interface{}
	json.Unmarshal(input, &v)
	start := time.Now()
	for i := 0; i < iterations; i++ {
		json.Marshal(v)
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iterations)
	fmt.Printf("  %-45s %8.0f ns/op\n", name, nsPerOp)
}

func main() {
	large := buildLargeJSON()

	fmt.Println("=== Go encoding/json benchmarks ===")
	fmt.Println()
	fmt.Println("--- Parse ---")
	bench("parse small (52B)", []byte(smallJSON), 50000)
	bench("parse medium (250B)", []byte(mediumJSON), 20000)
	bench("parse large (5KB)", []byte(large), 5000)
	fmt.Println()
	fmt.Println("--- Stringify ---")
	benchStringify("stringify medium", []byte(mediumJSON), 20000)
	benchStringify("stringify large", []byte(large), 5000)
	fmt.Println()
	fmt.Println("done.")
}
