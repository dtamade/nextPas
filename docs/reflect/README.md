# nextpas.core.reflect

运行时类型注册表——字段级反射 + visitor 模式遍历。

## 概述

提供运行时类型信息注册、查找和字段访问能力。通过 visitor 模式按字段类型分派，
支持序列化、JSON 导出、diff/patch、调试检查等场景。

## 层级

L1（基础设施）

## 快速开始

```pascal
uses
  nextpas.core.reflect;

type
  TPlayer = packed record
    X, Y: Single;
    HP: Int32;
    Alive: Boolean;
  end;

var
  LReg: ITypeRegistry;
  LID: TTypeID;
  LData: TPlayer;
  LPtr: PSingle;
begin
  LReg := CreateTypeRegistry;
  LID := LReg.RegisterType('Player', SizeOf(TPlayer));
  LReg.AddField(LID, 'X', PtrUInt(@TPlayer(nil^).X), fkFloat32);
  LReg.AddField(LID, 'Y', PtrUInt(@TPlayer(nil^).Y), fkFloat32);
  LReg.AddField(LID, 'HP', PtrUInt(@TPlayer(nil^).HP), fkInt32);
  LReg.AddField(LID, 'Alive', PtrUInt(@TPlayer(nil^).Alive), fkBool);

  LData.X := 100.0;
  LPtr := PSingle(LReg.GetFieldPtr('Player', 'X', @LData));
  // LPtr^ = 100.0
end;
```

## API

### 工厂

| 函数 | 说明 |
|------|------|
| `CreateTypeRegistry` | 创建 ITypeRegistry 实例 |

### ITypeRegistry

| 方法 | 说明 |
|------|------|
| `RegisterType(Name, Size)` | 注册类型，返回 TTypeID |
| `AddField(TypeID, Name, Offset, Kind, Size, Flags)` | 添加字段定义 |
| `FindType(Name)` | 按名称查找类型定义 |
| `FindTypeByID(ID)` | 按 ID 查找 |
| `HasType(Name)` | 检查类型是否已注册 |
| `GetTypeID(Name)` | 获取类型 ID |
| `GetFieldDef(TypeName, FieldName)` | 获取字段定义 |
| `GetFieldPtr(TypeName, FieldName, Data)` | 获取字段指针 |
| `Visit(TypeDef, Data, Visitor)` | visitor 模式遍历所有字段 |
| `GetTypeCount` | 已注册类型数量 |

### ITypeVisitor

| 方法 | 说明 |
|------|------|
| `BeginType/EndType` | 类型遍历开始/结束 |
| `ShouldVisit(Field)` | 过滤字段 |
| `VisitBool/Int32/Int64/...` | 按类型分派的访问方法 |

### TBaseTypeVisitor

空实现基类，子类按需覆盖感兴趣的方法。

## 字段类型

`fkBool`, `fkInt8..fkInt64`, `fkUInt8..fkUInt64`, `fkFloat32`, `fkFloat64`,
`fkString`, `fkEnum`, `fkRecord`, `fkDynArray`, `fkPointer`

## 字段标记

`ffTransient`（不序列化）, `ffReadOnly`（只读）, `ffNetSync`（网络同步）

## 设计决策

- **接口化**：ITypeRegistry 允许多实例（测试隔离）
- **固定容量**：512 类型 × 32 字段，无动态分配
- **自动推断大小**：基本类型无需手动指定 Size
- **重复注册安全**：返回已有 ID，不报错
