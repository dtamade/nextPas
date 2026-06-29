package strops

import (
	"strings"
	"testing"
)

const stropsN = 100000
const strLen = 100

var stropsA []string
var stropsB []string

func init() {
	stropsA = make([]string, stropsN)
	stropsB = make([]string, stropsN)
	for i := 0; i < stropsN; i++ {
		sb := make([]byte, strLen)
		sb2 := make([]byte, strLen)
		for j := 0; j < strLen; j++ {
			sb[j] = byte('a' + (i+j)%26)
			sb2[j] = byte('A' + (i+j)%26)
		}
		stropsA[i] = string(sb)
		stropsB[i] = string(sb2)
	}
}

func BenchmarkSameText100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		r := false
		for i := 0; i < stropsN; i++ {
			r = strings.EqualFold(stropsA[i], stropsB[i])
		}
		_ = r
	}
}

func BenchmarkUpperCase100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < stropsN; i++ {
			s = strings.ToUpper(stropsA[i])
		}
		_ = s
	}
}

func BenchmarkLowerCase100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var s string
		for i := 0; i < stropsN; i++ {
			s = strings.ToLower(stropsB[i])
		}
		_ = s
	}
}

func BenchmarkCompareStr100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		r := 0
		for i := 0; i < stropsN; i++ {
			r = strings.Compare(stropsA[i], stropsA[i])
		}
		_ = r
	}
}
