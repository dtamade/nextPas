package main

import (
	"fmt"
	"strconv"
	"time"
)

const (
	warmupIterations  = 1000
	measureIterations = 100000

	intValue       int64   = -1234567890123456789
	uintValue      uint64  = 18446744073709551615
	hexValue       uint64  = 0xDEADBEEFCAFEBABE
	floatValue     float64 = 1234567.89012345
	parseIntText           = "-1234567890123456789"
	parseFloatText         = "1234567.89012345"
	formatTextValue        = "benchmark"
)

type benchCase struct {
	name       string
	iterations int64
	totalNs    int64
	nsPerOp    float64
}

var (
	sinkString string
	sinkInt    int64
	sinkFloat  float64
	sinkBool   bool
	sinkBuffer = make([]byte, 0, 64)
)

func printHeader() {
	fmt.Println("操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op)")
	fmt.Println("--- | ---: | ---: | ---:")
}

func printCase(c benchCase) {
	fmt.Printf("%s | %d | %d | %.2f\n",
		c.name, c.iterations, c.totalNs, c.nsPerOp)
}

func runCase(name string, fn func()) {
	for i := 0; i < warmupIterations; i++ {
		fn()
	}

	start := time.Now()
	for i := 0; i < measureIterations; i++ {
		fn()
	}
	totalNs := time.Since(start).Nanoseconds()

	printCase(benchCase{
		name:       name,
		iterations: measureIterations,
		totalNs:    totalNs,
		nsPerOp:    float64(totalNs) / float64(measureIterations),
	})
}

func benchIntToStr() {
	sinkString = strconv.FormatInt(intValue, 10)
}

func benchUIntToStr() {
	sinkString = strconv.FormatUint(uintValue, 10)
}

func benchIntToHex() {
	sinkString = strconv.FormatUint(hexValue, 16)
}

func benchStrToInt() {
	sinkInt, _ = strconv.ParseInt(parseIntText, 10, 64)
}

func benchFloatToStr() {
	sinkString = strconv.FormatFloat(floatValue, 'f', -1, 64)
}

func benchTryStrToFloat() {
	sinkFloat, _ = strconv.ParseFloat(parseFloatText, 64)
	sinkBool = true
}

func benchTextFormat() {
	sinkString = fmt.Sprintf("%d %s %f", intValue, formatTextValue, floatValue)
}

func benchParseDouble() {
	sinkFloat, _ = strconv.ParseFloat(parseFloatText, 64)
}

func benchFloatToBuffer() {
	sinkBuffer = strconv.AppendFloat(sinkBuffer[:0], floatValue, 'g', -1, 64)
	if len(sinkBuffer) > 0 {
		sinkInt = int64(sinkBuffer[len(sinkBuffer)-1])
	}
}

func main() {
	fmt.Println("=== Go strconv number format/parse benchmark ===")
	printHeader()
	runCase("IntToStr", benchIntToStr)
	runCase("UIntToStr", benchUIntToStr)
	runCase("IntToHex", benchIntToHex)
	runCase("StrToInt", benchStrToInt)
	runCase("FloatToStr", benchFloatToStr)
	runCase("TryStrToFloat", benchTryStrToFloat)
	runCase("TextFormat", benchTextFormat)
	runCase("ParseDouble", benchParseDouble)
	runCase("FloatToBuffer", benchFloatToBuffer)
	_ = sinkBool
}
