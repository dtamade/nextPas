# nextpas.core.system Dynamic Array Lifecycle

本规范定义动态数组的内存布局、引用计数、写时复制（COW）和生命周期管理。

## 1. 内存布局

### 1.1 堆布局

```
offset -8:  RefCount (4 bytes, signed Int32)
offset -4:  Length (4 bytes, signed Int32, in elements)
offset  0:  Data (Length * ElSize bytes)
```

- `RefCount`：引用计数，-1 表示唯一引用（不需要计数）
- `Length`：元素个数（不是字节数）
- `Data`：元素数据，按元素类型对齐

### 1.2 变量布局

动态数组变量是一个指针（8 bytes on 64-bit），指向堆数据的 `offset 0`（Data 起始位置）。

```pascal
var
  LArr: TBytes;  // LArr 是一个 Pointer，指向堆数据
```

- 空数组：`LArr = nil`
- 非空数组：`LArr = @Data[0]`

### 1.3 对齐

元素对齐 = `Min(SizeOf(Element), 16)`

- `Byte`：1 字节对齐
- `LongInt`：4 字节对齐
- `Int64`：8 字节对齐
- `record`：最大字段对齐（最大 16 字节）

## 2. 引用计数

### 2.1 引用计数规则

- 新创建的数组：`RefCount = -1`（唯一引用，不需要计数）
- 赋值给另一个变量：`RefCount` 递增
- 变量离开作用域或被赋值：`RefCount` 递减
- `RefCount = 0`：释放堆内存

### 2.2 唯一引用优化

当 `RefCount = -1` 时，表示数组是唯一引用，不需要引用计数开销。

```pascal
var
  A, B: TBytes;
begin
  SetLength(A, 100);     // A.RefCount = -1（唯一引用）
  B := A;                // A.RefCount = 1, B.RefCount = 1（共享）
  A := nil;              // B.RefCount = -1（唯一引用）
end;
```

### 2.3 引用计数操作

编译器生成的 fpc_* 函数：

| 函数 | 语义 |
|------|------|
| `np_dynarray_incr_ref` | 递增引用计数 |
| `np_dynarray_decr_ref` | 递减引用计数，如果为 0 则释放 |
| `np_dynarray_unique` | 确保唯一引用（COW 前置） |
| `np_dynarray_assign` | 赋值（释放旧的，递增新的） |

## 3. 写时复制（COW）

### 3.1 COW 规则

当多个变量共享同一数组时，修改操作会触发复制：

1. 检查是否是唯一引用（`RefCount = -1`）
2. 如果不是唯一引用，复制数据
3. 修改复制后的数据

### 3.2 触发 COW 的操作

- `SetLength`：修改长度
- 直接赋值元素：`Arr[Index] := Value`
- `Delete`/`Insert`：修改数组结构

### 3.3 COW 示例

```pascal
var
  A, B: TBytes;
begin
  SetLength(A, 100);     // A 是唯一引用
  B := A;                // A 和 B 共享数据

  // 此时修改 A 会触发 COW
  A[0] := $FF;           // 编译器调用 np_dynarray_unique(A)
                          // 复制数据，然后修改

  // B[0] 仍然是 0（未被修改）
  Assert(B[0] = 0);
end;
```

### 3.4 避免不必要的 COW

```pascal
var
  A, B: TBytes;
begin
  SetLength(A, 100);

  // ✅ 正确：先断开共享，再修改
  B := A;
  A := nil;              // 断开共享
  SetLength(A, 100);     // 创建新数组
  A[0] := $FF;           // 不会触发 COW

  // ❌ 低效：频繁触发 COW
  B := A;
  for I := 0 to 99 do
    A[I] := I;           // 每次赋值都触发 COW
end;
```

## 4. 生命周期管理

### 4.1 创建

```pascal
var
  LArr: TBytes;
begin
  SetLength(LArr, 100);  // 分配 100 字节
  // LArr.RefCount = -1
  // LArr.Length = 100
end;
```

### 4.2 复制

```pascal
var
  A, B: TBytes;
begin
  SetLength(A, 100);
  B := Copy(A);          // 深拷贝
  // A 和 B 是独立的数组
  // A.RefCount = -1, B.RefCount = -1
end;
```

### 4.3 释放

```pascal
var
  LArr: TBytes;
begin
  SetLength(LArr, 100);
  // ... 使用 LArr
  LArr := nil;           // 释放数组
  // 或者
  SetLength(LArr, 0);   // 等效于 LArr := nil
end;
```

### 4.4 自动释放

```pascal
procedure DoSomething;
var
  LArr: TBytes;
begin
  SetLength(LArr, 100);
  // ... 使用 LArr
end;  // LArr 离开作用域，自动释放
```

## 5. 编译器生成的代码

### 5.1 SetLength

```pascal
// SetLength(Arr, NewLen)
// 编译为：
np_dynarray_setlength(@Arr, NewLen, TypeInfo(T));
```

### 5.2 赋值

```pascal
// ArrB := ArrA
// 编译为：
np_dynarray_assign(@ArrB, @ArrA);
```

### 5.3 元素赋值

```pascal
// Arr[Index] := Value
// 编译为：
np_dynarray_unique(@Arr);  // 确保唯一引用
Arr[Index] := Value;
```

### 5.4 释放

```pascal
// Arr := nil
// 编译为：
np_dynarray_decr_ref(@Arr);
Arr := nil;
```

## 6. np_dynarray_* 函数参考

| 函数 | 签名 | 语义 |
|------|------|------|
| `np_dynarray_incr_ref` | `function(S: Pointer): Pointer` | 递增引用计数 |
| `np_dynarray_decr_ref` | `function(S: Pointer): Pointer` | 递减引用计数，释放时返回 nil |
| `np_dynarray_assign` | `function(Dest, Src: Pointer): Pointer` | 赋值（释放旧的，递增新的） |
| `np_dynarray_length` | `function(S: Pointer): SizeInt` | 返回数组长度 |
| `np_dynarray_setlength` | `function(S: Pointer; NewLen: SizeInt; TypeInfo: Pointer): Pointer` | 设置长度（可能触发 COW） |
| `np_dynarray_unique` | `function(S: Pointer): Pointer` | 确保唯一引用 |
| `np_dynarray_copy` | `function(S: Pointer; Index, Count: SizeInt; TypeInfo: Pointer): Pointer` | 复制子数组 |
| `np_dynarray_delete` | `function(S: Pointer; Index, Count: SizeInt): Pointer` | 删除元素 |
| `np_dynarray_insert` | `function(S: Pointer; Sub: Pointer; Index: SizeInt): Pointer` | 插入元素 |
| `np_dynarray_pos` | `function(Sub, S: Pointer): SizeInt` | 查找元素位置 |
| `np_dynarray_get` | `function(S: Pointer; Index: SizeInt): Pointer` | 获取元素指针 |
| `np_dynarray_put` | `function(S: Pointer; Index: SizeInt; Value: Pointer): Pointer` | 设置元素 |

## 7. 常见问题

### 7.1 为什么 B := A 后修改 A 会影响 B？

这是写时复制（COW）的正常行为。赋值只是共享数据，修改时才复制。

```pascal
var A, B: TBytes;
begin
  SetLength(A, 100);
  B := A;          // 共享数据
  A[0] := $FF;     // 触发 COW，A 复制数据
  Assert(B[0] = 0); // B 不受影响
end;
```

### 7.2 如何避免 COW 开销？

1. 使用 `Copy` 创建独立副本
2. 先断开共享，再修改
3. 使用 `np_dynarray_unique` 显式确保唯一引用

### 7.3 空数组和 nil 的区别？

- `nil`：未分配，不占用内存
- 空数组（`SetLength(Arr, 0)`）：可能分配了堆头部（RefCount/Length）

```pascal
var A: TBytes;
begin
  A := nil;           // A = nil
  SetLength(A, 0);    // A 可能 <> nil（取决于实现）
  A := nil;           // A = nil
end;
```

### 7.4 动态数组可以存储接口吗？

可以，但需要注意引用计数：

```pascal
var
  LArr: array of IMyInterface;
begin
  SetLength(LArr, 10);
  LArr[0] := TMyClass.Create;  // 接口引用计数 +1
  // 数组释放时，接口引用计数 -1
end;
```

## 8. 最佳实践

### 8.1 使用规则

1. 使用 `SetLength` 而不是手动分配内存
2. 使用 `Copy` 创建独立副本
3. 使用 `nil` 释放数组
4. 避免在循环中频繁触发 COW

### 8.2 性能优化

1. 预分配足够容量：`SetLength(Arr, ExpectedSize)`
2. 使用 `Copy` 而不是循环赋值
3. 避免不必要的共享

### 8.3 内存管理

1. 数组离开作用域自动释放
2. 不需要手动释放（除非提前释放）
3. 使用 `nil` 提前释放

## 9. 参考资料

| 文档 | 用途 |
|------|------|
| `abi-specification.md` | 动态数组内存布局 |
| `api-reference.md` | np_dynarray_* 函数清单 |
| `design-decisions.md` | DD-4 fpc_* 函数设计 |
| `runtime-contracts.md` | np.system.dynarray_* 契约 |
