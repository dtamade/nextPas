# nextpas.core.multipart 代码契约

**模块路径**：`core/src/nextpas.core.multipart*.pas`（2 个源文件）
**层级**：L2（依赖 L0: base, text, bytes）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-30
**版本**：1.1

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| multipart.base | TMultipartHeader, TMultipartPart 记录类型 |
| multipart.pas | multipart/form-data 解析/序列化 |

### 1.2 核心类型

```pascal
TMultipartHeader = record
  Name: string;
  Value: string;
  Params: TStringArray;
end;

TMultipartPart = record
  Headers: array of TMultipartHeader;
  Body: TBytes;
end;
```

### 1.3 核心函数

```pascal
function ParseMultipart(const ABoundary: string; const AData: TBytes): TMultipartPartArray;
function BuildMultipart(const ABoundary: string; const AParts: TMultipartPartArray): TBytes;
```

---

## 2. 不变量

- Boundary 字符串不超过 70 字符（RFC 2046）
- 每个 Part 至少有一个 Header（Content-Disposition）
- Body 可以为空

---

## 3. 错误处理

- Boundary 不匹配抛 `EMultipartError`
- 格式错误抛 `EMultipartError`

---

## 4. 线程安全

- 纯函数式设计，无共享状态，线程安全

---

## 5. 内存管理

- 返回的 `TBytes` 和数组由调用方负责释放

---

## 6. 测试覆盖

- `test_multipart`: 8 测试，覆盖 Parse/Build/Boundary/Header/Body
