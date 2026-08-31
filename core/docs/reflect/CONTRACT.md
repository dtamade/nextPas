# nextpas.core.reflect 代码契约

**模块路径**：`core/src/nextpas.core.reflect*.pas`（5 个源文件）
**层级**：L1（依赖 L0: base）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| reflect.base | TTypeDef, TFieldDef, TBaseTypeVisitor 基础类型 |
| reflect.intf | ITypeVisitor, ITypeRegistry 接口定义 |
| reflect.dynarray | 动态数组类型反射支持 |
| reflect.marshal | TConfigUnmarshalVisitor 配置反序列化 |
| reflect.pas | 门面 re-export |

### 1.2 核心接口

```pascal
ITypeVisitor = interface
  procedure VisitInteger(const ADef: TFieldDef; AValue: PInt64);
  procedure VisitString(const ADef: TFieldDef; AValue: PString);
  procedure VisitBoolean(const ADef: TFieldDef; AValue: PBoolean);
  procedure VisitFloat(const ADef: TFieldDef; AValue: PDouble);
  procedure VisitRecord(const ADef: TFieldDef; AData: Pointer);
  procedure VisitDynArray(const ADef: TFieldDef; AData: Pointer);
end;

ITypeRegistry = interface
  function FindByName(const AName: string): PTypeDef;
  procedure Register(const ADef: TTypeDef);
end;
```

### 1.3 核心类型

```pascal
TTypeDef = record
  Name: string;
  Size: SizeInt;
  Fields: array of TFieldDef;
end;

TFieldDef = record
  Name: string;
  Offset: SizeInt;
  BaseType: TBaseType;
end;
```

---

## 2. 不变量

- 类型名全局唯一（在同一 Registry 中）
- Field Offset 在 Record Size 范围内
- BaseType 枚举值有效

---

## 3. 错误处理

- 类型未找到返回 nil
- 注册重复类型抛 `EReflectError`

---

## 4. 线程安全

- ITypeRegistry 注册操作非线程安全
- 查询操作只读，线程安全

---

## 5. 内存管理

- TTypeDef/TFieldDef 是值类型
- ITypeRegistry 拥有注册的类型定义

---

## 6. 测试覆盖

- `test_reflect`: 类型注册/查找/Visit 访问/ConfigUnmarshal
