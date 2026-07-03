# nextpas.core.system 代码契约

**模块路径**：`core/src/nextpas.core.system*.pas`（6 个源文件）
**层级**：L0（根模块，依赖 FPC RTL）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| system.pas | 根门面，re-export 基础类型/常量/运行时契约 |
| system.contracts | 运行时契约常量（np.system.*） |
| system.memmanager | 内存管理器集成 |
| system.classes | Classes 最小门面 |
| system.sysutils | SysUtils 最小门面 |
| system.typinfo | TypInfo 最小门面 |

### 1.2 运行时契约

```pascal
const
  NEXTPAS_SYSTEM_NAME = 'nextpas.core.system';
  np_system_process_init = 'np.system.process_init';
  np_system_process_fini = 'np.system.process_fini';
  np_system_object_free = 'np.system.object_free';
```

### 1.3 基础类型 Re-export

```pascal
// 从 nextpas.core.base re-export
SizeInt = nextpas.core.base.SizeInt;
SizeUInt = nextpas.core.base.SizeUInt;
PtrInt = nextpas.core.base.PtrInt;
TBytes = nextpas.core.base.TBytes;
TStringArray = nextpas.core.base.TStringArray;
```

---

## 2. 不变量

- system.pas 不实现逻辑，只 re-export
- 运行时契约名称全局稳定，编译器使用这些名称
- 所有类型来自 owner 模块，不重复定义

---

## 3. 错误处理

- system.pas 无错误处理逻辑
- 错误处理委托给 owner 模块

---

## 4. 线程安全

- Re-export 的类型由 owner 模块保证线程安全

---

## 5. 内存管理

- 内存管理委托给 nextpas.core.mem

---

## 6. 测试覆盖

- `test_system_facade`: 门面完整性测试
- `test_system_source_contracts`: 源契约边界检查
- `test_system_typinfo_minimal`: TypInfo 门面测试
- `test_system_sysutils_minimal`: SysUtils 门面测试
