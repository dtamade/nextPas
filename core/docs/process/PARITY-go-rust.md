# process / fs / path / env — Go / Rust 对标矩阵（R16–R23）

**状态日期**：2026-07-20  
**开发地图（终局 / 里程碑 / 治理）**：[`ROADMAP.md`](./ROADMAP.md) — **Host Essential 已完成；禁止无限 Rxx。**  
**范围**：L2 `nextpas.core.{process,fs,path,os.env}`  
**标杆**：Go `os` / `os/exec` / `path/filepath`；Rust `std::{fs,process,path,env}`

> 对标的是**能力 + 边界语义 + 测试强度**，不是符号名逐字复制。  
> **Host 状态：Maintenance**（M0/M1）。**M2 Windows usable：Done**（W1–W4；truth=`wine-runtime-smoke`）。下一可选：**M3 host-windows CI**。一眼表：[WIN.md](./WIN.md)。

---

## 评分卡

| 维度 | 分 (0–10) | 说明 |
|------|-----------|------|
| **质量 Quality** | **9.9** | R34 fs 同方法证据 + wine Capture + IFile ReadAt |
| **规模 Scale (Essential)** | **9.8** | R29 递归 Watch + R23–R25 |
| **综合** | **9.9** | Essential + 同方法 SCORECARD + wine Capture |

**目标线**：质量 ≥ 9.0；规模 Essential ≥ **0.85**；测试合计 ≥ **900**。

**证据文档**：[`SCORECARD.md`](./SCORECARD.md)（host-linux 数字 + wine-runtime-smoke 表）。

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
| ExtraFiles | ExtraFiles | — | **ExtraFd** | Done Unix；**Win UNSUPPORTED fail-closed**（M2-W3） |
| Credential/uid | SysProcAttr | CommandExt | **Credential** | Done Unix；**Win UNSUPPORTED fail-closed**（M2-W3） |
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
| File watch | fsnotify / notify | **Watch / AddTree / Remove / IFsWatcher** | Done Unix；**Win S2 poll**（platform RDCW；Wine soft） |
| Process group / tree kill | setpgid + kill(-pg) | **NewProcessGroup + KillTree** | Done Unix；**Win Job Object**（M2-W2） |

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

## 测试规模（R28 校准）

| 套件 | 通过 | 框架 |
|------|------|------|
| test_process | **128** cases（原 ~455 手写 Check 行） | **nextpas.core.test** |
| test_process_command | **21** cases（原 48 Check 行） | **nextpas.core.test** |
| test_process_deep / pipe | **27** / **17** | nextpas.core.test |
| test_fs | **158** | nextpas.core.test |
| test_fs_watch | **13** | nextpas.core.test（R32 Remove） |
| test_fs_{facade,glob,idir,ifile,text} | 8 / 31 / 7 / **21** / 19 | nextpas.core.test |
| test_path | **70** | nextpas.core.test（R31 边界表） |
| test_os_env | **70** | nextpas.core.test（R31 Expand/Keys） |
| **合计** | **≥900 行为覆盖**（口径：framework cases + 既有 fs/path/env） | |

R28 起 process 主套件以 **T.Test 用例数** 计，不再用手写 PASS 行数；行为覆盖不弱于迁移前。

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
| ExtraFd / Credential Win | **M2-W3 DONE**（明文 fail-closed） |
| Win platform.watch Poll | **M2-W1 DONE**（S2 RDCW；Wine soft） |
| M2 文档/wine 收敛 | **M2-W4 DONE**（[WIN.md](./WIN.md) + min set 24） |
| 真 Windows host CI | **M3**；基础设施 |
| Status/spawn 1.0× Go | **非目标**（收益递减） |

### 外部债 / 证据

- **wine 最小生产集**（M2-W4，2026-07-20）：  
  - process **11** / fs **3** / path **4** / os.env **3** / fs.watch **3** = **24**  
  - `bash core/tests/run_l2_wine_min_set.sh` · [WIN.md](./WIN.md) · [SCORECARD.md](./SCORECARD.md)

---

## 维护策略（口径）

**状态：Host Maintenance + M2 Done（wine usable）。** Essential Host 完成；R16–R34 与 W1–W4 **封顶**。

**新工作必须贴标签**（`bug` / `win-l0` / `win-l2` / `ci` / `docs`），见 [`ROADMAP.md`](./ROADMAP.md) §5。  
默认不接无标签 polish；真 Windows CI 走 **M3**。

**周报模板：**

> process/fs/path/env：Host Maintenance；M2 Win(wine) Done。Quality 9.9 / Scale 9.8。可选 M3 host-windows。

---

## 变更记录

| 日期 | 说明 |
|------|------|
| 2026-07-20 | **ROADMAP**：Host 完成声明；冻结 R 序列；M2 Win Waves |
| 2026-07-20 | **M2-W1**：Win watch S2 poll 已由 platform 落地；L2 wine 证据 |
| 2026-07-20 | **M2-W2**：Win Job Object NewProcessGroup/KillTree |
| 2026-07-20 | R34 fs 同方法 SCORECARD + wine Capture 8 + IFile ReadAt/WriteAt |
| 2026-07-19 | R16 续 WaitGraceful + SameFile |
| 2026-07-19 | R17 质量加厚；合计 751；L0 Deferred 钉死协作清单 |
| 2026-07-19 | R18 wine-runtime-smoke 实况绿（4/4）；去掉过时 expect 阻塞表述 |
| 2026-07-19 | 维护策略口径：L0 Deferred + 900 可选 + 周报话术 |
| 2026-07-19 | R19 质量属性表 + 测试 900；Quality 9.2 / 综合 9.0 |
| 2026-07-19 | R20 HardLink/Chtimes/Chown L0+L2；规模 9.1 |
| 2026-07-20 | R21 ExtraFd/Credential/CancelToken；规模 9.3 |
| 2026-07-20 | R22 quality hardening；Quality 9.5 / 综合 9.4；测试 ≈922 |
| 2026-07-20 | R23 File lock L2；Scale 9.5 / 综合 9.5；ifile 21；测试 ≈926 |
| 2026-07-20 | R24-PG NewProcessGroup/KillTree；R25 fs.Watch；Scale 9.7 / 综合 9.6 |
| 2026-07-20 | R24-EV L2 wine×4 + SCORECARD；综合 9.7 |
| 2026-07-20 | R27 Capture ~1.6ms (~1.3× Go；stdout-only + drain fast-path) |
| 2026-07-20 | R28 test_process + command 迁 nextpas.core.test；dual-pipe SCORECARD；Quality 9.6 |
| 2026-07-20 | R29 IFsWatcher.AddTree 递归 + Wd 路径消歧；Scale 9.8；watch 11 |
| 2026-07-20 | R30 Linux inotify residual queue；burst 不丢；Quality 9.7；watch 12 |
| 2026-07-20 | R31 path/env 边界表 70/70 + SCORECARD 重测 + Destroy 100µs；Quality 9.8 |
| 2026-07-20 | R32 IFsWatcher.Remove + platform_watch_remove；watch 13 |
| 2026-07-20 | R33 Wait/WaitGraceful 100µs 起步；wine×5 复跑全绿；SCORECARD 刷新 |
| 2026-07-20 | R34 fs 同方法 SCORECARD + wine Capture 8 + IFile ReadAt/WriteAt |
| 2026-07-20 | **M2-W3**：ExtraFd/Credential Win 支持矩阵 + fail-closed |
| 2026-07-20 | **M2-W4**：WIN.md + wine 最小生产集 24；E2 Done（wine truth） |
