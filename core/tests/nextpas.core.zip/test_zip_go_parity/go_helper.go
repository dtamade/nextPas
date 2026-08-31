package main

import (
	"archive/zip"
	"bytes"
	"encoding/hex"
	"fmt"
	"hash/crc32"
	"io"
	"os"
	"strings"
)

func mustHex(s string) []byte {
	if s == "" {
		return nil
	}
	b, err := hex.DecodeString(s)
	if err != nil {
		fmt.Fprintf(os.Stderr, "bad hex %q: %v\n", s, err)
		os.Exit(2)
	}
	return b
}

func readManifest(path string) [][3]string {
	data, err := os.ReadFile(path)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open manifest %v\n", err)
		os.Exit(2)
	}
	// Trim trailing newline to avoid empty last row, then split
	text := strings.ReplaceAll(string(data), "\r\n", "\n")
	lines := strings.Split(text, "\n")
	var rows [][3]string
	for _, line := range lines {
		if line == "" {
			continue
		}
		parts := strings.SplitN(line, "\t", 3)
		if len(parts) != 3 {
			fmt.Fprintf(os.Stderr, "manifest bad line len=%d %q\n", len(line), line[:min(64, len(line))])
			os.Exit(2)
		}
		rows = append(rows, [3]string{parts[0], parts[1], parts[2]})
	}
	return rows
}

func min(a, b int) int { if a < b { return a }; return b }

func doGen(outPath, manifestPath string) {
	rows := readManifest(manifestPath)
	out, err := os.Create(outPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "create %v\n", err)
		os.Exit(2)
	}
	zw := zip.NewWriter(out)
	for _, r := range rows {
		name := r[0]
		methodStr := r[1]
		hexStr := r[2]
		payload := mustHex(hexStr)
		isDir := strings.HasSuffix(name, "/")
		var method uint16
		if methodStr == "8" {
			method = zip.Deflate
		} else {
			method = zip.Store
		}
		fh := &zip.FileHeader{Name: name, Method: method}
		// Explicit UTF-8 for parity with Pascal (flag 0x800 is automatic for non-ASCII)
		fh.Flags = 0x800
		if isDir {
			fh.SetMode(0755 | os.ModeDir)
		}
		w, err := zw.CreateHeader(fh)
		if err != nil {
			fmt.Fprintf(os.Stderr, "create header %v\n", err)
			os.Exit(2)
		}
		if !isDir && len(payload) > 0 {
			if _, err := w.Write(payload); err != nil {
				fmt.Fprintf(os.Stderr, "write %v\n", err)
				os.Exit(2)
			}
		}
	}
	if err := zw.Close(); err != nil {
		fmt.Fprintf(os.Stderr, "close zip %v\n", err)
		os.Exit(2)
	}
	out.Close()
	fmt.Println("GEN OK")
}

func doVerify(zipPath, manifestPath string) {
	rows := readManifest(manifestPath)
	r, err := zip.OpenReader(zipPath)
	if err != nil {
		fmt.Fprintf(os.Stderr, "open zip %v\n", err)
		os.Exit(2)
	}
	defer r.Close()
	if len(r.File) != len(rows) {
		fmt.Fprintf(os.Stderr, "count %d != %d\n", len(r.File), len(rows))
		os.Exit(1)
	}
	for i, f := range r.File {
		expName := rows[i][0]
		expMethodStr := rows[i][1]
		expHex := rows[i][2]
		expPayload := mustHex(expHex)
		if f.Name != expName {
			fmt.Fprintf(os.Stderr, "name %q != %q at %d\n", f.Name, expName, i)
			os.Exit(1)
		}
		expMethod := uint16(zip.Store)
		if expMethodStr == "8" {
			expMethod = zip.Deflate
		}
		if f.Method != expMethod {
			fmt.Fprintf(os.Stderr, "method %d != %d at %q\n", f.Method, expMethod, f.Name)
			os.Exit(1)
		}
		// UTF-8 flag must be set (Pascal always sets 0x800)
		if f.Flags & 0x800 == 0 {
			// Not fatal for pure ASCII, but we enforce for parity
			// Allow pure ASCII without flag to pass (Go may omit for ASCII)
			hasNonASCII := false
			for _, ch := range f.Name {
				if ch > 127 {
					hasNonASCII = true
					break
				}
			}
			if hasNonASCII {
				fmt.Fprintf(os.Stderr, "utf8 flag missing at %q\n", f.Name)
				os.Exit(1)
			}
		}
		rc, err := f.Open()
		if err != nil {
			fmt.Fprintf(os.Stderr, "open entry %v\n", err)
			os.Exit(2)
		}
		got, err := io.ReadAll(rc)
		rc.Close()
		if err != nil {
			fmt.Fprintf(os.Stderr, "read entry %v\n", err)
			os.Exit(2)
		}
		if len(got) != len(expPayload) {
			fmt.Fprintf(os.Stderr, "size %d != %d at %q\n", len(got), len(expPayload), f.Name)
			os.Exit(1)
		}
		if crc32.ChecksumIEEE(got) != crc32.ChecksumIEEE(expPayload) {
			fmt.Fprintf(os.Stderr, "crc mismatch at %q\n", f.Name)
			os.Exit(1)
		}
		if !bytes.Equal(got, expPayload) {
			fmt.Fprintf(os.Stderr, "content mismatch at %q\n", f.Name)
			os.Exit(1)
		}
	}
	fmt.Println("VERIFY OK")
}

func main() {
	if len(os.Args) < 4 {
		fmt.Fprintf(os.Stderr, "usage: %s <gen|verify> <zip> <manifest>\n", os.Args[0])
		os.Exit(2)
	}
	mode := os.Args[1]
	zipPath := os.Args[2]
	manifestPath := os.Args[3]
	switch mode {
	case "gen":
		doGen(zipPath, manifestPath)
	case "verify":
		doVerify(zipPath, manifestPath)
	default:
		fmt.Fprintf(os.Stderr, "unknown mode %q\n", mode)
		os.Exit(2)
	}
}
