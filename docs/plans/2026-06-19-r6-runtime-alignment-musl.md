# R6 运行时对齐与 musl 目标支持

> **状态**: 🟢 Phase 1-7 SysUtils 迁移完成，Phase 8-9 + R6.2 待执行
> **时间**: ~1-2 天剩余
> **前提**: R5 自举收敛完成（stage3≡stage4 SHA256 一致）

---

## 0. 核心原则

nextPas 的编译器代码**全部基于 nextpas.core 构建**。不使用 FPC 的 System/SysUtils/Classes。

## 1. 当前状态 (2026-06-19 已验证)

### 已验证事实

- rebuild-compiler.sh **已包含** `-Fu"$ROOT/core/src"` —— 搜索路径就绪
- 3 个编译器文件已用 `nextpas.core.system.contracts` —— 集成先例存在
- 25 个编译器文件使用 SysUtils/Classes（不含 tests）
- `nextpas.core.process.pathresolve` **当前无法被 FPC 编译**（`platform_fs_is_executable` 未解析）
- `np_toolchain_runner.pas` 额外依赖 `Classes, Process` FPC 标准库

### 编译器实际使用的 SysUtils 函数（已验证）

| 函数 | 使用次数 | 所在模块 | nextpas.core 替代方案 | 迁移方式 |
|------|---------|---------|---------------------|---------|
| `IntToStr` | ~264 | text.conv | `IntToStr` (同名，返回 Int64) | 直接替换 |
| `Trim` | ~86 | text.conv | `Trim` (同名) | 直接替换 |
| `UpperCase`/`LowerCase` | ~12+11 | text.conv | `UpperCase`/`LowerCase` (ASCII-only) | 直接替换 |
| `SameText` | 少量 | text.conv | `SameText` (同名) | 直接替换 |
| `StrToInt`/`StrToIntDef` | 少量 | text.conv | `StrToInt` (返回 Int64) | 直接替换，注意返回类型 |
| `IntToHex` | 少量 | text.conv | `IntToHex` (参数 UInt64) | 直接替换，注意参数类型 |
| `Format` | 少量 | text.conv | `Format` (deprecated) | 直接替换 |
| `StringReplace` | 少量 | text.conv | `StringReplace` (同名) | 直接替换 |
| `IncludeTrailingPathDelimiter` | **~25** | **缺失** | **需补: `nextpas.core.path` 加 alias → `FsPathEnsureSep`** | **加 alias** |
| `ExcludeTrailingPathDelimiter` | ~2 | **缺失** | **需补: `nextpas.core.path` 加 alias → `FsPathTrimSep`** | **加 alias** |
| `ExpandFileName` | **~20** | **缺失** | **需补: `nextpas.core.path` 加 alias → `FsPathAbs`** | **加 alias** |
| `ExtractFilePath`/`ExtractFileDir` | ~21 | path | `ExtractFilePath` (别名已存在) | 直接替换 |
| `ExtractFileName`/`ExtractFileExt` | ~6 | path | `ExtractFileName`/`ExtractFileExt` (别名已存在) | 直接替换 |
| `ChangeFileExt` | 少量 | path | `ChangeFileExt` (别名已存在) | 直接替换 |
| `FileExists` | ~23 | fs.util | `FsExists` 或 `FsIsFile` | 改名替换 |
| `DirectoryExists` | ~5 | fs.util | `FsIsDir` | 改名替换 |
| `DeleteFile` | ~8 | fs.dir | `FsRemove` | 改名替换 |
| `ForceDirectories` | ~2 | fs.dir | `FsMkdirAll` | 改名替换 |
| `FindFirst/FindNext/FindClose` | ~3 组 | fs.dir | **`FsReadDir` + filter** | **重写为 IDirIterator 模式** |
| `GetEnvironmentVariable` | ~1 | os.env | `GetEnvironmentVariable` (同名) | 直接替换 |
| `FreeAndNil` | ~8 | base.utils | `FreeAndNil` (同名) | 直接替换 |
| `Now` | **1** | time | `DateTimeNow` | 改名替换 |
| `FormatDateTime` | 少量 | time | `FormatDateTime` (同名) | 直接替换 |
| `Assigned` | ~4 | FPC 内建 | 保持 FPC 内建 | 不迁移 |
| `ParamStr`/`ParamCount` | 多处 | FPC 内建 | 保持 FPC 内建 | 不迁移 |
| `Pos`/`Copy`/`Length`/`SetLength` | 大量 | FPC 内建 | 保持 FPC 内建 | 不迁移 |

**特别说明**:
- FPC 内建函数 (`Assigned`, `ParamStr`, `ParamCount`, `Pos`, `Copy`, `Length`, `SetLength`, `Low`, `High` 等) 无需迁移，它们属于 Pascal 语言和 System 内建
- `SysErrorMessage` / `GetLastOSError` 在编译器代码中实际未使用（Stage0 wrapper 有 SysErrorMessage 引用但 stage0 本身不在 R6 范围）
- `IsPathDelimiter` / `ExtractFileNameOnly` 无编译器消费方，不预付 surface
- `SysUtils.pas` (953 行) 提供的 FPC SysUtils 兼容层，R6 完成后应被完全废弃
- `np_toolchain_runner.pas` 依赖 `Classes` 和 `Process`，需要额外处理

## 2. R6.1 SysUtils → nextpas.core 迁移 (2-3 天)

### Codex 架构决策 (2026-06-19)

> **叶子 helper 加 alias，范式级 API 重写。**

- `IncludeTrailingPathDelimiter` 等 → spelling migration → 加 alias 到 owner module (`nextpas.core.path`)
- `FindFirst/TSearchRec` → programming model migration → 重写为 nextpas-core-native 目录迭代
- alias 只加在 owner module，**不加回 `nextpas.core.system`** (source contracts 会 reject)

### Phase 1: 补 nextpas.core.path 缺失的 SysUtils 兼容别名

**文件**: `core/src/nextpas.core.path.pas`

在 SysUtils-compatible aliases 区域补充：

```pascal
{ SysUtils-compatible aliases — migration surface }
function IncludeTrailingPathDelimiter(const APath: string): string;
function ExcludeTrailingPathDelimiter(const APath: string): string;
function ExpandFileName(const APath: string): string;
```

实现委托：
- `IncludeTrailingPathDelimiter` → `FsPathEnsureSep` (nextpas.core.fs.path.pas:152)
- `ExcludeTrailingPathDelimiter` → `FsPathTrimSep` (nextpas.core.fs.path.pas)
- `ExpandFileName` → `FsPathAbs` (nextpas.core.fs.path.pas)

**Codex 说明**: `IsPathDelimiter`、`ExtractFileNameOnly` 无实际消费方，不预付 surface。

### Phase 2: FPC host-compile probe (逐模块)

每个待迁移模块先独立 probe，确认 FPC trunk 能编译：

```bash
# 对每个 nextpas.core.* 模块
fpc /tmp/core_probe.pas \
  -Fu"$ROOT/core/src" \
  -Fi"$ROOT/core/src" \
  -FE/tmp -FU/tmp
```

已验证可编译: `text.conv`, `path`, `fs`, `os.env`, `time`
**当前不可编译**: `process.pathresolve` (`platform_fs_is_executable` 未解析)

### Phase 3: 叶子函数直接替换 (text.conv / path / os.env / time)

这些函数名在 nextpas.core 中完全同名，直接替换 `uses SysUtils` → `uses nextpas.core.text.conv, nextpas.core.path, nextpas.core.os.env, nextpas.core.time`。

**目标文件** (18 个使用叶子函数的编译器文件):
1. `np_lexer.pas` — LowerCase
2. `np_preprocessor.pas` — UpperCase, LowerCase
3. `np_green_tree.pas` — UpperCase, LowerCase
4. `np_semantic_model.pas` — IntToStr, Trim
5. `np_semantic_analyzer.pas` — LowerCase, IntToStr, Trim (注意 FileAge cache 字段 LongInt→Int64)
6. `np_hir_builder.pas` — IntToStr, Trim
7. `np_hir_model.pas` — IntToStr, Trim
8. `np_hir_types.pas` — IntToStr
9. `np_hir_printer.pas` — IntToStr
10. `np_hir_verifier.pas` — IntToStr
11. `np_compilation_session.pas` — IntToStr, Trim
12. `np_unit_graph.pas` — IntToStr, Trim
13. `np_source_database.pas` — IntToStr
14. `np_package_manifest.pas` — LowerCase, Trim, IncludeTrailingPathDelimiter, ExcludeTrailingPathDelimiter, ExpandFileName, ExtractFilePath, ExtractFileName
15. `np_package_lock.pas` — ExpandFileName
16. `np_package_workflow.pas` — ExpandFileName, IncludeTrailingPathDelimiter
17. `np_workspace_model.pas` — IncludeTrailingPathDelimiter
18. `np_backend_plan.pas` — IntToStr

**注意**: `np_semantic_analyzer.pas` 的 FileAge cache 字段要从 `LongInt` 提升到 `Int64` (Codex 警报: 静默截断风险)

### Phase 4: fs.util / fs.dir 函数改名替换

| FPC 调用 | 替换为 | 模块 |
|-----------|--------|------|
| `FileExists(X)` | `FsExists(X)` 或 `FsIsFile(X)` | nextpas.core.fs.util |
| `DirectoryExists(X)` | `FsIsDir(X)` | nextpas.core.fs.util |
| `DeleteFile(X)` | `FsRemove(X)` | nextpas.core.fs.dir |
| `ForceDirectories(X)` | `FsMkdirAll(X)` | nextpas.core.fs.dir |
| `GetCurrentDir` | `FsGetCwd` | nextpas.core.fs.util |

**目标文件**: `np_unit_resolver.pas`, `np_toolchain_runner.pas`

### Phase 5: FindFirst/FindNext/FindClose → FsReadDir 重写

**影响文件**:
- `np_unit_resolver.pas` — 扫描 `*.pas`/`*.pp` 发现单元文件
- `np_toolchain_runner.pas` — 扫描 `.o` 文件用于链接

**Codex 决策: 选 B (重写)** — 不建 TSearchRec 兼容层。

理由:
- 只有 2 个文件使用，不值得建兼容层
- 兼容层 = "把 shim 从 SysUtils.pas 搬到 nextpas.core.fs.dir 继续养"
- 用 FsReadDir + 简单后缀过滤即可

**重写方案**: 用 `nextpas.core.fs.dir.FsReadDir` 获取目录条目列表，过滤文件名后缀：

```pascal
// 旧: FindFirst(Dir + '/*.pas', faAnyFile, SearchRec)
// 新: FsReadDir 返回 entries，过滤后缀
entries := FsReadDir(DirPath);
for i := 0 to High(entries) do
  if (PathExt(entries[i].Name) = '.pas') or
     (PathExt(entries[i].Name) = '.pp') then
    // 处理匹配项
```

### Phase 6: Now → DateTimeNow

**影响**: 仅 `np_unit_resolver.pas:484` 一处
```pascal
// 旧: FRootIndexes[ARootIndex].LastScanTimestamp := Round(Now * 86400);
// 新: FRootIndexes[ARootIndex].LastScanTimestamp := Round(DateTimeNow * 86400);
// 需要: uses nextpas.core.time;
```

### Phase 7: np_toolchain_runner.pas 额外依赖处理

**问题**: 此文件还依赖 `Classes` (TStringList) 和 `Process` (TProcess)。

**策略**: 
- `TStringList` → 可用 `TStringArray` + 自定义 split/join 替代
- `TProcess` → 可用 `nextpas.core.process.command.ICommand` 替代
- 但 `nextpas.core.process.pathresolve` 当前 FPC 编译不过 (`platform_fs_is_executable`)
- **R6.1 先跳过此文件**，留到 R6.4 (toolchain runner 独立迁移)

### Phase 8: 验证自举循环

```bash
# 完整重编译
./scripts/rebuild-compiler.sh

# stage2/3/4 闭环
NEXTPAS_REPO_ROOT="$ROOT" "$STAGE0" build ...   # stage2
NEXTPAS_REPO_ROOT="$ROOT" "$STAGE2" build ...   # stage3
NEXTPAS_REPO_ROOT="$ROOT" "$STAGE3" build ...   # stage4

# SHA256 一致
sha256sum "$S3/nextpas" "$S4/nextpas"  # 必须相等

# 全量测试
make -C . test TEST_FILTER=compiler-pass
```

### Phase 9: 删除 SysUtils shim

```bash
git rm units/linux-x86_64/SysUtils.pas
```

## 3. R6.2 musl 目标支持 (1 天)

### 3.1 创建目标配置

**新建**: `build/targets/linux-x86_64-musl.toml`

参考 `build/targets/linux-x86_64.toml`，主要差异:
- toolchain: `musl-gcc` 替代 `x86_64-linux-gnu-gcc`
- linker flags: `-static` 替代动态链接
- crt paths: 使用 musl 的 `crt1.o`, `crti.o`, `crtn.o`
- dynamic linker: `/lib/ld-musl-x86_64.so.1` (或空，因为静态链接)

### 3.2 工具链绑定

在 `compiler/toolchain/np_toolchain_profiles.pas` 中注册 musl 目标:

```toml
[target.linux-x86_64-musl]
c_compiler = "musl-gcc"
linker = "musl-gcc"
link_flags = "-static -no-pie"
crt_files = ["crt1.o", "crti.o", "crtn.o"]
```

### 3.3 静态链接验证

```bash
# 在 Alpine Linux 容器中验证
docker run --rm -v "$PWD:/work" alpine:latest \
  sh -c "apk add gcc musl-dev && cd /work && ./build/stage0-bootstrap/nextpas build ..."

# 二进制兼容性检查
file build/out/nextpas   # 应显示 "statically linked"
ldd build/out/nextpas    # 应显示 "not a dynamic executable"
```

## 4. R6.3 双目标自举验证 (半天)

在同一个 worktree 中:

1. glibc 目标自举 → stage3≡stage4 ✓
2. musl 目标自举 → stage3≡stage4 ✓
3. 交叉验证: glibc stage2 编译 musl 目标 → stage3 musl 可执行 ✓

```bash
# glibc 自举
make rebuild-compiler
NEXTPAS_TARGET=linux-x86_64 make verify

# musl 自举
NEXTPAS_TARGET=linux-x86_64-musl make verify
```

## 5. 迁移后清理

- [x] Step 0: 搜索路径就绪
- [x] Phase 1: nextpas.core.path 补 SysUtils 兼容别名
- [x] Phase 2: FPC host-compile probe
- [x] Phase 3: 叶子函数替换 (23 文件)
- [x] Phase 4: fs.util/fs.dir 函数改名
- [x] Phase 5: FindFirst → FsReadDir 重写 (np_unit_resolver + np_toolchain_runner)
- [x] Phase 6: Now → DateTimeNow
- [x] Phase 7: np_toolchain_runner SysUtils 清零 (Classes/Process 保留)
- [ ] Phase 8: 验证自举循环 stage3≡stage4 (需 resolver 修复)
- [ ] Phase 9: 删除 `units/linux-x86_64/SysUtils.pas`
- [ ] Phase 8: 验证自举循环 stage3≡stage4 (需 resolver 修复)
- [ ] Phase 9: 删除 `units/linux-x86_64/SysUtils.pas`
- [ ] R6.2: musl 目标支持
- [ ] R6.3: 双目标验证

## 6. 风险与对策

| 风险 | 概率 | 影响 | 对策 |
|------|------|------|------|
| nextpas.core 模块 FPC host 编译失败 | 中 | Phase 2 阻塞 | 逐模块 probe，有问题的跳过留后续 |
| FindFirst→FsReadDir 重写引入 bug | 低 | 单元发现失败 | 重写后立即跑 compiler-pass 测试 |
| SysUtils.pas 删除后遗漏依赖 | 低 | 编译失败 | 分批删除，每删一批验证编译 |
| np_toolchain_runner 的 Classes/Process 依赖 | 高 | Phase 7 阻塞 | R6.1 跳过此文件，R6.4 专项处理 |
| musl 静态链接与 nextpas.core 不兼容 | 低 | R6.2 阻塞 | 先做最小 hello world 验证 |
| StrToInt 返回 Int64 导致类型不匹配 | 低 | 隐式截断 | 编译器警告检查 + 代码审查 |

## 7. 前置依赖检查

开始前需确认:
- [x] rebuild-compiler.sh 包含 `-Fu$ROOT/core/src`
- [x] nextpas.core.text.conv 能被 FPC trunk 正确编译
- [x] nextpas.core.path 能被 FPC trunk 正确编译
- [x] nextpas.core.fs.util 能被 FPC trunk 正确编译
- [x] nextpas.core.fs.dir 能被 FPC trunk 正确编译
- [x] nextpas.core.os.env 能被 FPC trunk 正确编译
- [x] nextpas.core.time 能被 FPC trunk 正确编译

---

## 参考资料

- [runtime-contracts.md](../../core/docs/system/runtime-contracts.md) — 运行时契约名称
- [goal-tree.md](../../core/docs/system/goal-tree.md) — 分阶段目标树
- [五线工作图](2026-06-18-five-lines-work-map.md) — 当前进度总览
