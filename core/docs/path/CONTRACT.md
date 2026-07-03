# nextpas.core.path 代码契约

**模块路径**：`core/src/nextpas.core.path.pas`（1 个源文件）
**层级**：L1（依赖 L0: base; 委托 fs.path）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 模块定位

SysUtils 路径函数的替代品。委托给 `nextpas.core.fs.path`（后者调用 platform_path_*）。
适用于只需路径操作、不需要完整 fs 模块的场景。

### 1.2 核心函数

| 函数 | 说明 | SysUtils 等价 |
|------|------|---------------|
| `PathJoin(ABase, AChild): string` | 连接两段路径 | — |
| `PathJoin3(A, B, C): string` | 连接三段路径 | — |
| `PathDir(APath): string` | 目录部分 | ExtractFilePath |
| `PathName(APath): string` | 文件名（含扩展名） | ExtractFileName |
| `PathExt(APath): string` | 扩展名（含点） | ExtractFileExt |
| `PathBaseName(APath): string` | 文件名（不含扩展名） | — |
| `PathChangeExt(APath, AExt): string` | 更改扩展名 | ChangeFileExt |
| `PathIsAbsolute(APath): Boolean` | 是否绝对路径 | — |
| `PathNormalize(APath): string` | 规范化（消除 `.`/`..`） | — |

---

## 2. 不变量

- **[INV-1]** 同时处理 `/` 和 `\` 分隔符
- **[INV-2]** UTF-8 字符串安全
- **[INV-3]** 空路径返回空字符串

---

## 3. 错误处理

不抛异常。所有函数对空/无效输入返回空字符串或原样。

---

## 4-6. 概要

- **线程安全**: ✅ 纯函数
- **内存**: 返回新 string，调用方负责释放
- **测试**: 1 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
