# <模块名> 代码契约

> 模块路径: `core/src/nextpas.core.<module>.pas`
> 创建日期: YYYY-MM-DD
> 维护者: AI / 开发者

---

## 概述

简述模块职责和设计目标。

---

## 接口签名

### 类型定义

```pascal
type
  IMyInterface = interface
    function GetData: TBytes;
    procedure SetData(const AValue: TBytes);
    property Data: TBytes read GetData write SetData;
  end;
```

### 函数/过程

```pascal
function ProcessData(const AInput: TBytes): TBytes;
```

**参数说明**:
- `AInput`: 输入数据，必须非空

**返回值**: 处理后的数据

---

## 前置条件

1. 输入数据必须非空
2. 数据长度不超过 1MB

---

## 后置条件

1. 返回数据长度等于输入长度
2. 返回数据不为 nil

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 输入为空 | 抛出 EInvalidInput |
| 数据过大 | 抛出 EDataTooLarge |

---

## 线程安全

- 默认不线程安全
- 需要并发访问时使用 sync 模块保护

---

## 内存管理

- 返回的数据由调用方负责释放
- 接口类型走引用计数自动管理

---

## 测试覆盖

### 单元测试

```pascal
procedure TestProcessData_NormalInput;
procedure TestProcessData_EmptyInput;
procedure TestProcessData_LargeInput;
```

### 边界测试

```pascal
procedure TestProcessData_MaxSize;
procedure TestProcessData_ZeroLength;
```

---

## 依赖关系

- 依赖: nextpas.core.base
- 被依赖: nextpas.core.crypto

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| YYYY-MM-DD | 初始版本 | 模块创建 |

