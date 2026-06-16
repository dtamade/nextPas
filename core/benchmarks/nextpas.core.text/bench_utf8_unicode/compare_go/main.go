package main

import (
	"fmt"
	"strings"
	"time"
	"unicode"
	"unicode/utf8"

	"golang.org/x/text/cases"
	"golang.org/x/text/language"
	"golang.org/x/text/unicode/norm"
)

const iterations = 50000

var (
	asciiText           = "Hello, UTF-8 world! 12345 ABC xyz ~/[]{}()"
	cjkText             = "你好世界，欢迎使用单元测试"
	emojiText           = "👋🌍✨🚀👩‍💻😀"
	mixedText           = "Straße 你好世界，欢迎使用单元测试 👋🌍✨🚀👩‍💻😀 Café"
	canonicalComposed   = "\u00c5"
	canonicalDecomposed = "A\u030a"
	caseFoldLeft        = "Straße"
	caseFoldRight       = "STRASSE"

	boolSink   bool
	intSink    int
	runeSink   rune
	byteSink   int
	stringSink string
)

func measure(name string, fn func()) {
	start := time.Now()
	fn()
	totalNs := time.Since(start).Nanoseconds()
	nsPerOp := float64(totalNs) / float64(iterations)
	fmt.Printf("%s | %d | %d | %.2f\n", name, iterations, totalNs, nsPerOp)
}

func main() {
	upperCaser := cases.Upper(language.Und)
	lowerCaser := cases.Lower(language.Und)

	fmt.Println("操作名 | 迭代次数 | 总耗时(ns) | 单次(ns/op)")
	fmt.Println("--- | ---: | ---: | ---:")

	measure("UTF8IsValid", func() {
		for i := 0; i < iterations; i++ {
			boolSink = utf8.ValidString(asciiText)
			boolSink = utf8.ValidString(cjkText) && boolSink
			boolSink = utf8.ValidString(emojiText) && boolSink
		}
	})

	measure("UTF8CodePointCount", func() {
		for i := 0; i < iterations; i++ {
			intSink = utf8.RuneCountInString(mixedText)
		}
	})

	measure("UTF8Decode + UTF8Encode", func() {
		var buf [utf8.UTFMax]byte
		for i := 0; i < iterations; i++ {
			for _, r := range mixedText {
				runeSink = r
				byteSink = utf8.EncodeRune(buf[:], r)
			}
		}
	})

	measure("TUTF8Iterator", func() {
		for i := 0; i < iterations; i++ {
			for _, r := range mixedText {
				runeSink = r
			}
		}
	})

	measure("UTF8ToUpper / UTF8ToLower", func() {
		for i := 0; i < iterations; i++ {
			stringSink = upperCaser.String(mixedText)
			stringSink = lowerCaser.String(stringSink)
		}
	})

	measure("NFD", func() {
		for i := 0; i < iterations; i++ {
			stringSink = norm.NFD.String(mixedText)
		}
	})

	measure("NFC", func() {
		for i := 0; i < iterations; i++ {
			stringSink = norm.NFC.String(mixedText)
		}
	})

	measure("UTF8CaseFold", func() {
		for i := 0; i < iterations; i++ {
			stringSink = strings.Map(unicode.SimpleFold, mixedText)
		}
	})

	measure("TextEqualCanonical", func() {
		for i := 0; i < iterations; i++ {
			boolSink = norm.NFC.String(canonicalComposed) == norm.NFC.String(canonicalDecomposed)
		}
	})

	measure("TextEqualCaseFold", func() {
		for i := 0; i < iterations; i++ {
			boolSink = norm.NFD.String(strings.ToLower(caseFoldLeft)) == norm.NFD.String(strings.ToLower(caseFoldRight))
		}
	})

	if boolSink && intSink == 0 && runeSink == 0 && byteSink == 0 && stringSink == "" {
		fmt.Println()
	}
}
