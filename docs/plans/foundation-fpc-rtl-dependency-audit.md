# FOUNDATION FPC RTL Dependency Audit

> 日期: 2026-06-18
> 范围: `core/src/` 下所有 929 个 `.pas` 文件
> 工作线: FOUNDATION (codex/core-foundation)

## 总览

| 指标 | 数量 |
|------|------|
| 审计文件总数 | 929 |
| 有 FPC RTL 依赖的文件 | 157 (16.9%) |
| 无 FPC RTL 依赖的文件 | 772 (83.1%) |
| 发现的 FPC RTL 单元 | 22 |

**结论**: 83.1% 的文件已经是干净的。TLS 模块集中了 67.5% 的依赖（106/157）。

## Top 5 依赖最严重的 FPC 单元

| 排名 | FPC 单元 | 文件数 | 严重度 | 迁移路径 |
|------|----------|--------|--------|---------|
| 1 | **SysUtils** | 58 | Critical | `system.sysutils` + `text.conv` + `mem` + `fs` + `platform.env` |
| 2 | **Classes** | 48 | Critical | `system.classes` + `io` + `collections` + `thread` |
| 3 | **DynLibs/dynlibs** | 26 | High | `platform.dl` |
| 4 | **Windows** | 15 | High | `platform.windows.base` |
| 5 | **DateUtils** | 14 | Medium | `time` (date, datetime, timezone) |

## Top 5 依赖最严重的模块

| 排名 | 模块 | 文件总数 | 有依赖的文件 | FPC 单元数 |
|------|------|---------|-------------|-----------|
| 1 | **tls** | 225 | 106 (47.1%) | 19 |
| 2 | **tui** | 81 | 11 (13.6%) | 5 |
| 3 | **http** | 36 | 8 (22.2%) | 2 |
| 4 | **crypto** | 26 | 6 (23.1%) | 3 |
| 5 | **git** | 7 | 4 (57.1%) | 4 |

## 完全干净的模块（0 FPC RTL 依赖）

base, contracts, props, template, testing, stopwatch, bytes, text, encoding,
collections, sync, thread, async, time, id, fs, path, process, compress, json,
toml, xml, regex, args, validation, config, websocket, coroutine, cookie, event,
ini, csv, hash, lockfree, sse, reflect, multipart

## 按模块详细矩阵

### TLS 模块 (106 文件，19 FPC 单元)

| FPC 单元 | 文件数 | 用途 | nextPas 替代 | 迁移难度 |
|----------|--------|------|-------------|---------|
| Classes | 43 | TStream, TMemoryStream, TFileStream, TThread, TInterfacedObject, TList, TStringList | system.classes + io + collections + thread | PARTIAL |
| SysUtils | 28 | Format, IntToStr, Trim, SameText, Exception, FreeAndNil, TBytes, FileExists | system.sysutils + text + mem + fs + platform.env | PARTIAL |
| DynLibs | 18 | OpenSSL API 动态加载 | platform.dl | READY |
| dynlibs | 8 | 额外动态加载 | platform.dl | READY |
| Windows | 13 | WinSSL API, crypto utils | platform.windows.base | WAIT |
| SyncObjs | 14 | TCriticalSection, TEvent | sync (mutex, rwlock, condvar) | READY |
| DateUtils | 11 | 证书过期, OCSP 时间戳 | time (date, datetime) | READY |
| Unix | 4 | FreePascal connection, nonblocking | platform.unix.base | WAIT |
| BaseUnix | 3 | dialer, OpenSSL async | platform.posix.base | WAIT |
| ctypes | 4 | OpenSSL connection FFI | platform FFI types | WAIT |
| Sockets | 4 | dialer, mbedtls connection | net (tcp, udp) | PARTIAL |
| StrUtils | 4 | Capability serializer, PKCS#11 | text.strings, text.utils | READY |
| Contnrs | 3 | TFPList (ASN1, mbedtls cert) | collections.list | READY |
| fgl | 3 | TFPGMap (OCSP/session cache) | collections.hashmap | READY |
| fpjson | 3 | TJSONObject (capability diff) | json (types, value, reader, writer) | READY |
| jsonparser | 3 | JSON parsing | json.parser | READY |
| Math | 2 | Debug utils, TLS utils | math | READY |
| Generics.Collections | 2 | TDictionary, TList | collections (hashmap, list) | READY |
| cthreads | 1 | OpenSSL thread API | thread | READY |

### HTTP 模块 (8 文件)

| FPC 单元 | 文件数 | 用途 |
|----------|--------|------|
| SysUtils | 8 | IntToStr, Trim, LowerCase, SameText, Format, TBytes, FreeAndNil, Exception |
| Classes | 1 | TStream (impl.tls.stream) |

### TUI 模块 (11 文件)

| FPC 单元 | 文件数 | 用途 |
|----------|--------|------|
| SysUtils | 9 | 文件操作, 图像能力, keybinding, sixel 渲染 |
| Classes | 1 | TThread (tui.task) |
| DateUtils | 1 | DaysInAMonth (widget.calendar) |
| BaseUnix | 1 | clipboard |
| Unix | 1 | clipboard |

### 其他有依赖的模块

| 模块 | 文件数 | FPC 单元 |
|------|--------|---------|
| io | 4 | BaseUnix(1), Classes(1), SysUtils(3) |
| simd | 4 | BaseUnix(1), Unix(1), Windows(2), ctypes(1) |
| crypto | 6 | Classes(1), MD5(1), Math(4) |
| git | 4 | DateUtils(2), SysUtils(2), ctypes(3), dynlibs(1) |
| mem | 2 | SysUtils(2) |
| net | 2 | SysUtils(2) |
| math | 2 | Math(2) |
| system | 2 | Classes(1), TypInfo(1) — 有意 facade |
| platform | 1 | SysUtils(1) |
| yaml | 1 | Math(1) |
| log | 1 | Math(1) |
| bench | 1 | SysUtils(1) |
| errors | 1 | SysUtils(1) |
| exception | 1 | SysUtils(1) |

## 迁移优先级建议

### P0: 扩展 system 门面覆盖

1. **system.sysutils 扩展** — 覆盖 TBytes, 文件操作, 环境变量, 异常 → 解决 58 文件
2. **system.classes 扩展** — 覆盖 TFileStream, TList, TStringList, TThread → 解决 48 文件

### P1: 已有替代，可直接迁移

3. TLS SyncObjs → `sync` (14 文件)
4. TLS DateUtils → `time` (11 文件)
5. TLS fpjson/jsonparser → `json` (3 文件)
6. TLS fgl/Contnrs/Generics.Collections → `collections` (8 文件)
7. TLS StrUtils → `text.strings/utils` (4 文件)
8. TLS Math → `math` (2 文件)
9. TLS cthreads → `thread` (1 文件)

### P2: 需平台 FFI 完备

10. TLS DynLibs/dynlibs → `platform.dl` (26 文件)
11. TLS Windows → `platform.windows.base` (13 文件)
12. TLS BaseUnix/Unix → `platform.posix.base/unix.base` (7 文件)
13. TLS ctypes → platform FFI types (4 文件)

### P3: 小量清理

14. http SysUtils → `system.sysutils` (8 文件)
15. tui SysUtils → `system.sysutils` (9 文件)
16. 其他模块零星依赖 (io, simd, crypto, git, mem, net, math, platform, yaml, log, bench, errors, exception)

## Codex 审查细化（2026-06-18）

### Classes 依赖四分类

原始审计将 Classes 视为统一 bucket，Codex 指出应按符号拆为四类 owner：

| 符号类型 | 实际 owner | 迁移策略 |
|----------|-----------|---------|
| Stream (TStream, TFileStream, TMemoryStream) | `nextpas.core.io` | 已有 system.classes stream shim |
| Thread (TThread) | `nextpas.core.thread` (未来) | 保留 RTL 残留债务，直到 thread owner 设计 worker abstraction |
| List (TList) | `nextpas.core.collections` | private 用 dynamic array 替代；public 签名需 API redesign |
| InterfacedBase (TInterfacedObject) | `nextpas.core.base` (未来 seam) | 保留 RTL，多模块压力出现时再设计 root-object seam |

### TLS 六文件逐案决策

| 文件 | 依赖类型 | 分类 | 决策 |
|------|---------|------|------|
| `tls.http.client` | TBytes + Exception | **drop uses** | ✅ 已迁：→ `nextpas.core.base` + `nextpas.core.errors` |
| `tls.openssl.api.async` | TList (private FJobs) | **API redesign** | 改 module-local dynamic array 或 collections 容器 |
| `tls.openssl.api.store` | TList (public 返回值) | **API redesign** | 改 `array of PX509` 等专名数组，TLS owner 内部类型 |
| `tls.transport` | TInterfacedObject | **residual RTL debt** | 保留，owner seam 设计后再议 |
| `tls.ocsp.stapling` | TThread | **residual RTL debt** | 保留，thread owner 设计后再议 |
| `tui.task` | TThread | **residual RTL debt** | 保留，同上 |

### P0 修正建议

原始 P0："扩 system.classes 覆盖 TFileStream/TList/TStringList/TThread"
修正为四类决策：
1. **drop uses**: `http.client.pas` — ✅ 已完成，删 `Classes`，改用 `base` + `errors`
2. **owner swap**: `TList` private → collections 容器或 dynamic array
3. **API redesign**: `store.pas` TList 公开返回值 → TLS owner 专属类型
4. **temporary residual RTL debt**: TThread/TInterfacedObject — 保留，标记为已知债务

**核心结论：不要把 TLS P0 做成扩 system.classes 的理由。system.classes 本轮不扩。**
