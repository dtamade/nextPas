# nextpas.core.gpu 代码契约

**模块路径**：`core/src/nextpas.core.gpu.gl*.pas`（2 个源文件）
**层级**：L2（依赖 L0: base, platform）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| gpu.gl.ffi | OpenGL 类型定义（GLenum, GLint, GLuint 等）+ FFI 绑定声明 |
| gpu.gl | GL 函数指针加载/卸载（gl_load, gl_unload, gl_is_loaded） |

### 1.2 核心 API

```pascal
function gl_load: Int32;       // 加载 GL 函数指针，返回 0 成功
procedure gl_unload;           // 卸载 GL 函数指针
function gl_is_loaded: Boolean; // 是否已加载
```

| 函数 | 前置条件 | 后置条件 | 异常 |
|------|----------|----------|------|
| `gl_load` | glX 可用 | 返回 0 或错误码，函数指针可用 | 不抛异常 |
| `gl_unload` | 无 | 释放所有函数指针 | 不抛异常 |
| `gl_is_loaded` | 无 | 返回加载状态 | 不抛异常 |

### 1.3 GL 类型

```pascal
GLenum = type UInt32;   GLboolean = type Byte;
GLint = type Int32;     GLuint = type UInt32;
GLsizei = type Int32;   GLfloat = type Single;
GLsizeiptr = type Int64;
```

---

## 2. 不变量

- 引用计数 `GRefCount` 管理加载/卸载生命周期
- `gl_load` 幂等：多次调用只增引用计数
- `gl_unload` 减引用计数，归零时真正卸载

---

## 3. 错误处理

- `gl_load` 返回错误码（`GL_ERR_NOT_LOADED`, `GL_ERR_LOAD_FAILED`）
- 不抛异常

---

## 4. 线程安全

- 引用计数使用 `InterLockedIncrement`/`InterLockedDecrement`，线程安全

---

## 5. 内存管理

- 函数指针由 `glXGetProcAddress` 获取，无需手动释放
- `gl_unload` 将所有指针置 nil

---

## 6. 测试覆盖

- 平台特化模块，测试需要 GL 上下文，暂无自动化测试
