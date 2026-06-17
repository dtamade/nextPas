# Process/FS/Path/Env Phase 4 Plan — 拳打 Go 脚踢 Rust

> **目标**: 填补与 Go stdlib / Rust std 的关键差距，让 nextPas 的系统编程能力达到一流水准。
> **原则**: 先完善修复，再加新功能；接口设计遵守 design-conventions.md；测试 100% 覆盖。

## Gap Analysis（Go/Rust vs nextPas）

### 已超越 Go/Rust ✅

| 能力 | nextPas | Go | Rust |
|------|---------|-----|------|
| `**` 递归 glob | ✅ FsGlob | ❌ 不支持 | ✅ glob crate |
| `$VAR` + `${VAR}` 展开 | ✅ ExpandEnv | ✅ 仅 `$`/`${` | ❌ 无内置 |
| UTF-16 BOM 检测 | ✅ ReadFileText | ❌ | ❌ |
| sendfile 零拷贝 | ✅ CopyFile | ✅ | ✅ |
| 内存映射行读取 | ✅ MapFileLines | ❌ | ❌ |

### 关键差距（必补）

| 差距 | Go | Rust | nextPas | 优先级 |
|------|-----|------|---------|--------|
| 文件监控 | fsnotify 库 | notify crate | ❌ | P1 |
| 文件锁 | syscall.Flock | fs2 crate | ❌ | P1 |
| 硬链接 | os.Link | fs::hard_link | ❌ | P2 |
| 用户目录 | os.UserHomeDir | dirs crate | ❌ | P2 |
| 临时目录 | os.MkdirTemp | tempfile crate | ❌ | P2 |
| 可执行文件路径 | os.Executable | std::env::current_exe | ❌ | P3 |
| 页大小 | os.Getpagesize | libc::getpagesize | ❌ | P3 |

### 差距详解

#### 1. 文件监控 (fs.watch) — P1
- **Go**: `github.com/fsnotify/fsnotify` (inotify/kqueue/ReadDirectoryChangesW)
- **Rust**: `notify` crate
- **nextPas**: 无
- **实现**: `nextpas.core.fs.watch` — IWatcher 接口 + 平台回调
- **复杂度**: 高（需要 platform 层 inotify/kqueue/ReadDirectoryChangesW 绑定）
- **工时**: 3-5 天

#### 2. 文件锁 (fs.lock) — P1
- **Go**: `syscall.Flock(fd, LOCK_EX|LOCK_SH|LOCK_UN)`
- **Rust**: `fs2::FileExt::lock_shared/lock_exclusive`
- **nextPas**: 无
- **实现**: `FsLock(APath, AMode)` / `FsTryLock` / `FsUnlock`
- **模式**: 共享锁 (SH)、排他锁 (EX)、非阻塞尝试
- **复杂度**: 中（Unix: flock, Windows: LockFileEx）
- **工时**: 2-3 天

#### 3. 硬链接 — P2
- **Go**: `os.Link(old, new)`
- **Rust**: `fs::hard_link(from, to)`
- **nextPas**: 无
- **实现**: `FsLink(AExistingPath, ANewPath)`
- **复杂度**: 低（Unix: link(), Windows: CreateHardLinkW）
- **工时**: 0.5 天

#### 4. 用户目录 — P2
- **Go**: `os.UserHomeDir()`, `os.UserCacheDir()`, `os.UserConfigDir()`
- **Rust**: `dirs` crate (home_dir, cache_dir, config_dir)
- **nextPas**: 无
- **实现**: `FsHomeDir`, `FsCacheDir`, `FsConfigDir`
- **复杂度**: 低（Unix: $HOME, XDG_*, Windows: SHGetFolderPath）
- **工时**: 1 天

#### 5. 临时目录 — P2
- **Go**: `os.MkdirTemp(dir, pattern)`
- **Rust**: `tempfile::TempDir`
- **nextPas**: 只有 TempFile，无 MkdirTemp
- **实现**: `FsMkdirTemp(ADir, APattern): string`
- **复杂度**: 低
- **工时**: 0.5 天

#### 6. 可执行文件路径 — P3
- **Go**: `os.Executable()` (返回绝对路径)
- **Rust**: `std::env::current_exe()`
- **nextPas**: 无
- **实现**: `FsExecutable: string`
- **复杂度**: 低（Linux: /proc/self/exe, macOS: _NSGetExecutablePath, Windows: GetModuleFileNameW）
- **工时**: 0.5 天

#### 7. 页大小 — P3
- **Go**: `os.Getpagesize()`
- **Rust**: `libc::getpagesize()`
- **nextPas**: 无
- **实现**: `FsPageSize: SizeInt`
- **复杂度**: 低（Unix: sysconf(_SC_PAGESIZE), Windows: GetSystemInfo）
- **工时**: 0.25 天

---

## 执行计划

### Phase 4A: 核心补齐（P2 优先——简单快速出成果）

| 任务 | 内容 | 工时 |
|------|------|------|
| P4-1 | FsLink 硬链接 + platform_link | 0.5d |
| P4-2 | FsHomeDir/FsCacheDir/FsConfigDir | 1d |
| P4-3 | FsMkdirTemp 临时目录 | 0.5d |
| P4-4 | FsExecutable 可执行文件路径 | 0.5d |
| P4-5 | FsPageSize 页大小 | 0.25d |

### Phase 4B: 高级特性（P1——填补最大差距）

| 任务 | 内容 | 工时 |
|------|------|------|
| P4-6 | FsLock/FsTryLock/FsUnlock 文件锁 | 2-3d |
| P4-7 | fs.watch 文件监控（IWatcher 接口） | 3-5d |

### Phase 4C: 测试 + 基准 + 文档

| 任务 | 内容 | 工时 |
|------|------|------|
| P4-8 | 所有新 API 100% 测试覆盖 | 随各任务 |
| P4-9 | 扩展基准：文件锁、硬链接、watch | 1d |
| P4-10 | 更新 README + JavaDoc | 0.5d |

---

## 成功标准

1. 所有新 API 100% 测试覆盖，0 泄漏
2. 文件锁支持 SH/EX/UNLOCK + TryLock 非阻塞
3. fs.watch 支持 Linux inotify（最低目标），kqueue/ReadDirectoryChangesW 可后续
4. 基准数据不低于 Go/Rust 同等操作
5. 通过 Codex 审查

## 预估总工时

- Phase 4A: 2.75 天
- Phase 4B: 5-8 天
- Phase 4C: 1.5 天
- **总计: 9-12 天**
