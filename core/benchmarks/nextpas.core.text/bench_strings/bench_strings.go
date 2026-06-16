package benchstrings

import (
	"strings"
)

const (
	warmupIterations = 1000
	trimSampleCount  = 100
)

var (
	trimSamples    [trimSampleCount]string
	splitSample    string
	splitParts     []string
	joinParts      []string
	joinSeparator  string
	replaceSource  string
	replaceOld     string
	replaceNew     string
	containsSource string
	containsNeedle string
	prefixSource   string
	prefixNeedle   string
	suffixNeedle   string
	equalLeft      string
	equalRight     string
	upperSource    string
	lowerSource    string

	stringSink string
	boolSink   bool
	sliceSink  []string
	intSink    int
)

func init() {
	setupData()
}

func setupData() {
	for i := 0; i < trimSampleCount; i++ {
		trimSamples[i] = "  sample_" + twoDigits(i) + " alpha beta gamma delta epsilon zeta eta theta iota  "
	}

	splitSample = strings.Join([]string{
		"field_00=value_03",
		"field_01=value_10",
		"field_02=value_17",
		"field_03=value_24",
		"field_04=value_31",
		"field_05=value_38",
		"field_06=value_45",
		"field_07=value_52",
		"field_08=value_59",
		"field_09=value_66",
		"field_10=value_73",
		"field_11=value_80",
	}, ",")
	splitParts = strings.Split(splitSample, ",")

	joinParts = []string{"Alice", "Bob", "Charlie", "Delta", "Echo", "Foxtrot", "Golf", "Hotel", "India", "Juliet"}
	joinSeparator = " | "
	replaceSource = "Order status: pending, pending review, pending shipment, pending completion."
	replaceOld = "pending"
	replaceNew = "ready"
	containsSource = "The Unicode text module handles UTF-8 trimming, splitting, folding, and normalization safely."
	containsNeedle = "splitting"
	prefixSource = "nextpas.core.text.unicode.facade"
	prefixNeedle = "nextpas.core.text"
	suffixNeedle = "facade"
	equalLeft = "CAFÉ"
	equalRight = "café"
	upperSource = "Straße Ωμέγα café"
	lowerSource = "STRASSE ΩΜΕΓΑ CAFÉ"
}

func twoDigits(v int) string {
	return string(rune('0'+(v/10)%10)) + string(rune('0'+v%10))
}

func runWarmup(proc func()) {
	for i := 0; i < warmupIterations; i++ {
		proc()
	}
}

func runTextTrim() {
	for i := 0; i < trimSampleCount; i++ {
		stringSink = strings.TrimSpace(trimSamples[i])
	}
}

func runTextSplit() {
	sliceSink = strings.Split(splitSample, ",")
	intSink = len(sliceSink)
}

func runTextJoin() {
	stringSink = strings.Join(joinParts, joinSeparator)
}

func runTextReplace() {
	stringSink = strings.ReplaceAll(replaceSource, replaceOld, replaceNew)
}

func runTextContains() {
	boolSink = strings.Contains(containsSource, containsNeedle)
}

func runTextStartsWith() {
	boolSink = strings.HasPrefix(prefixSource, prefixNeedle)
}

func runTextEndsWith() {
	boolSink = strings.HasSuffix(prefixSource, suffixNeedle)
}

func runTextEqualI() {
	boolSink = strings.EqualFold(equalLeft, equalRight)
}

func runTextToUpper() {
	stringSink = strings.ToUpper(upperSource)
}

func runTextToLower() {
	stringSink = strings.ToLower(lowerSource)
}

func totalTrimBytes() int {
	total := 0
	for i := 0; i < trimSampleCount; i++ {
		total += len(trimSamples[i])
	}
	return total
}

func joinedBytes() int {
	return len(strings.Join(joinParts, joinSeparator))
}
