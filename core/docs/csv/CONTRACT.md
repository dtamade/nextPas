# nextpas.core.csv 代码契约

**模块路径**：`core/src/nextpas.core.csv.pas`（1 个源文件）
**层级**：L1（依赖 L0: base, errors, mem）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 核心类型

```pascal
TCsvError = record
  Message: string;
  Offset: SizeUInt;
  Line: UInt32;
  Column: UInt32;
end;

TCsvReader = record
  // 流式 RFC 4180 解析器
  class function Create(const AInput: string): TCsvReader; static;
  function ReadRow(out ARow: TStringArray): Boolean;
  function ReadAll: TStringMatrix;
  function Error: TCsvError;
end;

TCsvWriter = record
  // 流式 CSV 写入器
  class function Create(ADelimiter: Char = ','): TCsvWriter; static;
  procedure WriteRow(const ARow: array of string);
  function ToString: string;
end;
```

### 1.2 RFC 4180 兼容

- 默认分隔符: `,`
- 引号字符: `"`
- 引号内换行: 支持
- 引号内双引号转义: `""` → `"`
- 行尾: CRLF 或 LF

---

## 2. 不变量

- **[INV-1]** TCsvReader 为 record，零堆分配（视图引用输入字符串）
- **[INV-2]** 引号字段内可包含分隔符和换行
- **[INV-3]** ReadRow 返回 False 表示 EOF

---

## 3. 错误处理

| 场景 | 策略 |
|------|------|
| 未闭合引号 | Error.Message 设置，ReadRow 返回 False |
| 非法格式 | Error 记录位置（Line/Column/Offset） |
| IAllocator 注入 | 内部 buffer 使用 FAllocator |

---

## 4-6. 概要

- **线程安全**: TCsvReader/Writer 为 record，✅ 值语义
- **内存**: Reader 零分配（视图）; Writer 内部 buffer; ReadAll 返回 TStringMatrix
- **测试**: 4 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
