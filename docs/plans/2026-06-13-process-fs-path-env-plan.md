# process/fs/path/env 模块修复执行计划

> **For Claude:** 先按本计划恢复编译与 focused gate，再进入封装整改。不要把 `FsTempFile` 降回 legacy `Int32 fd` seam。

**Goal:** 先恢复 `fs` / `process` focused gates 的可编译状态，再完成 process 封装修复和 fs 安全/文本契约补强。

**Architecture:** 四阶段推进：
1. `P0` 恢复编译
2. `P1` process 正确性与封装
3. `P1/P2` fs 安全与遍历契约
4. `P2/P3` text/path/owner 收尾

**Hard Rules:**
- `FsTempFile` 必须继续走 typed handle seam：`platform_fs_mktemp_handle` + `FsFromPlatformHandle`
- 不要把 `platform_fs_is_executable` 在 Windows 上实现成 “regular file 即 true”
- `TChild.Destroy` 不能因为公开 `Kill`/`Wait` 改成抛错而开始抛异常

---

## 阶段一：P0 恢复 focused gate 编译

### 任务 1.1：补回 `platform_fs_mktemp_handle` typed seam

**文件：**
- 修改: `core/src/nextpas.core.platform.fs.pas`
- 验证: `core/src/nextpas.core.fs.util.pas`
- 验证: `core/tests/nextpas.core.fs/test_fs/test_fs.lpr`

**为什么先做：**
- `test_fs` / `test_fs_text` 当前都卡在这里
- 现有 `FsTempFile` source-contract 明确禁止回退到 `platform_fs_mktemp` + `FsFromHandle`

**实现要求：**
- 在 `platform.fs` interface 新增：
```pascal
function platform_fs_mktemp_handle(const APrefix: PAnsiChar; const ASuffix: PAnsiChar;
  APathBuf: PAnsiChar; APathBufLen: Int32; out AHandle: TPlatformFileHandle): Int32;
```
- implementation 里直接返回 `TPlatformFileHandle`
- `platform_fs_mktemp` 如继续保留，也不能成为 `FsTempFile` 的 system-temp 路径入口

**Acceptance:**
- `core/src/nextpas.core.fs.util.pas` 继续包含 `platform_fs_mktemp_handle`
- `core/src/nextpas.core.fs.util.pas` 继续包含 `FsFromPlatformHandle`
- `test_fs` 中 `TestTempFileSystemDirUsesTypedHandleContract` 继续成立

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

---

### 任务 1.2：补齐 `platform_fs_is_executable`

**文件：**
- 修改: `core/src/nextpas.core.platform.fs.pas`
- 验证: `core/src/nextpas.core.process.pathresolve.pas`

**实现要求：**
- 在 `platform.fs` 暴露统一 helper：
```pascal
function platform_fs_is_executable(const APath: PAnsiChar): Boolean;
```
- Unix:
  - `stat` 成功
  - regular file
  - 任一执行位存在
- Windows:
  - 不能 blanket `True`
  - 必须与当前 `ResolveExecutablePath` / `PATHEXT` 语义一致
  - 至少应拒绝明显的非可执行扩展名

**建议实现方向：**
- Windows 侧若 path 已带扩展名，则检查是否属于可执行扩展集合
- 未带扩展名的候选仍由 `ResolveExecutablePath` 的 `PATHEXT` 扩展枚举负责

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process
```

---

### 任务 1.3：修正 `platform.error` 对不存在单元的依赖

**文件：**
- 修改: `core/src/nextpas.core.platform.error.pas`

**默认方案：**
- 直接让 `platform.error` uses `nextpas.core.platform.sync.base`

**备选方案：**
- 仅当明确需要建立 `platform.error.base` carrier 时，才新增 shim 单元

**理由：**
- 当前仓库里 `PLATFORM_ERR_*` 的真实 owner 是 `platform.sync.base`
- 直接修 phantom dependency 比新造一层壳更小、更真实

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
```

---

### 阶段一收口验证

```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
```

目标：四个 gate 全部进入可编译/可运行状态。

---

## 阶段二：P1 process 正确性与封装

### 任务 2.1：`TChild.Wait` / `TryWait` / `Kill` 返回码传播

**文件：**
- 修改: `core/src/nextpas.core.process.child.pas`

**实现要求：**
- 增加统一 helper，例如：
```pascal
procedure RaiseProcessPlatformError(const AOp: string; ACode: Int32);
```
- `Wait` / `TryWait` / `Kill` 不再静默忽略平台返回码
- timeout path 里 `kill + wait` 也必须走同一错误传播

**额外要求：**
- `TChild.Destroy` 不能直接依赖会抛错的公有 `Kill`
- 析构清理保留 best-effort 语义，不把 cleanup error 变成析构异常

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_deep
```

---

### 任务 2.2：`WaitWithOutput` 收口 drain seam

**文件：**
- 修改: `core/src/nextpas.core.process.child.pas`
- 修改: `core/src/nextpas.core.process.pipe.pas`

**实现要求：**
- 把 raw `poll/read` 逻辑从 `process.child` 移走
- `process.child` 不再直接 uses `platform.posix.base` / `platform.posix.ffi`
- 允许在 `process.pipe` 内保留平台分支，但要通过显式 seam 暴露给 `child`
- `poll < 0` / `read < 0` 必须区分 `EINTR` / `EAGAIN` 与真实失败

**建议 seam：**
- `TPipeReader` 暴露最小 native-handle contract
- `DrainPipePair(...)` 由 `process.pipe` 拥有

**同时修正：**
- `TChild` 内部 close stdin 不再 concrete-cast `TPipeWriter` 才能工作

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_deep
```

---

### 任务 2.3：`TCommand.Spawn` 平台化 pipe/null/close

**文件：**
- 修改: `core/src/nextpas.core.process.command.pas`
- 修改: `core/src/nextpas.core.platform.process.pas`

**问题边界：**
- 当前 `command.pas` 直接依赖 `pipe()`
- 直接 `open('/dev/null')`
- 直接 `close()`
- 这让 L2 builder 被锁死在 POSIX

**实现要求：**
- 在 `platform.process` 增加 pipe/null/close 准备 helper
- `command.pas` 删除对 `platform.posix.*` 的直接依赖
- 继续复用现有 `platform_process_spawn_fds`

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_deep
```

---

## 阶段三：fs 安全与遍历契约

### 任务 3.1：`FsRemoveAll` 根路径保护

**文件：**
- 修改: `core/src/nextpas.core.fs.dir.pas`
- 修改: `core/src/nextpas.core.platform.path.pas`

**实现要求：**
- 在 `platform.path` 暴露 public root helper，例如：
```pascal
function platform_path_is_root(const APath: PAnsiChar): Boolean;
```
- `FsRemoveAll` 统一用 normalized path 做 root 判定
- 必须覆盖：
  - Unix `/`
  - Windows `C:\` / `C:/`
  - UNC share root
  - extended drive root

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.platform.path/test_platform_path
```

---

### 任务 3.2：`FsWalk` 错误回调补全

**文件：**
- 修改: `core/src/nextpas.core.fs.dir.pas`

**实现要求：**
- `FsOpenDir` 失败走 callback
- `LIter.Next` 失败走 callback
- iterator close 放进 `finally`
- 维持现有 `TWalkFunc` 契约：错误通过 `AErr` 返回，不是中途裸异常

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

---

### 任务 3.3：`FsRemoveAll` / `FsWalk` child path 统一走 path owner

**文件：**
- 修改: `core/src/nextpas.core.fs.dir.pas`

**实现要求：**
- 替换 `APath + '/' + LEntry.Name`
- 使用 `FsPathJoin([APath, LEntry.Name])` 或局部 helper

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
```

---

## 阶段四：text/path/owner 收尾

### 任务 4.1：`FsReadFileText` BOM 剥离 + UTF-8 校验

**文件：**
- 修改: `core/src/nextpas.core.fs.util.pas`

**实现要求：**
- UTF-8 BOM 自动剥离
- 非法 UTF-8 抛异常
- text API 保持“只接受/返回 UTF-8 text”，二进制内容继续走 `ReadFile`

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
```

---

### 任务 4.2：text write helper 去重

**文件：**
- 修改: `core/src/nextpas.core.fs.pas`

**实现要求：**
- 抽 `Utf8TextToBytes`
- `WriteFileText` / `AppendFileText` / `WriteFileLines` 复用
- 这是去重和可读性优化，不改变 public behavior

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
```

---

### 任务 4.3：`PATH=` / `PATHEXT=` prefix 常量化

**文件：**
- 修改: `core/src/nextpas.core.process.pathresolve.pas`

**实现要求：**
- 只做常量化和可读性整理
- 不改变当前行为

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.process/test_process
```

---

### 任务 4.4：`FsCopyFile` owner 收敛

**文件：**
- 修改: `core/src/nextpas.core.fs.util.pas`

**实现要求：**
- 目标是把 copy 逻辑收口到 `platform.fs`
- 不是为吞吐做先验优化
- 若切换到底层 helper，会同步保留 permission/错误语义

**验证：**
```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs
```

---

## 建议测试顺序

```bash
make focused FOCUS=core/tests/nextpas.core.fs/test_fs
make focused FOCUS=core/tests/nextpas.core.fs/test_fs_text
make focused FOCUS=core/tests/nextpas.core.process/test_process
make focused FOCUS=core/tests/nextpas.core.process/test_process_pipe_contract
make focused FOCUS=core/tests/nextpas.core.process/test_process_deep
```

按需补：

```bash
make focused FOCUS=core/tests/nextpas.core.platform.path/test_platform_path
make focused FOCUS=core/tests/nextpas.core.platform.error/test_platform_error
make focused FOCUS=core/tests/nextpas.core.platform.fs/test_platform_fs
```

---

## 质量门禁

- 每阶段结束至少跑对应 focused gates
- `git diff --check`
- `make hygiene`
- 不吞并无关改动
- `Ready` 时单独列出 cross-module touched files 与额外验证
