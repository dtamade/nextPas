# process / fs / path / env — Go / Rust 对标矩阵（R16–R23）

**状态日期**：2026-07-20
**范围**：L2 `nextpas.core.{process,fs,path,os.env}`
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名逐字复制。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.5** | R22 hardening 保持 |
| **规模 Scale (Essential)** | **9.5** | R23 文件锁（IFile.Lock/TryLock/Unlock + OpenLocked） |
| **综合** | **9.5** | Essential + 文件锁闭环 |

**目标线**：质量 ≥ 9.0；规模 Essential ≥ **0.85**；测试合计 ≥ **900**（R23 ifile +4 → ≈**926**）。

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
| Context cancel | context | — | **CancelToken** | Done（R21+R22；Wait/Output/Status/WaitGraceful） |

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
| File lock | flock / fs2 | **IFile.Lock/TryLock/Unlock** + OpenLocked | Done（R23；L0 已有） |

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

## 测试规模（R23 校准）

| 套件 | 通过 |
|------|------|
| test_process | **455** |
| test_process_command / deep / pipe | 48 / **24** / 17 |
| test_fs | **158** |
| test_fs_{facade,glob,idir,ifile,text} | 8 / 31 / 7 / **21** / 19 |
| test_path | **69** |
| test_os_env | **69** |
| **合计** | **≈926** |

目标 **≥900** ✅（R23）。

---

## R22 Hardening 清单

### 本轮关闭

| 项 | 结论 |
|----|------|
| CancelToken 仅 WaitWithOutput 生效 | **已修**：`TChild.Wait`（含 `Status`）轮询 Cancel + Kill，置 `Cancelled` |
| WaitWithOutput 无 Timeout 忙等 | **已修**：进程仍 running 时 sleep 10ms |
| fs.errors 磁盘满/OOM | **已修**：ENOSPC/ENOMEM、Win DISK_FULL → `EResourceExhaustedError` |
| 历史 polish（RemoveAll symlink / Append / pread） | **复核已修复** |

### 仍 Deferred（非阻塞）

| 项 | 性质 |
|----|------|
| FsLock / fs.watch / 进程组 | ~~FsLock~~ **R23 已落地**；watch / 进程组仍 Deferred |
| Win ExtraFd / Credential | 文档 UNSUPPORTED |
| test_process 迁 `nextpas.core.test` | P3 框架债 |
| 真 Windows host CI | 证据仍 wine-runtime-smoke 级 |

### 外部债

- **wine-runtime-smoke**：2026-07-19 实况 **4 passed**；≠ 真 Windows host

---

## 维护策略（口径）

**状态：Ready / 维护态。** Essential + R22 quality + R23 文件锁；测试 **≈926**；Quality **9.5** / Scale **9.5**。

**周报可用一句：**

> process/fs/path/env：Ready。R23 文件锁（IFile.Lock/TryLock/OpenLocked）；测试 ≈926；综合 9.5。下一批可选 fs.watch 或进程组。

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
| 2026-07-20 | R22 quality hardening；Quality 9.5 / 综合 9.4；测试 ≈922 |
| 2026-07-20 | R23 File lock L2；Scale 9.5 / 综合 9.5；ifile 21；测试 ≈926 |
