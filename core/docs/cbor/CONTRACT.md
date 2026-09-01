# nextpas.core.cbor 代码契约

**模块路径**：`core/src/nextpas.core.cbor.pas`（1 个源文件，必要时拆 `cbor.types/builder`）
**层级**：L2（依赖 L0 `base/errors` 与 L1 `text.view/bytes`；与 `json/yaml/toml` 同层）
**Owner**：core 集体
**最后更新**：2026-09-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 文件

| 文件 | 职责 |
|------|------|
| `cbor.pas` | 门面 + 实现（ICborBuilder/ICborDocument/TCborValue/TCborNode） |

四件套形态：当前单文件实现，门面即实现；`base` 类型（`TCborKind/TCborError/cCborMax*`）与 `intf`（`ICborBuilder/ICborDocument`）内聚于同一单元，按需可拆。

### 1.2 构建器

```pascal
ICborBuilder = interface
  procedure Uint(const AValue: UInt64);
  procedure NegInt(const AFinal: Int64);
  procedure Int(const AValue: Int64);
  procedure Bytes(const AValue: TBytes);
  procedure Text(const AValue: string);
  procedure Bool(const AValue: Boolean);
  procedure Null;
  procedure Float(const AValue: Double);
  procedure BeginArray(const AItemCount: SizeUInt);
  procedure BeginMap(const APairCount: SizeUInt);
  function ToBytes: TBytes;
end;
function CborBuilder: ICborBuilder;
```

确定性紧凑输出：definite length 头，参数最小字节序（<24 内联，否则 1/2/4/8 大端）。

### 1.3 文档与视图

```pascal
ICborDocument = interface
  function HasError: Boolean;
  function Error: TCborError; // {Message, Offset}
  function Root: TCborValue;
end;
function CborParse(const AData: TBytes): ICborDocument; overload;
function CborParse(const AData: PByte; const ASize: SizeUInt): ICborDocument; overload;
function CborParsePrefix(const AData: TBytes; const AOffset: SizeUInt): TCborPrefixResult;
TCborValue = record // 16B 借用视图
  function IsValid: Boolean; function Kind: TCborKind;
  function IsInt/IsBytes/IsText/IsArray/IsMap/IsBool/IsNull/IsReal: Boolean;
  function AsInt: Int64; function AsBytes: TBytes; function AsStr: TStringView;
  function ChildAt/Cpair: TCborValue; function Get(const AKey: string): TCborValue;
end;
```

---

## 2. 不变量

- **[INV-1]** Definite only：拒绝 indefinite/tag/保留 ai，fail-closed。
- **[INV-2]** 深度/节点上限：`cCborMaxDepth=32`、`cCborMaxNodes=65536`，超限 `SetError`。
- **[INV-3]** 整数域 Int64 收敛：`major 0 > High(Int64)`、`major 1` 越界报错（文档化子集）。
- **[INV-4]** 零拷贝：text 为 `TStringView` 指向输入缓冲，失效随输入；bytes 为 `Move` 副本。
- **[INV-5]** 严格消费：非前缀解析根后残留 = 错误；前缀解析经 `RootEnd` 报告消费长度。
- **[INV-6]** 错误面：解析永不抛异常，经 `HasError/Error`；builder 契约违例抛异常。
- **[INV-7]** 单源复用：复用 `bytes.ops/builder` 与 `text.view`，不复制比较/拼接逻辑。

---

## 3. 错误处理

| 场景 | 行为 |
|------|------|
| indefinite/tag/保留 ai | `SetError('indefinite length not supported'/'tags not supported')` |
| 深度/节点超限 | `SetError('depth/node limit exceeded')` |
| 整数越界 | `SetError('uint/negint exceeds Int64 domain')` |
| 截断/越界 | `SetError('truncated* / length exceeds input')` |
| 空输入 | `SetError('empty input')` |
| 前缀偏移越界 | `Consumed=0, HasError=True` |

---

## 4. 线程安全

- `TCborValue/TCborParser`：非线程安全，调用方同步；同一 `ICborDocument` 禁止并发写。
- 纯视图访问（`Is*/As*`）：线程安全（只读借用）。

---

## 5. 内存管理

- `TCborDocument` 经 `New/Dispose(PCborDocument)` + 接口 `TCborDocumentImpl` 管寿命；`FNodes/FBlobs` 为动态数组 arena。
- `AsBytes` 返回副本（`Copy`）；`AsStr` 返回视图（零分配）。
- Builder `FBuf: TBytes` 经 `SetLength+Move` 增长，`ToBytes` 返回拷贝。

---

## 6. 测试覆盖

| 测试目录 | 说明 |
|----------|------|
| `core/tests/nextpas.core.cbor` | 解析（definite/tag 拒绝/截断/深度/Int64 边界）+ 构建往返 + 前缀 |

门禁：`make -C core/tests/nextpas.core.cbor clean test`（heaptrc 0）。
