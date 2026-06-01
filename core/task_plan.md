# Task Plan: SysUtils 依赖消除 — Phase 2

## Goal
将剩余 15 个 SysUtils 硬依赖文件中可替换的调用全部迁移到框架自有 API，最终仅保留 base.pas/errors.pas（Exception 定义点）。

## Current Phase
Phase 1

## Phases

### Phase 1: cpuinfo 5 文件 — FindFirst/DirectoryExists/FileExists → platform API
- [ ] cpuinfo.pas: FindFirst/FindNext/FindClose/DirectoryExists → platform_dir_open/read/close + platform_file_stat
- [ ] cpuinfo.lazy.pas: 同上 + GetEnvironmentVariable → os.env.GetEnv
- [ ] cpuinfo.arm.pas: FileExists → platform_file_stat
- [ ] cpuinfo.loongarch.pas: FileExists → platform_file_stat
- [ ] cpuinfo.riscv.pas: FindFirst/FindNext/FindClose/DirectoryExists/FileExists → platform API
- [ ] cpuinfo.diagnostic.pas: GetTickCount/Now → platform_monotonic_ns
- [ ] 编译验证
- **Status:** not_started

### Phase 2: log.pas — 文件操作 + 时间
- [ ] FileExists → FsExists (nextpas.core.fs)
- [ ] DeleteFile → FsRemove (nextpas.core.fs.dir)
- [ ] RenameFile → FsRename (nextpas.core.fs.dir)
- [ ] 验证 TInstant.Now 已自给（不依赖 SysUtils.Now）
- [ ] 编译验证
- **Status:** not_started

### Phase 3: collections.base — CompareStr/CompareMemRange
- [ ] CompareStr → 自实现 ASCII 比较（或 text.conv 提供）
- [ ] AnsiCompareStr/WideCompareStr/UnicodeCompareStr → 内联实现
- [ ] CompareMemRange → CompareMem (System) 或 platform_memcmp
- [ ] 编译验证
- **Status:** not_started

### Phase 4: collections.forward_list — FreeAndNil
- [ ] FreeAndNil → nextpas.core.base.utils.FreeAndNil
- [ ] 移除 SysUtils uses
- [ ] 编译验证
- **Status:** not_started

### Phase 5: collections.deque — Supports
- [ ] Supports → 直接 QueryInterface 调用或自实现
- [ ] 编译验证
- **Status:** not_started

### Phase 6: mem.memory_map — 最复杂（6+ 符号）
- [ ] GetEnvironmentVariable → os.env.GetEnv
- [ ] GetTempDir → nextpas.core.fs.GetTempDir
- [ ] StringReplace → 自实现或 text.strings
- [ ] IncludeTrailingPathDelimiter → fs.path 工具
- [ ] INVALID_HANDLE_VALUE → PLATFORM_FILE_INVALID_HANDLE
- [ ] FileExists → FsExists
- [ ] DeleteFile → FsRemove / platform_file_unlink
- [ ] 编译验证
- **Status:** not_started

### Phase 7: 最终验证
- [ ] 全量编译 core 库
- [ ] 运行现有测试套件
- [ ] 确认仅 base.pas + errors.pas 保留 SysUtils
- [ ] 提交 git
- **Status:** not_started

## 替换映射表
| SysUtils API | 框架替代 | 来源单元 |
|---|---|---|
| FindFirst/FindNext/FindClose | platform_dir_open/read/close | platform.files |
| DirectoryExists | platform_file_stat (check ftDirectory) | platform.files |
| FileExists | platform_file_stat (check result=0) | platform.files / fs.util |
| GetEnvironmentVariable | GetEnv | os.env |
| GetTempDir | GetTempDir | fs |
| DeleteFile | FsRemove / platform_file_unlink | fs.dir / platform.files |
| RenameFile | FsRename / platform_file_rename | fs.dir / platform.files |
| IncludeTrailingPathDelimiter | 手动 + PathDelim | fs.path |
| StringReplace | 自实现循环 | 内联 |
| INVALID_HANDLE_VALUE | PLATFORM_FILE_INVALID_HANDLE | platform.files.base |
| CompareStr | 自实现 ASCII 比较 | 内联 |
| CompareMemRange | CompareByte (System) | System |
| FreeAndNil | FreeAndNil | base.utils |
| Supports | QueryInterface | 内联 |
| GetTickCount64 | platform_monotonic_ns div 1_000_000 | platform.time |

## Decisions
| Decision | Rationale |
|---|---|
| 用 platform_file_stat 替代 FileExists/DirectoryExists | 避免引入 fs.util 的额外依赖链，cpuinfo 只需最底层 API |
| CompareStr 内联实现 | 纯 ASCII 比较，无需 locale，3 行循环足够 |
| INVALID_HANDLE_VALUE → 常量 | platform.files.base 已定义 PLATFORM_FILE_INVALID_HANDLE |

## Errors Encountered
| Error | Attempt | Resolution |
|---|---|---|
