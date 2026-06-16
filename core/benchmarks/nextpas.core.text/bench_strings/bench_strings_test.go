package benchstrings

import (
	"strings"
	"testing"
)

func TestBenchmarkFixtures(t *testing.T) {
	if len(splitParts) == 0 {
		t.Fatal("splitParts should not be empty")
	}
	if stringsTrimCount := totalTrimBytes(); stringsTrimCount <= 0 {
		t.Fatal("trim fixtures should have positive byte count")
	}
	if strings.Join(joinParts, joinSeparator) == "" {
		t.Fatal("join fixture should not be empty")
	}
}

func BenchmarkTextTrim(b *testing.B) {
	runWarmup(runTextTrim)
	b.ResetTimer()
	b.SetBytes(int64(totalTrimBytes()))
	for i := 0; i < b.N; i++ {
		runTextTrim()
	}
}

func BenchmarkTextSplit(b *testing.B) {
	runWarmup(runTextSplit)
	b.ResetTimer()
	b.SetBytes(int64(len(splitSample)))
	for i := 0; i < b.N; i++ {
		runTextSplit()
	}
}

func BenchmarkTextJoin(b *testing.B) {
	runWarmup(runTextJoin)
	b.ResetTimer()
	b.SetBytes(int64(joinedBytes()))
	for i := 0; i < b.N; i++ {
		runTextJoin()
	}
}

func BenchmarkTextReplace(b *testing.B) {
	runWarmup(runTextReplace)
	b.ResetTimer()
	b.SetBytes(int64(len(replaceSource)))
	for i := 0; i < b.N; i++ {
		runTextReplace()
	}
}

func BenchmarkTextContains(b *testing.B) {
	runWarmup(runTextContains)
	b.ResetTimer()
	b.SetBytes(int64(len(containsSource)))
	for i := 0; i < b.N; i++ {
		runTextContains()
	}
}

func BenchmarkTextStartsWith(b *testing.B) {
	runWarmup(runTextStartsWith)
	b.ResetTimer()
	b.SetBytes(int64(len(prefixSource)))
	for i := 0; i < b.N; i++ {
		runTextStartsWith()
	}
}

func BenchmarkTextEndsWith(b *testing.B) {
	runWarmup(runTextEndsWith)
	b.ResetTimer()
	b.SetBytes(int64(len(prefixSource)))
	for i := 0; i < b.N; i++ {
		runTextEndsWith()
	}
}

func BenchmarkTextEqualI(b *testing.B) {
	runWarmup(runTextEqualI)
	b.ResetTimer()
	b.SetBytes(int64(len(equalLeft) + len(equalRight)))
	for i := 0; i < b.N; i++ {
		runTextEqualI()
	}
}

func BenchmarkTextToUpper(b *testing.B) {
	runWarmup(runTextToUpper)
	b.ResetTimer()
	b.SetBytes(int64(len(upperSource)))
	for i := 0; i < b.N; i++ {
		runTextToUpper()
	}
}

func BenchmarkTextToLower(b *testing.B) {
	runWarmup(runTextToLower)
	b.ResetTimer()
	b.SetBytes(int64(len(lowerSource)))
	for i := 0; i < b.N; i++ {
		runTextToLower()
	}
}
