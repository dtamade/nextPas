package main

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"strconv"
	"strings"
	"time"
)

type Config struct {
	Services []Service `xml:"service"`
}

type Service struct {
	Name    string `xml:"name,attr"`
	Enabled string `xml:"enabled,attr"`
	Host    string `xml:"host"`
	Port    int    `xml:"port"`
	Timeout int    `xml:"timeout"`
	Path    string `xml:"path"`
}

type Dataset struct {
	Rows []Row `xml:"row"`
}

type Row struct {
	ID      string `xml:"id,attr"`
	Type    string `xml:"type,attr"`
	Name    string `xml:"name"`
	Value   int    `xml:"value"`
	Flag    int    `xml:"flag"`
	Message string `xml:"message"`
}

var (
	configXML string
	dataXML   string
	sink      uint64
)

func buildConfigXML(targetBytes int) string {
	var b strings.Builder
	b.Grow(targetBytes + 512)
	b.WriteString("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<config>\n")
	for i := 0; b.Len() < targetBytes-16; i++ {
		b.WriteString("  <service name=\"service")
		b.WriteString(strconv.Itoa(i))
		b.WriteString("\" enabled=\"true\">\n")
		b.WriteString("    <host>127.0.0.1</host>\n")
		b.WriteString("    <port>")
		b.WriteString(strconv.Itoa(8000 + i%1000))
		b.WriteString("</port>\n")
		b.WriteString("    <timeout>30</timeout>\n")
		b.WriteString("    <path>/var/lib/nextpas/service")
		b.WriteString(strconv.Itoa(i))
		b.WriteString("</path>\n")
		b.WriteString("  </service>\n")
	}
	b.WriteString("</config>\n")
	return b.String()
}

func buildDataXML(targetBytes int) string {
	var b strings.Builder
	b.Grow(targetBytes + 512)
	b.WriteString("<?xml version=\"1.0\" encoding=\"utf-8\"?>\n<dataset>\n")
	for i := 0; b.Len() < targetBytes-18; i++ {
		b.WriteString("  <row id=\"")
		b.WriteString(strconv.Itoa(i))
		b.WriteString("\" type=\"event\">\n")
		b.WriteString("    <name>item_")
		b.WriteString(strconv.Itoa(i))
		b.WriteString("</name>\n")
		b.WriteString("    <value>")
		b.WriteString(strconv.Itoa(i * 17))
		b.WriteString("</value>\n")
		b.WriteString("    <flag>")
		b.WriteString(strconv.Itoa(i % 2))
		b.WriteString("</flag>\n")
		b.WriteString("    <message>payload for item ")
		b.WriteString(strconv.Itoa(i))
		b.WriteString(" with stable benchmark text</message>\n")
		b.WriteString("  </row>\n")
	}
	b.WriteString("</dataset>\n")
	return b.String()
}

func tokenize(input string, iters int) {
	for i := 0; i < iters; i++ {
		decoder := xml.NewDecoder(bytes.NewBufferString(input))
		count := uint64(0)
		for {
			_, err := decoder.Token()
			if err == io.EOF {
				break
			}
			if err != nil {
				panic(err)
			}
			count++
		}
		sink ^= count
	}
}

func parseConfig(iters int) {
	for i := 0; i < iters; i++ {
		var cfg Config
		if err := xml.Unmarshal([]byte(configXML), &cfg); err != nil {
			panic(err)
		}
		sink ^= uint64(len(cfg.Services))
		if len(cfg.Services) > 0 {
			sink ^= uint64(len(cfg.Services[0].Name))
		}
	}
}

func parseData(iters int) {
	for i := 0; i < iters; i++ {
		var data Dataset
		if err := xml.Unmarshal([]byte(dataXML), &data); err != nil {
			panic(err)
		}
		sink ^= uint64(len(data.Rows))
		if len(data.Rows) > 0 {
			sink ^= uint64(len(data.Rows[len(data.Rows)-1].ID))
		}
	}
}

func printHeader() {
	fmt.Printf("  %-32s %10s %14s %16s\n", "operation", "iterations", "total", "ns/op")
}

func runBench(name string, iters int, fn func(int)) {
	fn(2)
	start := time.Now()
	fn(iters)
	elapsed := time.Since(start)
	nsPerOp := float64(elapsed.Nanoseconds()) / float64(iters)
	fmt.Printf("  %-32s %10d %12.3f ms %12.1f ns/op\n",
		name, iters, float64(elapsed.Nanoseconds())/1_000_000.0, nsPerOp)
}

func main() {
	configXML = buildConfigXML(10 * 1024)
	dataXML = buildDataXML(100 * 1024)

	fmt.Println("=== Go encoding/xml benchmark ===")
	fmt.Println("  config XML bytes:", len(configXML))
	fmt.Println("  data XML bytes:  ", len(dataXML))
	printHeader()
	runBench("go xml tokenize 10KB config", 300, func(iters int) { tokenize(configXML, iters) })
	runBench("go xml tokenize 100KB data", 50, func(iters int) { tokenize(dataXML, iters) })
	runBench("go xml unmarshal 10KB config", 100, parseConfig)
	runBench("go xml unmarshal 100KB data", 20, parseData)
	fmt.Println("  sink=", sink)
}
