package list

import (
	"fmt"
	"testing"
)

const listN = 100000

type node struct {
	value int64
	next  *node
}

func buildList(count int) *node {
	var head, tail *node
	for i := 0; i < count; i++ {
		n := &node{value: int64(i)}
		if head == nil {
			head = n
			tail = n
		} else {
			tail.next = n
			tail = n
		}
	}
	return head
}

func traverseSum(head *node) int64 {
	var sum int64
	for n := head; n != nil; n = n.next {
		sum += n.value
	}
	return sum
}

func mergeSort(head *node) *node {
	if head == nil || head.next == nil {
		return head
	}
	slow, fast := head, head.next
	for fast != nil && fast.next != nil {
		slow = slow.next
		fast = fast.next.next
	}
	mid := slow.next
	slow.next = nil
	left := mergeSort(head)
	right := mergeSort(mid)
	var result *node
	if left.value <= right.value {
		result = left
		left = left.next
	} else {
		result = right
		right = right.next
	}
	tail := result
	for left != nil && right != nil {
		if left.value <= right.value {
			tail.next = left
			left = left.next
		} else {
			tail.next = right
			right = right.next
		}
		tail = tail.next
	}
	if left != nil {
		tail.next = left
	} else {
		tail.next = right
	}
	return result
}

func BenchmarkBuild100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		head := buildList(listN)
		_ = head
	}
}

func BenchmarkTraverse100k(b *testing.B) {
	head := buildList(listN)
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		s := traverseSum(head)
		if s < 0 {
			fmt.Println()
		}
	}
}

func BenchmarkBuildTraverse100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		head := buildList(listN)
		s := traverseSum(head)
		if s < 0 {
			fmt.Println()
		}
	}
}

func BenchmarkMergeSort100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		head := buildList(listN)
		head = mergeSort(head)
		if head.value > head.next.value {
			fmt.Println()
		}
	}
}
