package main

import (
	"fmt"
	"strings"
	"testing"
	"unicode/utf8"

	"golang.org/x/text/collate"
	"golang.org/x/text/language"
	"golang.org/x/text/unicode/norm"
)

const (
	ascii50    = "The quick brown fox jumps over the lazy dog 12345!"
	ascii200   = "The quick brown fox jumps over the lazy dog. Pack my box with five dozen liquor jugs. How vexingly quick daft zebras jump! The five boxing wizards jump quickly. Crazy Frederick bought many very exquisite opal jewels. Sphinx of black quartz, judge my vow. Two driven jocks help fax my big quiz."
	bmpLatin50 = "ÀÁÂÃÄÅÆÇÈÉ" +
		"ÊËÌÍÎÏÐÑÒÓ" +
		"ÔÕÖØÙÚÛÜÝÞ" +
		"ßàáâãäåæçè" +
		"éêëìíîïðñò"
	bmpCJK50 = "一丁丂七丄丅丆万丈三" +
		"上下丌不与丏丐丑丒专" +
		"且丕世丗丘丙业丛东丝" +
		"丞丟丠両丢丣两严並丧" +
		"丨丩个丫丬中丮丯丰丱"
)

var (
	collator = collate.New(language.English)
	sink     string
	sinkInt  int
)

// N1-N10: Normalization

func BenchmarkNFC_ASCII50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFC.String(ascii50)
	}
}

func BenchmarkNFC_ASCII200(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFC.String(ascii200)
	}
}

func BenchmarkNFD_ASCII50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFD.String(ascii50)
	}
}

func BenchmarkNFC_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFC.String(bmpLatin50)
	}
}

func BenchmarkNFD_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFD.String(bmpLatin50)
	}
}

func BenchmarkNFC_BMPCJK50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFC.String(bmpCJK50)
	}
}

func BenchmarkNFD_BMPCJK50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFD.String(bmpCJK50)
	}
}

func BenchmarkNFKD_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = norm.NFKD.String(bmpLatin50)
	}
}

func BenchmarkQuickCheckNFC_ASCII200(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = boolToInt(norm.NFC.IsNormalString(ascii200))
	}
}

func BenchmarkQuickCheckNFC_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = boolToInt(norm.NFC.IsNormalString(bmpLatin50))
	}
}

// G1-G4: Segmentation (Go doesn't have built-in grapheme/word segmentation
// in the standard library, so we use rune counting as a proxy)

func BenchmarkRuneCount_ASCII200(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = utf8.RuneCountInString(ascii200)
	}
}

func BenchmarkRuneCount_BMPCJK50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = utf8.RuneCountInString(bmpCJK50)
	}
}

func BenchmarkNextRune_ASCII200(b *testing.B) {
	for i := 0; i < b.N; i++ {
		pos := 0
		for pos < len(ascii200) {
			_, size := utf8.DecodeRuneInString(ascii200[pos:])
			pos += size
		}
		sinkInt = pos
	}
}

// C1-C5: Collation

func BenchmarkCompare_ASCII50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = collator.CompareString(ascii50, ascii200)
	}
}

func BenchmarkCompare_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = collator.CompareString(bmpLatin50, bmpLatin50)
	}
}

func BenchmarkCompare_BMPCJK50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sinkInt = collator.CompareString(bmpCJK50, bmpCJK50)
	}
}

func BenchmarkSortKey_ASCII50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		var buf collate.Buffer
		key := collator.KeyFromString(&buf, ascii50)
		sinkInt = len(key)
		buf.Reset()
	}
}

func BenchmarkSortKey_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		var buf collate.Buffer
		key := collator.KeyFromString(&buf, bmpLatin50)
		sinkInt = len(key)
		buf.Reset()
	}
}

// F1-F5: Case + Utils

func BenchmarkToUpper_ASCII200(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = strings.ToUpper(ascii200)
	}
}

func BenchmarkToUpper_BMPLatin50(b *testing.B) {
	for i := 0; i < b.N; i++ {
		sink = strings.ToUpper(bmpLatin50)
	}
}

func boolToInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

func main() {
	fmt.Println("=== Go Unicode benchmark ===")
	fmt.Println("Run with: go test -bench=. -benchtime=1s")
}
