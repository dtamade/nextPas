package main

import (
	"fmt"
	"strconv"
	"strings"
	"time"

	"gopkg.in/yaml.v3"
)

func main() {
	small := `{name: Alice, age: 30, active: true, score: 3.14}`
	medium := `{users: [{id: 1, name: Alice, email: alice@example.com, age: 30}, {id: 2, name: Bob, email: bob@example.com, age: 25}, {id: 3, name: Charlie, email: charlie@example.com, age: 35}], total: 3, page: 1, hasMore: false}`

	var parts []string
	for i := 1; i <= 100; i++ {
		parts = append(parts, fmt.Sprintf("{id: %d, name: item%d, value: %d, active: true}", i, i, i*10))
	}
	large := "{items: [" + strings.Join(parts, ", ") + "], count: 100, version: 2}"

	fmt.Println("=== Go yaml.v3 benchmarks ===")
	fmt.Println()
	bench("parse small (50B)", small, 10000)
	bench("parse medium (250B)", medium, 5000)
	bench("parse large (5KB)", large, 1000)
	fmt.Println("\ndone.")
}

func bench(name, input string, iterations int) {
	var node yaml.Node
	start := time.Now()
	for i := 0; i < iterations; i++ {
		node = yaml.Node{}
		yaml.Unmarshal([]byte(input), &node)
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iterations)
	fmt.Printf("  %-45s %8.0f ns/op  (%d bytes)\n", name, nsPerOp, len(input))
	_ = strconv.Itoa(int(node.Kind))
}
