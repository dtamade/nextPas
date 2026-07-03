# nextpas.core.git 代码契约

**模块路径**：`core/src/nextpas.core.git*.pas`（7 个源文件）
**层级**：L2（依赖 L0: base, text, fs）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| git.base | TGitStatusEntry, TGitStatusFilter 基础类型 |
| git.intf | IGitManager, IGitRepository, IGitCommit 等接口定义 |
| git.libgit2 | libgit2 集成门面 |
| git.libgit2.ffi | libgit2 C FFI 绑定 |
| git.libgit2.binding | libgit2 函数指针绑定 |
| git.libgit2.backend | libgit2 后端实现 |
| git.pas | 门面 re-export |

### 1.2 核心接口

```pascal
IGitManager = interface
  function OpenRepository(const APath: string): IGitRepository;
  function IsGitRepository(const APath: string): Boolean;
  procedure InitRepository(const APath: string; ABare: Boolean);
end;

IGitRepository = interface
  function Status: TGitStatusEntryArray;
  function Head: IGitReference;
  function LookupCommit(const AId: string): IGitCommit;
  procedure Close;
end;

IGitCommit = interface
  function Id: string;
  function Message: string;
  function Author: string;
  function Timestamp: TInstant;
end;
```

### 1.3 核心类型

```pascal
TGitStatusEntry = record
  Path: string;
  IndexStatus: TGitStatusKind;
  WorkdirStatus: TGitStatusKind;
end;
```

---

## 2. 不变量

- IGitRepository 拥有 libgit2 仓库句柄
- Close 后不可再使用
- Commit ID 为 40 字符十六进制字符串

---

## 3. 错误处理

- 仓库不存在抛 `EGitError`
- libgit2 错误抛 `EGitError`（含错误码）

---

## 4. 线程安全

- IGitManager 线程安全
- IGitRepository 非线程安全

---

## 5. 内存管理

- IGitRepository.Close 释放 libgit2 资源
- IGitManager 拥有 libgit2 全局状态

---

## 6. 测试覆盖

- `test_git`: Status/Head/LookupCommit/Init/IsGitRepository
