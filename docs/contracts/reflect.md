# nextpas.core.reflect 代码契约

> 模块路径: `core/src/nextpas.core.reflect.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

运行时类型反射。提供类型注册表、字段描述和 visitor 模式遍历。

---

## 关键接口

```pascal
type
  TTypeID = UInt32;
  TFieldKind = (fkInteger, fkFloat, fkString, fkBool, fkObject, fkArray, fkRecord);
  TFieldDef = record ... end;
  TTypeDef = record ... end;
  ITypeVisitor = interface
    procedure BeginType(ATypeDef: PTypeDef; AData: Pointer);
    procedure EndType;
    procedure VisitField(AFieldDef: PFieldDef; AData: Pointer);
  end;
  ITypeRegistry = interface
    procedure Register(ATypeDef: PTypeDef);
    function Find(ATypeID: TTypeID): PTypeDef;
    procedure Accept(AVisitor: ITypeVisitor; AData: Pointer);
  end;

function CreateTypeRegistry: ITypeRegistry;
```

---

## 线程安全

- ITypeRegistry 注册阶段不线程安全
- 查询阶段线程安全

---

## 依赖关系

- 依赖: base
- 被依赖: json marshal, 序列化

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
