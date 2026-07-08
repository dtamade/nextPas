# nextPas I/O Benchmark — 跨语言文件 I/O 性能

**日期**: 2026-06-29
**CPU**: Intel Xeon E5-2696 v4 @ 2.20GHz (44 cores)
**nextPas**: FPC 3.3.1 `-O3` — `nextpas.core.fs` (直接 syscall via platform 层)
**Go**: 1.23.5 — `os.ReadFile` / `os.WriteFile`
**Rust**: 1.96.0 — `std::fs::read` / `std::fs::write`

## 测试参数

- Write/Read 1MB: 顺序写/读 1MB 二进制文件
- Write/Read 10MB: 顺序写/读 10MB 二进制文件
- Write/Read Text: 430KB 文本文件 (10000 行)

## 结果

| 赛道 | nextPas | Go | Rust | vs Go | vs Rust |
|------|---------|-----|------|-------|---------|
| Write/1MB | 498µs | 499µs | 476µs | **平手** | 平手 |
| Read/1MB | 817µs | 1360µs | 167µs | ✅ 1.66x 快 | 4.9x 慢 |
| Write/10MB | 5.96ms | 10.93ms | 6.23ms | ✅ **1.83x 快** | 平手 |
| Read/10MB | 12.87ms | 15.06ms | 2.11ms | ✅ 1.17x 快 | 6.1x 慢 |
| Write/Text | 283µs | 397µs | 168µs | ✅ 1.40x 快 | 1.68x 慢 |
| Read/Text | 770µs | 456µs | 54µs | 1.69x 慢 | 14.3x 慢 |

## 分析

### vs Go: 4赢 1平 1输

- **Write 性能全面领先**: Pascal 的直接 syscall 路径 (platform_file_write) 比 Go 的 `os.File.Write` + `bufio` 更高效
- **Write/10MB 大胜 1.83x**: Go 的内部 polling/FD 管理开销在大文件上被放大
- **Read/Text 小输**: Go 的 `os.ReadFile` 优化较好

### vs Rust: 0赢 6输

Rust 的 `fs::read` 性能异常优秀：
- Read/1MB 只需 167µs (6 GB/s) — 接近内存带宽上限
- Read/Text 只需 54µs (8 GB/s) — 极致 syscall 优化

**Rust 快的原因**:
1. `std::fs::read` 内部使用 `stat` + 单次 `read` syscall + `read_to_end` 优化
2. `Vec<u8>` 分配器使用 jemalloc/系统分配器的 fast path
3. 没有 platform 抽象层开销

**Pascal 的差距主要在读路径**:
1. `FsReadFile` → `platform_fs_read_file_into` 会**重复调用** `platform_fs_file_size`
2. `platform_fs_read_all` 有循环读取开销
3. TBytes 分配可能有 FPC RTL 额外开销

## 优化方向

1. **消除重复 stat**: `platform_fs_read_file_into` 不应再调用 `platform_fs_file_size`
2. **单次 read syscall**: 对已知大小的文件，跳过 read_all 循环
3. **减少分配开销**: 考虑使用 `AllocMem` + `SetLength` 的合并路径
