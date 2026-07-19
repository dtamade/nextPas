# process / fs / path / env — Go / Rust 对标矩阵（R16–R17）

**状态日期**：2026-07-19  
**范围**：L2 `nextpas.core.{process,fs,path,os.env}`  
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名逐字复制。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.2** | R19：WaitGraceful TimedOut（ignore TERM）、ProcessSucceeded 真值表、错误路径、path Clean/Rel 表 |
| **规模 Scale (Essential)** | **9.3** | R20 fs 三 API + R21 ExtraFd/Credential/CancelToken |
| **综合** | **9.25** | 对标 Essential 接近完整 |

**目标线**：质量 ≥ 9.0（**R19 达 9.2**）；规模 Essential ≥ **0.85**；测试合计 ≥ **900**（达成）。

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
| ExtraFiles | ExtraFiles | — | **ExtraFd** | Done（R21；Unix fd→3+） |
| Credential/uid | SysProcAttr | CommandExt | **Credential** | Done（R21；Unix；Win UNSUPPORTED） |
| Context cancel | context | — | **CancelToken** | Done（R21；`IAsyncCancellationToken`） |

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
| HardLink | Link/hard_link | **HardLink** | Done（R20；L0 `platform_file_link`） |
| Chtimes | Chtimes | **Chtimes**（ns epoch） | Done（R20；L0 `platform_file_utimens`） |
| Chown | Chown | **Chown** | Done（R20；L0 `platform_file_chown`；Win UNSUPPORTED） |
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

## 测试规模（R19 校准）

| 套件 | 通过 |
|------|------|
| test_process | **447** |
| test_process_command / deep / pipe | 48 / 20 / 17 |
| test_fs | **151** |
| test_fs_{facade,glob,idir,ifile,text} | 8 / 31 / 7 / 17 / 19 |
| test_path | **68** |
| test_os_env | **67** |
| **合计** | **900** |

目标 **≥900** ✅（R19）。

---

## 延期（Deferred）说明

### L0 缺口（platform 协作清单）

~~HardLink / Chtimes / Chown~~ — **R20 已落地**（`platform_file_link` / `utimens` / `chown` + fs 门面）。

### process 其他 Deferred

- ~~ExtraFiles / Credential / context~~ — **R21 已落地**（Unix 完整；Win Extra/Cred UNSUPPORTED）。

### 外部债

- **wine-runtime-smoke**：~~曾归因 test.expect 交叉编译阻塞~~ — **2026-07-19 实况绿**  
  - `make -C core/tests/nextpas.core.process/test_process_wine wine-runtime-smoke` → **4 passed**（cmd echo / LookPath / timeout / MaxOutput）  
  - truth tier 仍是 **wine-runtime-smoke**（≠ 真 Windows host / ci-matrix）  
  - Batch-0 后 `test.expect` Windows IUnknown ABI 已可用；全量 `nextpas.core.test` 门面可交叉编译 Win64

---

## 维护策略（口径）

**状态：Ready / 维护态。** Essential 与 wine-runtime-smoke 已绿；测试合计 **900**；Quality **9.2**。  
剩余两项为**已知、非阻塞**开放债，不是「模块没做完」。

| 项 | 性质 | 口径 |
|----|------|------|
| **HardLink / Chtimes / Chown** | 已落地 R20 | L0+L2 完成；Win chown = unsupported |
| **测试冲 900** | 已达成 R19 | 合计 900；继续表驱动可选 |

**周报可用一句：**

> process/fs/path/env：Ready / 维护态。Essential + wine 4/4 绿；测试 900；Quality 9.2。剩余 HardLink/Chtimes/Chown 等 platform L0。

**不要说：**「fs 不支持 hardlink」（应说分层 Deferred）；「等有空再说」却不留 L0 清单（上表即清单）。

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-19 | R16 初版矩阵 + 评分卡；Essential 零 L0 API 落地后更新状态 |
| 2026-07-19 | R16 续 WaitGraceful + SameFile |
| 2026-07-19 | R17 质量加厚；合计 751；L0 Deferred 钉死协作清单 |
| 2026-07-19 | R18 wine-runtime-smoke 实况绿（4/4）；去掉过时 expect 阻塞表述 |
| 2026-07-19 | 维护策略口径：L0 Deferred + 900 可选 + 周报话术 |
| 2026-07-19 | R19 质量属性表 + 测试 900；Quality 9.2 / 综合 9.0 |
| 2026-07-19 | R20 HardLink/Chtimes/Chown L0+L2；规模 9.1 |
| 2026-07-20 | R21 ExtraFd/Credential/CancelToken；规模 9.3 |
