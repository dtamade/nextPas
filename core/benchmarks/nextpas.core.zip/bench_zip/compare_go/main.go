package main

import (
	"archive/zip"
	"bytes"
	"fmt"
	"hash/crc32"
	"io"
	"time"
)

const (
	fileCount  = 2000
	fileSize   = 512
	smallIters = 5
	bigSize    = 1024 * 1024
	bigIters   = 20
)

var (
	files [][]byte
	blob  []byte
)

func generateData() {
	files = make([][]byte, fileCount)
	for i := range files {
		files[i] = make([]byte, fileSize)
		for j := range files[i] {
			files[i][j] = byte((j*7 + i) % 251)
		}
	}
	blob = make([]byte, bigSize)
	for i := range blob {
		blob[i] = byte((i*7 + i/256) % 251)
	}
}

func entryName(i int) string {
	return fmt.Sprintf("f/%04d.bin", i)
}

func checkEqual(label string, expected, actual []byte) {
	if !bytes.Equal(expected, actual) {
		panic(label + ": byte mismatch")
	}
}

// 全部小文件打成一个 deflate 归档（与 Pascal 端 BuildManyArchive 对齐）
func buildManyArchive() []byte {
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	for i := 0; i < fileCount; i++ {
		fh := &zip.FileHeader{Name: entryName(i), Method: zip.Deflate}
		fw, err := w.CreateHeader(fh)
		if err != nil {
			panic(err.Error())
		}
		if _, err := fw.Write(files[i]); err != nil {
			panic(err.Error())
		}
	}
	if err := w.Close(); err != nil {
		panic(err.Error())
	}
	return buf.Bytes()
}

func benchPackManyDeflate() {
	total := float64(int64(fileCount) * fileSize)
	archive := buildManyArchive()
	ratio := float64(len(archive)) / total * 100

	start := time.Now()
	for i := 0; i < smallIters; i++ {
		archive = buildManyArchive()
	}
	elapsed := time.Since(start).Seconds()

	fmt.Printf("zip pack %4d files   %8.0f entries/s  %6.1f MB/s  ratio=%.1f%%\n",
		fileCount,
		float64(int64(fileCount)*smallIters)/elapsed,
		total*float64(smallIters)/1048576.0/elapsed,
		ratio)
}

func benchOpenParse(archive []byte) {
	start := time.Now()
	for i := 0; i < smallIters*10; i++ {
		zr, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
		if err != nil {
			panic(err.Error())
		}
		if len(zr.File) != fileCount {
			panic("entry count mismatch")
		}
	}
	elapsed := time.Since(start).Seconds()

	fmt.Printf("zip open (parse CD) %8.0f opens/s  %9.0f entries/s\n",
		float64(smallIters*10)/elapsed,
		float64(int64(fileCount)*smallIters*10)/elapsed)
}

func benchExtractAll(archive []byte) {
	zr, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		panic(err.Error())
	}
	for i, f := range zr.File {
		rc, err := f.Open()
		if err != nil {
			panic(err.Error())
		}
		got, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			panic(err.Error())
		}
		checkEqual("extract-all verify", files[i], got)
	}
	total := float64(int64(fileCount) * fileSize)

	buf := make([]byte, fileSize)
	start := time.Now()
	for n := 0; n < smallIters*10; n++ {
		for _, f := range zr.File {
			rc, err := f.Open()
			if err != nil {
				panic(err.Error())
			}
			crc := uint32(0)
			for {
				nread, rerr := rc.Read(buf)
				crc = crc32.Update(crc, crc32.IEEETable, buf[:nread])
				if rerr == io.EOF {
					break
				}
				if rerr != nil {
					panic(rerr.Error())
				}
			}
			rc.Close()
			_ = crc
		}
	}
	elapsed := time.Since(start).Seconds()

	fmt.Printf("zip extract all     %8.0f entries/s  %6.1f MB/s\n",
		float64(int64(fileCount)*smallIters*10)/elapsed,
		total*float64(smallIters*10)/1048576.0/elapsed)
}

func buildBigArchive() []byte {
	var buf bytes.Buffer
	w := zip.NewWriter(&buf)
	fh := &zip.FileHeader{Name: "big.bin", Method: zip.Deflate}
	fw, err := w.CreateHeader(fh)
	if err != nil {
		panic(err.Error())
	}
	if _, err := fw.Write(blob); err != nil {
		panic(err.Error())
	}
	if err := w.Close(); err != nil {
		panic(err.Error())
	}
	return buf.Bytes()
}

func benchBigRoundtrip() {
	archive := buildBigArchive()
	ratio := float64(len(archive)) / float64(bigSize) * 100

	zr, err := zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		panic(err.Error())
	}
	rc, err := zr.File[0].Open()
	if err != nil {
		panic(err.Error())
	}
	got, err := io.ReadAll(rc)
	rc.Close()
	if err != nil {
		panic(err.Error())
	}
	checkEqual("big roundtrip verify", blob, got)

	start := time.Now()
	for i := 0; i < bigIters; i++ {
		archive = buildBigArchive()
	}
	elapsed := time.Since(start).Seconds()
	fmt.Printf("zip write 1MB entry %6.1f MB/s  ratio=%.1f%%\n",
		float64(bigSize*bigIters)/1048576.0/elapsed, ratio)

	zr, err = zip.NewReader(bytes.NewReader(archive), int64(len(archive)))
	if err != nil {
		panic(err.Error())
	}
	bigbuf := make([]byte, 64*1024)
	start = time.Now()
	for i := 0; i < bigIters; i++ {
		rc, err := zr.File[0].Open()
		if err != nil {
			panic(err.Error())
		}
		crc := uint32(0)
		for {
			nread, rerr := rc.Read(bigbuf)
			crc = crc32.Update(crc, crc32.IEEETable, bigbuf[:nread])
			if rerr == io.EOF {
				break
			}
			if rerr != nil {
				panic(rerr.Error())
			}
		}
		rc.Close()
		_ = crc
	}
	elapsed = time.Since(start).Seconds()
	fmt.Printf("zip read 1MB entry  %6.1f MB/s\n",
		float64(bigSize*bigIters)/1048576.0/elapsed)
}

func main() {
	generateData()
	fmt.Printf("=== Go zip benchmark (archive/zip, %d files x %dB + 1MB blob) ===\n",
		fileCount, fileSize)
	fmt.Println()
	archive := buildManyArchive()
	benchPackManyDeflate()
	benchOpenParse(archive)
	benchExtractAll(archive)
	fmt.Println()
	benchBigRoundtrip()
	fmt.Println()
	fmt.Println("done.")
}
