package hash

import (
	"fmt"
	"strconv"
	"testing"
)

const hashN = 100000

var hashKeys []string
var hashMissKeys []string
var lookupMap map[string]int

func init() {
	hashKeys = make([]string, hashN)
	hashMissKeys = make([]string, hashN)
	lookupMap = make(map[string]int, hashN)
	for i := 0; i < hashN; i++ {
		hashKeys[i] = "key_" + strconv.Itoa(i)
		hashMissKeys[i] = "miss_" + strconv.Itoa(i)
		lookupMap[hashKeys[i]] = i
	}
}

func BenchmarkInsert100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		m := make(map[string]int, hashN)
		for i := 0; i < hashN; i++ {
			m[hashKeys[i]] = i
		}
	}
}

func BenchmarkLookup100k(b *testing.B) {
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var sink int
		for i := 0; i < hashN; i++ {
			sink = lookupMap[hashKeys[i]]
		}
		if sink == 0 {
			fmt.Println()
		}
	}
}

func BenchmarkInsertLookup100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		m := make(map[string]int, hashN)
		for i := 0; i < hashN; i++ {
			m[hashKeys[i]] = i
		}
		var sink int
		for i := 0; i < hashN; i++ {
			sink = m[hashKeys[i]]
		}
		if sink == 0 {
			fmt.Println()
		}
	}
}

func BenchmarkLookupMiss100k(b *testing.B) {
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var sink int
		for i := 0; i < hashN; i++ {
			sink = lookupMap[hashMissKeys[i]]
		}
		if sink != 0 {
			fmt.Println()
		}
	}
}
