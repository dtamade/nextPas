# process / fs / path / env — Go / Rust 对标矩阵（R16–R17）

**状态日期**：2026-07-19  
**范围**：L2 `nextpas.core.{process,fs,path,os.env}`  
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名逐字复制。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | CONTRACT INV 完整；真 uses 门禁；Wait/TryWait/PathDir/env 名已钉；R17 质量表加厚 |
| **规模 Scale (Essential)** | **8.8** | Essential API 齐（WaitGraceful/SameFile）；HardLink/Chtimes/Chown **Deferred（需 L0）** |
| **综合** | **8.9** | 测试合计 **≥750** 已达成；远期 900 仍可加厚 |

**目标线**：质量 ≥ 9.0（保持）；规模 Essential 覆盖率 ≥ **0.85**；测试合计 ≥ **750**（达成）→ 远期 **900**。

---

## Essential 矩阵

图例：`Done` / `Partial` / `Missing` / `Deferred`

### process

| 能力 | Go | Rust | nextpas | 状态 |
|------|----|------|---------|------|
| Command builder | Cmd | Command | ICommand | Done |
| Spawn / Wait | Start/Wait | spawn/wait | Spawn/Wait | Done |
| Capture | Output | output | Output/Capture | Done |
| Combined | CombinedOutput | — | MergeStderr | Done |
| Status only | Run | status | Status | Done |
| Env replace/extend | Env | env/envs | Env/EnvAdd | Done |
| LookPath | LookPath | — | LookPath | Done |
| Kill / Signal | Kill | kill | Kill/Signal | Partial（Win 信号有限） |
| Timeout | context/WaitDelay | — | Timeout | Done |
| MaxOutput | — | — | MaxOutput | Done |
| Graceful stop | WaitDelay | — | **WaitGraceful** | Done（R16 续） |
| ExtraFiles | ExtraFiles | — | Missing | Deferred |
| Credential/uid | SysProcAttr | CommandExt | Missing | Deferred |
| Context cancel | context | — | Missing | Deferred |

### fs

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Read/Write 全文 | ✓ | ✓ | Done |
| Temp file/dir | ✓ | TempFile/TempDir | Done |
| MkdirAll / RemoveAll | ✓ | ✓ | Done |
| Walk / ReadDir | ✓ | ✓ | Done |
| Symlink / Readlink | ✓ | ✓ | Done |
| Stat / Lstat | ✓ | ✓ | Done |
| Chmod | ✓ | ✓ | Done |
| IFile.Sync | Sync | IFile.Sync | Done（接口已有） |
| IsSymlink(path) | Lstat | **IsSymlink** | Done（R16） |
| PathAbs / resolve | Abs/EvalSymlinks | PathAbs→`platform_path_resolve`（realpath） | **Done**（跟随 symlink） |
| HardLink | Link/hard_link | — | **Deferred**（需 L0 `platform_file_link`） |
| Chtimes | Chtimes | — | **Deferred**（需 L0 utimens） |
| Chown | Chown | — | **Deferred**（需 L0 chown；FFI 有、公开 API 无） |
| SameFile(inode) | SameFile | **SameFile** (lstat Dev+Ino) | Done（R16 续） |
| Remove ENOENT | Go 报错 | **静默成功**（Pascal） | Done（有意 ≠ Go） |

### path

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Join/Clean/Abs/Rel/Base/Dir/Ext/Match | ✓ | ✓ | Done |
| PathDir 双轨 | Go `.` / SysUtils `''` | 门面裸名 `''`；FsPathDir `.` | Done |
| ToSlash / FromSlash | ToSlash/FromSlash | **PathToSlash/PathFromSlash** | Done（R16） |
| SplitList (PATH) | SplitList | **PathSplitList** | Done（R16） |
| VolumeName | VolumeName | **PathVolume** (+ ExtractFileDrive) | Done（R16） |
| FileStem | file_stem | **PathFileStem** | Done（R16） |
| StripPrefix | strip_prefix | **PathStripPrefix** | Done（R16） |

### env

| 能力 | Go/Rust | nextpas | 状态 |
|------|---------|---------|------|
| Get/Set/Unset/Lookup | ✓ | ✓ | Done |
| Environ / keys | Environ | EnvironmentVariables/EnvKeys | Done |
| Expand | Expand (自定义) | ExpandEnv + %VAR% | Done（更强） |
| User*Dir | UserCacheDir… | ✓ | Done |
| Clearenv | Clearenv | **ClearEnv** | Done（R16） |
| 可移植名 | — | INV-9 Set/Expand | Done |

---

## 测试规模（R17 校准）

| 套件 | 通过 |
|------|------|
| test_process | **340** |
| test_process_command / deep / pipe | 48 / 20 / 17 |
| test_fs | **133** |
| test_fs_{facade,glob,idir,ifile,text} | 8 / 31 / 7 / 17 / 19 |
| test_path | **56** |
| test_os_env | **55** |
| **合计** | **751** |

目标 **≥750** ✅；远期 **≥900** 可继续表驱动加厚。

---

## 延期（Deferred）说明

### L0 缺口（platform 协作清单）

L2 **禁止**直调 POSIX FFI。下列能力在 platform 内部/FFI 已见，但**无公开** `platform_file_*` API：

| L2 期望 | 需要 L0 | 现状 |
|---------|---------|------|
| `HardLink` | `platform_file_link(old, new)` | 无公开 API（仅有 symlink） |
| `Chtimes` | `platform_file_utimens(path, atime, mtime)` | syscall 号有，无封装 |
| `Chown` | `platform_file_chown(path, uid, gid)` | `posix.ffi` 有 `chown`，files 层未导出 |

**平台侧建议**：补齐三函数 + 错误码映射 + Windows 对等（或 `PLATFORM_ERR_UNSUPPORTED`），L2 再开一片。

### process 其他 Deferred

- ExtraFiles / Credential / context 取消：需 L0 spawn 扩展或跨模块 context；无真实消费者前不阻塞 Essential。

### 外部债

- **wine-runtime-smoke**：~~曾归因 test.expect 交叉编译阻塞~~ — **2026-07-19 实况绿**  
  - `make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke` → **4 passed**（cmd echo / LookPath / timeout / MaxOutput）  
  - truth tier 仍是 **wine-runtime-smoke**（≠ 真 Windows host / ci-matrix）  
  - Batch-0 后 `test.expect` Windows IUnknown ABI 已可用；全量 `nextpas.core.test` 门面可交叉编译 Win64

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-19 | R16 初版矩阵 + 评分卡；Essential 零 L0 API 落地后更新状态 |
| 2026-07-19 | R16 续 WaitGraceful + SameFile |
| 2026-07-19 | R17 质量加厚；合计 751；L0 Deferred 钉死协作清单 |
| 2026-07-19 | R18 wine-runtime-smoke 实况绿（4/4）；去掉过时 expect 阻塞表述 |
