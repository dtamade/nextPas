# nextpas.core.csv 代码契约

> 模块路径: `core/src/nextpas.core.csv.*.pas`
> 创建日期: 2026-07-04
> 维护者: AI

---

## 概述

RFC 4180 兼容 CSV 解析器和写入器。零 SysUtils 依赖，Go encoding/csv 兼容 API。

---

## 关键接口

```pascal
type
  TCsvError = record
    Message: string;
    Offset: SizeUInt;
    Line: UInt32;
    Column: UInt32;
  end;

  TCsvReader = record
    class function Create(AInput: string; ADelimiter: AnsiChar = ',';
      AFieldsPerRecord: Integer = 0; ATrimSpace: Boolean = False;
      AComment: AnsiChar = #0): TCsvReader; static;
    function ReadRow(out AFields: TStringArray): Boolean;
    function HasError: Boolean;
    function Error: TCsvError;
    procedure Done;
  end;

  TCsvWriter = record
    class function Create(ADelimiter: AnsiChar = ','): TCsvWriter; static;
    procedure WriteRow(AFields: TStringArray);
    function AsString: string;
    procedure Done;
  end;
```

---

## 错误语义

| 场景 | 行为 |
|------|------|
| 引号未闭合 | HasError=true, Error 描述位置 |
| 字段数不一致 | HasError=true（如果 FieldsPerRecord > 0） |

---

## 线程安全

- TCsvReader/TCsvWriter 为值类型 record，不共享状态

---

## 依赖关系

- 依赖: errors, mem
- 被依赖: 数据导入/导出

---

## 变更记录

| 日期 | 变更 | 原因 |
|------|------|------|
| 2026-07-04 | 初始版本 | 契约建立 |
