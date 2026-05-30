package main

import (
	"fmt"
	"strings"
	"time"

	"github.com/BurntSushi/toml"
)

const smallTOML = `name = "my-app"
version = "1.0.0"
description = "A sample application"
license = "MIT"
authors = ["Alice", "Bob"]
debug = false
port = 8080
timeout = 30.5
created = 2024-01-15T10:30:00Z
tags = ["web", "api", "fast"]
`

func buildMediumTOML() string {
	var sb strings.Builder
	sb.WriteString(`[package]
name = "nextpas"
version = "0.1.0"
edition = "2024"

[dependencies]
http = "2.0.0"
json = "1.5.0"
toml = "0.8.0"
crypto = "0.4.0"

[server]
host = "0.0.0.0"
port = 443
workers = 4
max_connections = 10000
timeout_ms = 30000
tls = true

[database]
url = "postgres://localhost:5432/mydb"
pool_size = 20
idle_timeout = 300
ssl_mode = "require"

[logging]
level = "info"
format = "json"
output = "stdout"

`)
	for i := 1; i <= 20; i++ {
		fmt.Fprintf(&sb, "[[features]]\nname = \"feature-%d\"\nenabled = true\npriority = %d\n\n", i, i)
	}
	return sb.String()
}

func buildLargeTOML() string {
	var sb strings.Builder
	for i := 1; i <= 100; i++ {
		fmt.Fprintf(&sb, "[section_%d]\nkey_a = \"value_%d_a\"\nkey_b = %d\nkey_c = %d.5\nkey_d = true\nkey_e = [1, 2, 3, 4, 5]\nkey_f = {x = %d, y = %d}\n\n",
			i, i, i*100, i, i, i*2)
	}
	return sb.String()
}

func bench(name string, input string, iters int) {
	start := time.Now()
	for i := 0; i < iters; i++ {
		var v interface{}
		toml.Decode(input, &v)
	}
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	mbPerSec := float64(len(input)) / nsPerOp * 1000.0
	fmt.Printf("  %-40s %8d iters %10.1f ns/op %8.1f MB/s\n", name, iters, nsPerOp, mbPerSec)
}

func main() {
	medium := buildMediumTOML()
	large := buildLargeTOML()

	fmt.Println("=== Go BurntSushi/toml benchmark ===")
	fmt.Printf("Small TOML:  %5d bytes\n", len(smallTOML))
	fmt.Printf("Medium TOML: %5d bytes\n", len(medium))
	fmt.Printf("Large TOML:  %5d bytes\n\n", len(large))

	bench("parse/small (10 keys)", smallTOML, 100000)
	bench("parse/medium (~50 keys)", medium, 20000)
	bench("parse/large (~700 keys)", large, 2000)
}
