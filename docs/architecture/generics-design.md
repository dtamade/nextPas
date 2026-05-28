# nextPas 泛型系统设计

## 设计目标

- 兼容 FPC 的 `generic/specialize` 语法（向后兼容）
- 兼容 Delphi 的 `TList<T>` 语法（主推）
- 超越两者：约束组合、声明处型变、concept、关联类型、条件实现、特化

## 当前 Pascal 生态的问题

### FPC 泛型
- 需要 `specialize` 关键字，冗长
- 类型推断弱
- 不支持约束组合
- 错误信息差

### Delphi 泛型
- 约束系统有限（只有 class/record/constructor/interface）
- 不支持 concept/trait
- 不支持 variadic generics
- 不支持 specialization/partial specialization

## 分层路线图

| 阶段 | 内容 | 状态 |
|------|------|------|
| G1 | Delphi 兼容泛型 + 基础约束 | **已完成** |
| G2 | 约束组合 + where 子句 + 声明处型变 | **进行中** — class/record 约束已实现 |
| G3 | concept 定义 + 关联类型 + 条件实现 | 规划中 |
| G4 | 特化/偏特化 + reified（可选） | 规划中 |

## G1: 基础泛型

### 语法

```pascal
// 声明
type
  TList<T> = class
    procedure Add(Item: T);
    function Get(Index: Integer): T;
  end;

// 实例化（Delphi 风格，主推）
var List: TList<Integer>;

// 实例化（FPC 兼容）
var List: specialize TList<Integer>;

// 基础约束
type
  TSortedList<T: IComparable> = class
    procedure Add(Item: T);
  end;
```

### 实现要点

1. **Parser**：解析 `<T>` 类型参数列表，支持约束语法
2. **Semantic model**：`TSemanticType` 增加 `IsGeneric`、`TypeParams`、`Constraints`
3. **Instantiation**：遇到 `TList<Integer>` 时，用 Integer 替换 T 生成具体类型
4. **Member truth**：实例化后的类型有完整的 member 列表（方法签名中 T 被替换）
5. **Diagnostics**：约束不满足时发出 `sema.constraint-violation`

### 关键设计决策

- 实例化策略：**monomorphization**（每个具体类型生成独立代码），和 FPC/Delphi 一致
- 类型参数存储：在 `TSemanticType` 中用 `TypeParamNames: array of string` 和 `TypeParamConstraints: array of string`
- 实例化缓存：同一 `TList<Integer>` 只实例化一次，后续引用复用

## G2: 约束组合 + where 子句 + 声明处型变

### 语法

```pascal
// 约束组合
type
  TDict<K, V> = class
    where K: IComparable, IHashable;
    where V: class;
  end;

// 声明处型变
type
  IProducer<out T> = interface
    function Produce: T;
  end;

  IConsumer<in T> = interface
    procedure Consume(Item: T);
  end;
```

### 实现要点

- `where` 子句在类体开头，parser 在 class body 开始时检查
- 型变标记（in/out）存储在 type param metadata 中
- 赋值兼容性检查时考虑型变

## G3: Concept + 关联类型 + 条件实现

### 语法

```pascal
// concept 定义
type concept INumeric =
  class function Zero: Self;
  operator +(A, B: Self): Self;
  operator *(A, B: Self): Self;
end;

// 关联类型
type IIterator = interface
  type Item;
  function Next: Item;
  function HasNext: Boolean;
end;

// 条件实现
type TList<T> = class(IEquatable)
  where T: IEquatable;
  function Equals(Other: TList<T>): Boolean;
end;
```

## G4: 特化 + Reified

### 语法

```pascal
// 全特化
type TList<Integer> = class
  // 针对 Integer 的优化实现（如用连续内存）
end;

// 偏特化
type TList<T: class> = class
  // 针对所有 class 类型的实现（如用引用计数）
end;
```

## 不采用的特性

| 特性 | 来源 | 不采用原因 |
|------|------|-----------|
| Variadic generics | C++ | Pascal 语法不适合展开，复杂度爆炸 |
| Opaque types | Swift | Pascal 接口变量已覆盖此场景 |
| Star projection | Kotlin | Pascal 偏显式，通配符与哲学冲突 |
| SFINAE | C++ | hack 式设计，concept 已是替代品 |

## 从其他语言吸收的创新

| 特性 | 来源 | Pascal 适配 |
|------|------|------------|
| trait bounds 组合 | Rust | `where T: A, B` |
| 声明处型变 | Kotlin | `<out T>` / `<in T>` |
| conditional conformance | Swift | `where T: IEquatable` 条件实现 |
| associated types | Rust/Swift | `type Item` 在 interface 中 |
| concepts | C++20 | `type concept ... end` 块 |
| reified generics | Kotlin | 运行时类型信息保留（LLVM 支持） |
