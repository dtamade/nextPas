package tree

import (
	"fmt"
	"math/rand"
	"testing"
)

const treeN = 100000

type bstNode struct {
	key         int64
	left, right *bstNode
}

var treeKeys []int64

func init() {
	treeKeys = make([]int64, treeN)
	for i := 0; i < treeN; i++ {
		treeKeys[i] = int64(i)
	}
	rng := rand.New(rand.NewSource(12345))
	for i := treeN - 1; i > 0; i-- {
		j := int(rng.Int31n(int32(i + 1)))
		treeKeys[i], treeKeys[j] = treeKeys[j], treeKeys[i]
	}
}

func bstInsert(root *bstNode, key int64) *bstNode {
	if root == nil {
		return &bstNode{key: key}
	}
	if key < root.key {
		root.left = bstInsert(root.left, key)
	} else {
		root.right = bstInsert(root.right, key)
	}
	return root
}

func bstLookup(root *bstNode, key int64) *bstNode {
	for n := root; n != nil; {
		if key == n.key {
			return n
		} else if key < n.key {
			n = n.left
		} else {
			n = n.right
		}
	}
	return nil
}

func inOrderSum(root *bstNode) int64 {
	if root == nil {
		return 0
	}
	return inOrderSum(root.left) + root.key + inOrderSum(root.right)
}

func BenchmarkInsert100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var root *bstNode
		for i := 0; i < treeN; i++ {
			root = bstInsert(root, treeKeys[i])
		}
	}
}

func BenchmarkLookup100k(b *testing.B) {
	var root *bstNode
	for i := 0; i < treeN; i++ {
		root = bstInsert(root, treeKeys[i])
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		for i := 0; i < treeN; i++ {
			_ = bstLookup(root, treeKeys[i])
		}
	}
}

func BenchmarkInsertLookup100k(b *testing.B) {
	for n := 0; n < b.N; n++ {
		var root *bstNode
		for i := 0; i < treeN; i++ {
			root = bstInsert(root, treeKeys[i])
		}
		var sink *bstNode
		for i := 0; i < treeN; i++ {
			sink = bstLookup(root, treeKeys[i])
		}
		if sink == nil {
			fmt.Println()
		}
	}
}

func BenchmarkInOrder100k(b *testing.B) {
	var root *bstNode
	for i := 0; i < treeN; i++ {
		root = bstInsert(root, treeKeys[i])
	}
	b.ResetTimer()
	for n := 0; n < b.N; n++ {
		s := inOrderSum(root)
		if s < 0 {
			fmt.Println()
		}
	}
}
