# R6: 编译器运行时归位 + musl 目标

> **日期**: 2026-06-19
> **状态**: 待启动
> **北极星**: 编译器运行在 `nextpas.core.*` 上，产出 glibc/musl 双目标 ELF

---

## 为什么这是最高优先级

R5 自举虽然 stage3≡stage4 收敛，但编译器依赖 `units/linux-x86_64/SysUtils.pas`
（953 行手写 FPC 兼容 shim）。这违背项目核心原则：

> **nextPas 编译器必须运行在自己的运行时上，不依赖 FPC 兼容层。**

musl 支持是容器化/嵌入式场景的刚需，也是碾压 FPC 的差异化能力。

---

## R6.1: SysUtils → nextpas.core 迁移

**目标**: 编译器源码全部 `uses nextpas.core.*`，删除 SysUtils shim

### 函数映射清单

| # | SysUtils API | nextpas.core API | 模块 | 同名? |
|---|---|---|---|---|
| 1 | `IntToStr(V)` | `IntToStr(V)` | `nextpas.core.text.conv` | ✅ |
| 2 | `StrToInt(S)` | `StrToInt(S)` | `nextpas.core.text.conv` | ✅ |
| 3 | `StrToIntDef(S,D)` | `StrToIntDef(S,D)` | `nextpas.core.text.conv` | ✅ |
| 4 | `StrToInt64Def(S,D)` | `StrToInt64Def(S,D)` | `nextpas.core.text.conv` | ✅ |
| 5 | `TryStrToInt(S,V)` | `TryStrToInt(S,V)` | `nextpas.core.text.conv` | ✅ |
| 6 | `TryStrToInt64(S,V)` | `TryStrToInt64(S,V)` | `nextpas.core.text.conv` | ✅ |
| 7 | `UpperCase(S)` | `UpperCase(S)` | `nextpas.core.text.conv` | ✅ |
| 8 | `LowerCase(S)` | `LowerCase(S)` | `nextpas.core.text.conv` | ✅ |
| 9 | `Trim(S)` | `Trim(S)` | `nextpas.core.text.conv` | ✅ |
| 10 | `SameText(A,B)` | `SameText(A,B)` | `nextpas.core.text.conv` | ✅ |
| 11 | `Format(F,A)` | `Format(F,A)` | `nextpas.core.text.conv` | ✅ |
| 12 | `StringReplace(S,O,N,F)` | `StringReplace(S,O,N,F)` | `nextpas.core.text.conv` | ✅ |
| 13 | `ExtractFileDir(F)` | `PathDir(F)` | `nextpas.core.path` | ❌ |
| 14 | `ExtractFileName(F)` | `PathBase(F)` | `nextpas.core.path` | ❌ |
| 15 | `ExtractFileExt(F)` | `PathExt(F)` | `nextpas.core.path` | ❌ |
| 16 | `ExtractFileDrive(F)` | `PathDrive(F)` | `nextpas.core.path` | ❌ |
| 17 | `ChangeFileExt(F,E)` | `PathChangeExt(F,E)` | `nextpas.core.path` | ❌ |
| 18 | `ExpandFileName(F)` | `PathNormalize(F)` | `nextpas.core.path` | ❌ |
| 19 | `IncludeTrailingPathDelimiter(P)` | `PathEnsureSep(P)` | `nextpas.core.path` | ❌ |
| 20 | `ExcludeTrailingPathDelimiter(P)` | `PathTrimSep(P)` | `nextpas.core.path` | ❌ |
| 21 | `LastDelimiter(D,S)` | `LastDelimiter(D,S)` | `nextpas.core.path` | ✅ |
| 22 | `FileExists(F)` | `FsExists(F)` | `nextpas.core.fs.util` | ❌ |
| 23 | `DirectoryExists(D)` | `FsIsDir(D)` | `nextpas.core.fs.util` | ❌ |
| 24 | `ForceDirectories(D)` | `FsMkdirAll(D)` | `nextpas.core.fs.dir` | ❌ |
| 25 | `DeleteFile(F)` | `FsRemove(F)` | `nextpas.core.fs.dir` | ❌ |
| 26 | `FindFirst/Next/Close` | `FsOpenDir` + `IDirIterator` | `nextpas.core.fs.dir` | ❌ |
| 27 | `FileSearch(N,D)` | 内联实现 | — | ❌ |
| 28 | `GetEnvironmentVariable(N)` | `OsEnvGet(N)` | `nextpas.core.os.env` | ❌ |
| 29 | `ParamStr(I)` / `ParamCount` | FPC 内置 | — | — |
| 30 | `GetCurrentDir` | `FsGetCwd` | `nextpas.core.fs.util` | ❌ |

**同名 12 个** (切换 imports 即可) + **改名 17 个** + **特殊处理 1 个** (FileSearch)

### 迁移步骤

#### Step 1: rebuild-compiler.sh 加 core/src 路径
```bash
# 在 fpc 命令中加:
-Fu"$ROOT/core/src" \
-Fi"$ROOT/core/src" \
```

#### Step 2: 逐文件迁移（按依赖顺序）

**Phase A — stage0 包装层** (12 文件，低风险)

| 文件 | SysUtils 函数 | 迁移动作 |
|---|---|---|
| `tools/stage0/nextpas.pas` | ParamStr, ParamCount | 保留（FPC 内置） |
| `tools/stage0/target_config.pas` | ExpandFileName, ExtractFileDir, ExtractFileDrive, FileExists, GetEnvironmentVariable, IncludeTrailingPathDelimiter, LowerCase, SameText, Trim | → nextpas.core.path + fs.util + os.env + text.conv |
| `tools/stage0/nextpas_command_build.pas` | DirectoryExists, ExpandFileName, FileExists, ForceDirectories, GetEnvironmentVariable, IncludeTrailingPathDelimiter, IntToStr, ParamStr | → nextpas.core.{path,fs,os.env,text.conv} |
| `tools/stage0/nextpas_command_env.pas` | DeleteFile, DirectoryExists, ExpandFileName, ExtractFileDir, FileExists, ForceDirectories, IncludeTrailingPathDelimiter, LowerCase, ParamStr, StringReplace, Trim | → nextpas.core.{path,fs,os.env,text.conv} |
| `tools/stage0/nextpas_command_test.pas` | DirectoryExists, ExpandFileName, FileExists, GetCurrentDir, IncludeTrailingPathDelimiter, ParamStr | → nextpas.core.{path,fs.util} |
| `tools/stage0/nextpas_command_doctor.pas` | DirectoryExists, ExpandFileName, ParamStr | → nextpas.core.path |
| `tools/stage0/nextpas_command_pkg.pas` | DirectoryExists, ExpandFileName, ParamStr | → nextpas.core.path |
| `tools/stage0/nextpas_command_query.pas` | ExpandFileName, FileExists, ParamStr | → nextpas.core.{path,fs.util} |
| `tools/stage0/nextpas_projection_context.pas` | DirectoryExists, ExpandFileName, FileExists, IncludeTrailingPathDelimiter, Trim | → nextpas.core.{path,fs.util,text.conv} |
| `tools/stage0/nextpas_projection_json.pas` | IntToStr | → nextpas.core.text.conv |
| `tools/stage0/nextpas_projection_text.pas` | IntToStr | → nextpas.core.text.conv |
| `tools/stage0/nextpas_json_helpers.pas` | IntToStr | → nextpas.core.text.conv |

**Phase B — 编译器核心** (4 文件，需谨慎)

| 文件 | SysUtils 函数 | 迁移动作 |
|---|---|---|
| `compiler/toolchain/np_toolchain_runner.pas` | DeleteFile, DirectoryExists, ExpandFileName, ExtractFileDir, FileExists, FileSearch, FindFirst/Next/Close, ForceDirectories, GetEnvironmentVariable, IncludeTrailingPathDelimiter, IntToStr, SameText, Trim | 最复杂，FindFirst→IDirIterator 模式重写 |
| `compiler/toolchain/np_toolchain_profiles.pas` | ExpandFileName, ExtractFileDir, FileExists, IncludeTrailingPathDelimiter, LowerCase, Trim | → nextpas.core.{path,fs.util,text.conv} |
| `compiler/frontend/np_package_manifest.pas` | DirectoryExists, ExcludeTrailingPathDelimiter, ExpandFileName, ExtractFileDir, FileExists, IncludeTrailingPathDelimiter, LowerCase, Trim | → nextpas.core.{path,fs.util,text.conv} |
| `compiler/frontend/np_package_lock.pas` | ExpandFileName, FileExists, Trim, TryStrToInt | → nextpas.core.{path,fs.util,text.conv} |

**Phase C — 测试文件** (3 文件，字符串中的 SysUtils 引用)

| 文件 | 说明 |
|---|---|
| `compiler/tests/test_installed_target_unit_call_binding.pas` | 字符串 `'uses SysUtils;'` 是测试数据，保留 |
| `compiler/tests/test_parser_program_directive_uses_clause.pas` | 字符串 `'uses SysUtils;'` 是测试数据，保留 |
| `compiler/tests/test_semantic_reexported_type_member_call.pas` | 字符串引用，保留 |

#### Step 3: 验证
```bash
# 1. FPC 编译 stage0（加了 core/src 路径）
make rebuild-compiler

# 2. stage0 编译简单程序
build/stage0-bootstrap/nextpas build tests/compiler/pass/hello_pass.pas ...

# 3. stage0 编译自身 → stage2
# 4. stage2 编译自身 → stage3
# 5. stage3 SHA256 == stage2 SHA256（收敛）
```

#### Step 4: 删除 SysUtils shim
```bash
git rm units/linux-x86_64/SysUtils.pas
```

---

## R6.2: musl 目标支持

**目标**: `nextpas build --target linux-x86_64-musl` 产出无 glibc 依赖的静态 ELF

### 为什么 musl

| 场景 | glibc | musl |
|---|---|---|
| 容器镜像 | ~5MB glibc 层 | **0 依赖** |
| Alpine Linux | 不兼容 | **原生** |
| 嵌入式 | 太大 | **~1MB libc** |
| 静态链接 | 有 NSS/nsswitch 问题 | **干净静态** |
| 编译速度 | 正常 | **musl-gcc 更快** |

### 实现步骤

#### Step 1: 工具链发现
```bash
# 检测 musl 工具链
which musl-gcc           # Debian/Ubuntu: apt install musl-tools
which x86_64-linux-musl-gcc  # Alpine/cross: musl-cross-make
```

#### Step 2: 目标配置
创建 `build/targets/linux-x86_64-musl.toml`:
```toml
target = "linux-x86_64-musl"
host_os = "linux"
host_cpu = "x86_64"
compiler = "fpc"
units_dir = "units/linux-x86_64"
object_format = "elf"
assembler_flavor = "gnu-as"
linker_flavor = "gnu-ld"
llvm_triple = "x86_64-linux-musl"
c_library_naming = "lib-prefix-so-a"
# musl 特定: 静态链接优先
static_link = true
```

#### Step 3: 工具链绑定
创建 `build/toolchains/linux-x86_64-to-linux-x86_64-musl.toml`:
```toml
[binding]
id = "linux-x86_64-to-linux-x86_64-musl"
host_compiler = "musl-gcc"  # 或 x86_64-linux-musl-gcc
linker_flavor = "gnu-ld"
static_link = true
```

#### Step 4: 链接策略
```
musl-gcc -static -o output input.o -lc
```
产出完全静态的 ELF，无 `PT_INTERP`，无动态依赖。

#### Step 5: 验证
```bash
file output        # ELF 64-bit, statically linked
ldd output         # "not a dynamic executable"
./output           # 在 Alpine 容器中运行
```

---

## R6.3: 双目标自举验证

```
               ┌─ nextpas build --target linux-x86_64        → glibc ELF
stage0(FPC) ──┤
               └─ nextpas build --target linux-x86_64-musl   → musl ELF (静态)
```

两个目标都必须通过:
1. hello_pass 编译 + 运行
2. 编译器自身编译 (stage2)
3. stage2 编译自身 (stage3)
4. stage3 ≡ stage2 (收敛)

---

## 时间估算

| 阶段 | 任务 | 估时 |
|---|---|---|
| R6.1 Step 1 | rebuild-compiler.sh 加路径 | 10 min |
| R6.1 Step 2 Phase A | stage0 包装层迁移 (12 文件) | 2-3 hr |
| R6.1 Step 2 Phase B | 编译器核心迁移 (4 文件) | 2-3 hr |
| R6.1 Step 3 | 验证自举闭环 | 1 hr |
| R6.1 Step 4 | 删除 SysUtils shim | 10 min |
| R6.2 | musl 目标支持 | 2-3 hr |
| R6.3 | 双目标验证 | 1 hr |
| **总计** | | **~1-2 天** |

---

## 风险

| 风险 | 影响 | 缓解 |
|---|---|---|
| `nextpas.core.path` 的 `PathNormalize` 语义不同于 `ExpandFileName` | 路径解析错误 | 逐函数对比测试 |
| `FsOpenDir` API 模式不同于 `FindFirst/Next/Close` | np_toolchain_runner 重写 | 封装 helper |
| `FileSearch` 无 nextpas.core 等价物 | 仅 1 处使用 | 内联 10 行实现 |
| FPC 编译 nextpas.core 拉入过多依赖 | 编译时间增长 | 测量增量，按需裁剪 |
| musl-gcc 不可用 | 无法测试 | 先检查 `which musl-gcc` |
