// bench_arena.go — Go 综合竞技场基准
//
// 五个赛道：HashMap / Sort / String / JSON / Pool
// 输出 benchstat 兼容格式
package main

import (
	"encoding/json"
	"fmt"
	"math/rand"
	"sort"
	"strconv"
	"strings"
	"sync"
	"testing"
)

const (
	HASHMAP_N     = 100000
	HASHMAP_ITERS = 100
	SORT_N        = 1000
	SORT_ITERS    = 100
	STRING_N      = 10000
	STRING_ITERS  = 100
	JSON_N        = 1000
	JSON_ITERS    = 100
)

// === 赛道 1: HashMap ===

func BenchmarkHashMap_Insert(b *testing.B) {
	keys := make([]int, HASHMAP_N)
	for i := range keys {
		keys[i] = (i * 2654435761) & 0x7FFFFFFF
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		m := make(map[int]int, HASHMAP_N)
		for j := 0; j < HASHMAP_N; j++ {
			m[keys[j]] = j
		}
	}
}

func BenchmarkHashMap_Lookup(b *testing.B) {
	keys := make([]int, HASHMAP_N)
	m := make(map[int]int, HASHMAP_N)
	for i := range keys {
		keys[i] = (i * 2654435761) & 0x7FFFFFFF
		m[keys[i]] = i
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		found := 0
		for j := 0; j < HASHMAP_N; j++ {
			if _, ok := m[keys[j]]; ok {
				found++
			}
		}
	}
}

func BenchmarkHashMap_Iterate(b *testing.B) {
	m := make(map[int]int, HASHMAP_N)
	for i := 0; i < HASHMAP_N; i++ {
		m[(i*2654435761)&0x7FFFFFFF] = i
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		count := 0
		for range m {
			count++
		}
	}
}

// === 赛道 2: Sort ===

func BenchmarkSort_Int32(b *testing.B) {
	data := make([]int, SORT_N)
	for i := range data {
		data[i] = (i * 48271) % 1000000
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		d := make([]int, SORT_N)
		copy(d, data)
		sort.Ints(d)
	}
}

// === 赛道 3: String ===

func BenchmarkString_Builder(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var sb strings.Builder
		sb.Grow(STRING_N * 16)
		for i := 0; i < STRING_N; i++ {
			sb.WriteString("item_")
			sb.WriteString(strconv.Itoa(i))
			sb.WriteByte(',')
		}
		_ = sb.String()
	}
}

func BenchmarkString_Concat(b *testing.B) {
	for n := 0; n < b.N; n++ {
		result := ""
		for i := 0; i < STRING_N; i++ {
			result = result + "item_" + strconv.Itoa(i) + ","
		}
	}
}

// === 赛道 4: JSON ===

type User struct {
	ID    int    `json:"id"`
	Name  string `json:"name"`
	Email string `json:"email"`
	Age   int    `json:"age"`
}

type Users struct {
	Users []User `json:"users"`
}

func BenchmarkJSON_Parse(b *testing.B) {
	users := Users{Users: make([]User, JSON_N)}
	for i := 0; i < JSON_N; i++ {
		users.Users[i] = User{
			ID:    i,
			Name:  "user_" + strconv.Itoa(i),
			Email: "user" + strconv.Itoa(i) + "@example.com",
			Age:   20 + (i % 50),
		}
	}
	data, _ := json.Marshal(users)

	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var u Users
		json.Unmarshal(data, &u)
	}
}

// === 赛道 5: Pool (sync.Pool) ===

type PoolItem struct {
	Value int
}

func BenchmarkPool_SingleThread(b *testing.B) {
	pool := sync.Pool{
		New: func() any { return &PoolItem{} },
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for i := 0; i < 10000; i++ {
			item := pool.Get().(*PoolItem)
			item.Value = i
			pool.Put(item)
		}
	}
}

func BenchmarkPool_Concurrent_8(b *testing.B) {
	pool := sync.Pool{
		New: func() any { return &PoolItem{} },
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		var wg sync.WaitGroup
		for t := 0; t < 8; t++ {
			wg.Add(1)
			go func() {
				defer wg.Done()
				for i := 0; i < 100000; i++ {
					item := pool.Get().(*PoolItem)
					item.Value = i
					pool.Put(item)
				}
			}()
		}
		wg.Wait()
	}
}

func main() {
	fmt.Println("=== Go Arena Benchmark ===")
	fmt.Println("Run with: go test -bench=. -benchmem -count=6 | tee go_arena.txt")
	fmt.Println("Then: benchstat go_arena.txt")
}
