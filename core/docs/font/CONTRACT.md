# nextpas.core.font 代码契约

**模块路径**：`core/src/nextpas.core.font*.pas`（6 个源文件）
**层级**：L2（依赖 L0: base, text, bytes, math, mem）
**Owner**：Claude（AI 负责）
**最后更新**：2026-08-31
**版本**：1.2

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| font.base | 基础类型（TFontTableEntry, TFontHeadTable, TFontMetrics 等） |
| font.ttface | TrueType 表解析（head/hhea/maxp/OS2/name/post/fvar/avar） |
| font.shaper | 文本整形（GSUB 查询 + SingleSubst + MarkToBase） |
| font.atlas | 字形图集管理 |
| font.rasterizer | 字形光栅化 |
| font.pas | 门面 re-export |

### 1.2 核心类型

```pascal
TFontHeadTable = record
  UnitsPerEm: UInt16;
  Created, Modified: Int64;
  XMin, YMin, XMax, YMax: Int16;
end;

TFontMetrics = record
  Ascent: Int16;
  Descent: Int16;
  LineGap: Int16;
  AdvanceWidthMax: UInt16;
end;

TFontOs2Table = record
  XAvgCharWidth: Int16;
  UsWeightClass: UInt16;
  FsSelection: UInt16;
end;
```

### 1.3 核心 API

```pascal
// TrueType 表解析
function TtFaceParseHead(const AData: TBytes): TFontHeadTable;
function TtFaceParseHhea(const AData: TBytes): TFontMetrics;
function TtFaceParseMaxp(const AData: TBytes): TFontMaxpTable;

// 文本整形
function GsubLookup(const ATable: TBytes; AFeature, AGlyph: Integer): Integer;
```

---

## 2. 不变量

- UnitsPerEm > 0
- Ascent + Descent = 行高
- GSUB lookup 返回 -1 表示无替换

---

## 3. 错误处理

- 表数据格式错误抛 `EFontError`
- Glyph ID 越界抛 `EFontError`

---

## 4. 线程安全

- 解析函数纯函数式，线程安全
- Atlas 和 Shaper 有内部状态，调用方自行同步

---

## 5. 内存管理

- 返回的记录由调用方负责释放
- TBytes 参数引用计数管理

---

## 6. 测试覆盖

- `test_font_tables`: head/hhea/maxp/OS2/name/post/fvar/avar 表解析
- `test_font_shaper`: GSUB/SingleSubst/MarkToBase 整形查询
