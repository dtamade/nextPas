# process / fs / path / env — Go / Rust 对标矩阵（R16）

**状态日期**：2026-07-19  
**范围**：L2 `nextpas.core.{process,fs,path,os.env}`  
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名逐字复制。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.0** | CONTRACT INV 完整；真 uses 门禁；Wait/TryWait/PathDir/env 名已钉；R15 全量绿 |
| **规模 Scale (Essential)** | **8.4** | R16：IsSymlink、path slash/list/volume/stem/strip、ClearEnv 已落地；HardLink/Chtimes/Chown 仍需 L0 |
| **综合** | **8.7** | 质量保持；规模 Essential 接近 0.85 目标 |

**目标线**：质量 ≥ 9.0（保持）；规模 Essential 覆盖率 ≥ **0.85**；测试合计 ≥ **900**。

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
| Graceful stop | WaitDelay | — | Missing | P2 可选 |
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
| HardLink | Link/hard_link | — | Missing（需 L0） |
| Chtimes | Chtimes | — | Missing（需 L0） |
| Chown | Chown | — | Missing（需 L0） |
| SameFile(inode) | SameFile | SameFileName only | Missing |
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

## 测试规模（R15 基线）

| 套件 | 通过 |
|------|------|
| process 四套 | 281+48+20+17 |
| fs 六套 | 113+8+31+7+17+19 |
| path | 41 |
| env | 42 |
| **合计** | **~655+**（R16 增量后） |

R16 增量后以 `make test` 重校准；目标 **≥ 900**。

---

## 延期（Deferred）说明

- **process ExtraFiles / Credential / context 取消**：需 L0 spawn 扩展或跨模块 context；无真实消费者前不阻塞 Essential。  
- **HardLink / Chtimes / Chown / SameFile(inode)**：缺 `platform_file_*`；Phase 3 与 platform 协作。  
- **wine-runtime-smoke**：受 test.expect 交叉编译阻塞（外部债）。

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-19 | R16 初版矩阵 + 评分卡；Essential 零 L0 API 落地后更新状态 |
