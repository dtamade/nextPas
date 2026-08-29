# nextpas.core.system 代码契约

**模块路径**：`core/src/nextpas.core.system*.pas`（8 个源文件）
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
| system.heap | 堆原语封装（GetMem/FreeMem/ReallocMem/Move 唯一所有者） |
| system.errors | 异常分类门面（38 exception + 18 error category） |
| system.classes | Classes 最小门面 |
| system.sysutils | SysUtils 兼容薄门面（文本 API 实现 owner = `text.conv`，非本单元） |
| system.typinfo | TypInfo 最小门面 |

### 1.2 运行时契约

> 契约常量来源：`core/src/nextpas.core.system.contracts.pas`（28 个）

```pascal
const
  NPSYSTEM_PROCESS_INIT = 'np.system.process_init';
  NPSYSTEM_PROCESS_FINI = 'np.system.process_fini';
  NPSYSTEM_UNIT_INIT = 'np.system.unit_init';
  NPSYSTEM_UNIT_FINI = 'np.system.unit_fini';
  NPSYSTEM_HALT = 'np.system.halt';
  NPSYSTEM_STRING_INIT = 'np.system.string_init';
  NPSYSTEM_STRING_FINI = 'np.system.string_fini';
  NPSYSTEM_STRING_ASSIGN = 'np.system.string_assign';
  NPSYSTEM_DYNARRAY_INIT = 'np.system.dynarray_init';
  NPSYSTEM_DYNARRAY_FINI = 'np.system.dynarray_fini';
  NPSYSTEM_DYNARRAY_SET_LENGTH = 'np.system.dynarray_set_length';
  NPSYSTEM_INTERFACE_ADDREF = 'np.system.interface_addref';
  NPSYSTEM_INTERFACE_RELEASE = 'np.system.interface_release';
  NPSYSTEM_MANAGED_RECORD_INIT = 'np.system.managed_record_init';
  NPSYSTEM_MANAGED_RECORD_FINI = 'np.system.managed_record_fini';
  NPSYSTEM_HEAP_ALLOC = 'np.system.heap_alloc';
  NPSYSTEM_HEAP_FREE = 'np.system.heap_free';
  NPSYSTEM_OBJECT_ALLOC = 'np.system.object_alloc';
  NPSYSTEM_OBJECT_FREE = 'np.system.object_free';
  NPSYSTEM_OBJECT_FREE_DESTROY = 'np.system.object_free.destroy';
  NPSYSTEM_OBJECT_FREE_CLEANUP = 'np.system.object_free.cleanup';
  NPSYSTEM_OBJECT_FREE_RELEASE = 'np.system.object_free.release';
  NPSYSTEM_RUNTIME_FAULT = 'np.system.runtime_fault';
  NPSYSTEM_EXCEPTION_TRY_PUSH = 'np.system.exception_try_push';
  NPSYSTEM_EXCEPTION_TRY_POP = 'np.system.exception_try_pop';
  NPSYSTEM_EXCEPTION_RAISE = 'np.system.exception_raise';
  NPSYSTEM_EXCEPTION_FINALLY_END = 'np.system.exception_finally_end';
  NPSYSTEM_EXCEPTION_EXCEPT_END = 'np.system.exception_except_end';
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
