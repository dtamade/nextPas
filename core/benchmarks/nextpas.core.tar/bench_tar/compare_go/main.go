package main

import (
	"archive/tar"
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"runtime"
	"time"
)

const (
	fileCount = 200
	fileSize  = 512
	bigSize   = 1024 * 1024
	benchIters = 25
)

var (
	gFiles [][]byte
	gBlob  []byte
	gArchive []byte
	gBigArchive []byte
)

type benchResult struct {
	Name       string  `json:"name"`
	Status     string  `json:"status"`
	Iterations int     `json:"iterations"`
	NsPerOp    float64 `json:"ns_per_op"`
	OpsPerSec  float64 `json:"ops_per_sec"`
	BytesPerOp int     `json:"bytes_per_op"`
	AllocsPerOp int    `json:"allocs_per_op"`
	Statistics map[string]interface{} `json:"statistics"`
}

type benchSuite struct {
	Version     string        `json:"version"`
	Timestamp   string        `json:"timestamp"`
	Environment map[string]interface{} `json:"environment"`
	Summary     map[string]interface{} `json:"summary"`
	Benchmarks  []benchResult `json:"benchmarks"`
}

func generateData() {
	gFiles = make([][]byte, fileCount)
	for i := 0; i < fileCount; i++ {
		b := make([]byte, fileSize)
		for j := 0; j < fileSize; j++ {
			b[j] = byte((j*7 + i) % 251)
		}
		gFiles[i] = b
	}
	gBlob = make([]byte, bigSize)
	for i := 0; i < bigSize; i++ {
		gBlob[i] = byte((i*7 + i/256) % 251)
	}
}

func entryName(idx int) string {
	return fmt.Sprintf("f/%04d.bin", idx)
}

func buildManyArchive200() []byte {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for i := 0; i < fileCount && i < 200; i++ {
		hdr := &tar.Header{
			Name: entryName(i),
			Mode: 0644,
			Size: int64(len(gFiles[i])),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			panic(err)
		}
		if _, err := tw.Write(gFiles[i]); err != nil {
			panic(err)
		}
	}
	if err := tw.Close(); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func buildManyArchiveAll() []byte {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for i := 0; i < fileCount; i++ {
		hdr := &tar.Header{
			Name: entryName(i),
			Mode: 0644,
			Size: int64(len(gFiles[i])),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			panic(err)
		}
		if _, err := tw.Write(gFiles[i]); err != nil {
			panic(err)
		}
	}
	if err := tw.Close(); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func buildBigArchive() []byte {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	hdr := &tar.Header{
		Name: "big.bin",
		Mode: 0644,
		Size: int64(len(gBlob)),
	}
	if err := tw.WriteHeader(hdr); err != nil {
		panic(err)
	}
	if _, err := tw.Write(gBlob); err != nil {
		panic(err)
	}
	if err := tw.Close(); err != nil {
		panic(err)
	}
	return buf.Bytes()
}

func benchPackMany() {
	_ = buildManyArchive200()
}

func benchBuilderPack() {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	for i := 0; i < 200; i++ {
		hdr := &tar.Header{
			Name: entryName(i),
			Mode: 0644,
			Size: int64(len(gFiles[i])),
		}
		if err := tw.WriteHeader(hdr); err != nil {
			panic(err)
		}
		if _, err := tw.Write(gFiles[i]); err != nil {
			panic(err)
		}
	}
	if err := tw.Close(); err != nil {
		panic(err)
	}
	_ = buf.Bytes()
}

func benchOpenParse() {
	tr := tar.NewReader(bytes.NewReader(gArchive))
	for {
		_, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}
	}
}

func benchExtractAll() {
	tr := tar.NewReader(bytes.NewReader(gArchive))
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}
		n, err := io.CopyN(io.Discard, tr, hdr.Size)
		if err != nil && err != io.EOF {
			panic(err)
		}
		_ = n
	}
}

func benchExtractSlice() {
	tr := tar.NewReader(bytes.NewReader(gArchive))
	for {
		hdr, err := tr.Next()
		if err == io.EOF {
			break
		}
		if err != nil {
			panic(err)
		}
		// zero-copy view simulation: read header then discard
		_ = hdr.Name
		_, _ = io.CopyN(io.Discard, tr, hdr.Size)
	}
}

func benchWrite1M() {
	var buf bytes.Buffer
	tw := tar.NewWriter(&buf)
	hdr := &tar.Header{Name: "big.bin", Mode: 0644, Size: int64(len(gBlob))}
	if err := tw.WriteHeader(hdr); err != nil {
		panic(err)
	}
	if _, err := tw.Write(gBlob); err != nil {
		panic(err)
	}
	if err := tw.Close(); err != nil {
		panic(err)
	}
	_ = buf.Bytes()
}

func benchRead1M() {
	tr := tar.NewReader(bytes.NewReader(gBigArchive))
	hdr, err := tr.Next()
	if err != nil {
		panic(err)
	}
	n, err := io.CopyN(io.Discard, tr, hdr.Size)
	if err != nil && err != io.EOF {
		panic(err)
	}
	_ = n
}

func measure(name string, fn func(), bytesPerOp int) benchResult {
	// warmup 1
	fn()
	runtime.GC()
	start := time.Now()
	for i := 0; i < benchIters; i++ {
		fn()
	}
	elapsed := time.Since(start)
	ns := float64(elapsed.Nanoseconds()) / float64(benchIters)
	ops := 1e9 / ns
	if ns == 0 {
		ops = 0
	}
	return benchResult{
		Name:       name,
		Status:     "ok",
		Iterations: benchIters,
		NsPerOp:    ns,
		OpsPerSec:  ops,
		BytesPerOp: bytesPerOp,
		AllocsPerOp: 0,
		Statistics: map[string]interface{}{
			"sample_count": benchIters,
		},
	}
}

func saveJSON(suite benchSuite) {
	data, err := json.MarshalIndent(suite, "", "  ")
	if err != nil {
		panic(err)
	}
	candidates := []string{
		"build/bench-tar-compare-go.json",
		"compare_go/build/bench-tar-compare-go.json",
		"../../../build/bench-tar-compare-go.json",
		"../../build/bench-tar-compare-go.json",
	}
	// also try absolute relative to this file
	exeDirCandidates := []string{}
	if wd, err := os.Getwd(); err == nil {
		exeDirCandidates = append(exeDirCandidates, filepath.Join(wd, "build/bench-tar-compare-go.json"))
		exeDirCandidates = append(exeDirCandidates, filepath.Join(wd, "compare_go/build/bench-tar-compare-go.json"))
		exeDirCandidates = append(exeDirCandidates, filepath.Join(wd, "../../../build/bench-tar-compare-go.json"))
	}
	all := append(candidates, exeDirCandidates...)
	// always ensure at least one path succeeds: bench_tar/build and repo build
	// Determine repo build path by walking up to find core dir
	wd, _ := os.Getwd()
	for _, p := range all {
		dir := filepath.Dir(p)
		if dir != "." && dir != "" {
			_ = os.MkdirAll(dir, 0755)
		}
		// resolve relative to wd if needed
		outPath := p
		if !filepath.IsAbs(p) && wd != "" {
			// try both relative to wd and relative to bench_tar dir
			abs := filepath.Join(wd, p)
			if _, err := os.Stat(filepath.Dir(abs)); err == nil {
				outPath = abs
			}
		}
		if err := os.WriteFile(outPath, data, 0644); err == nil {
			fmt.Printf("saved %s\n", outPath)
		}
	}
	// Ensure at least the primary expected by check_regression.py is written
	primary := "build/bench-tar-compare-go.json"
	_ = os.MkdirAll(filepath.Dir(primary), 0755)
	_ = os.WriteFile(primary, data, 0644)
	// Also write to repo build if exists
	repoBuild := "../../../build/bench-tar-compare-go.json"
	_ = os.MkdirAll(filepath.Dir(repoBuild), 0755)
	_ = os.WriteFile(repoBuild, data, 0644)
	compareDirBuild := "compare_go/build/bench-tar-compare-go.json"
	_ = os.MkdirAll(filepath.Dir(compareDirBuild), 0755)
	_ = os.WriteFile(compareDirBuild, data, 0644)
	fmt.Println(string(data))
}

func main() {
	generateData()
	gArchive = buildManyArchive200()
	gBigArchive = buildBigArchive()

	// parity check: ensure archives non-empty
	if len(gArchive) == 0 || len(gBigArchive) == 0 {
		panic("archive empty")
	}
	// GOMAXPROCS already set via env, ensure single thread
	runtime.GOMAXPROCS(1)

	results := []benchResult{
		measure("tar/pack/200x512B", benchPackMany, 102400),
		measure("tar/builder-pack/200x512B", benchBuilderPack, 102400),
		measure("tar/open/parse", benchOpenParse, 205824),
		measure("tar/extract-all/200x512B", benchExtractAll, 102400),
		measure("tar/extract-slice/200x512B", benchExtractSlice, 102400),
		measure("tar/write/1MB", benchWrite1M, 1048576),
		measure("tar/read/1MB", benchRead1M, 1048576),
	}

	suite := benchSuite{
		Version:   "1.0",
		Timestamp: time.Now().UTC().Format(time.RFC3339),
		Environment: map[string]interface{}{
			"os":   runtime.GOOS,
			"arch": runtime.GOARCH,
			"go_version": runtime.Version(),
		},
		Summary: map[string]interface{}{
			"total":    len(results),
			"executed": len(results),
			"skipped":  0,
		},
		Benchmarks: results,
	}
	saveJSON(suite)
	fmt.Println("Go tar compare done (archive/tar, GOMAXPROCS=1)")
}
