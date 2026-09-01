# nextpas.core.cbor

RFC 8949 CBOR 确定性子集（definite lengths only），与 `json`/`yaml`/`toml` 同属 L2 序列化家族。由 `nextpas.core.cbor.pas` 单源实现，门面纯 re-export，解析与构建分离。

## 定位

- **层级**：L2（依赖 L0 `base/errors` 与 L1 `text.view`/`bytes`，不依赖 `json`）。
- **四件套**：`cbor.pas` 门面 + `cbor` 实现（当前单文件，按需可拆 `cbor.types/builder`）。
- **双编译器**：仅用 FPC 基础 RTL，stub 仅名称桥接，无 `{$IFDEF}` 分叉。

## 核心能力

- **解析**：`CborParse(PByte,Size)/CborParse(TBytes)/CborParsePrefix`，经 `ICborDocument` 持有 arena（`TCborNode` 数组 + `Blobs`），`TCborValue` 16 字节借用视图（零分配遍历）。
- **限制**：definite lengths only，拒绝 indefinite（ai=31）、tag（major 6）、保留 ai（28..30）；`cCborMaxDepth=32`、`cCborMaxNodes=65536` 防放大；根后残留字节按错误处理。
- **整数域**：收敛 `Int64`（`major 0 > High(Int64)` 或 `major 1` 越界报错，文档化子集边界）。
- **文本串**：零拷贝 `TStringView` 指向输入缓冲，不校验 UTF-8 良构性（与 json 同口径）。
- **构建**：`ICborBuilder` 确定性紧凑输出（definite length 头 + 最小字节序参数），`Uint/NegInt/Int/Bytes/Text/Bool/Null/Float/BeginArray/BeginMap/ToBytes`。

## 错误与不变量

- **解析**：`HasError/Error`（`TCborError` {Message, Offset}），永不抛异常（不可信输入属边界）；`Root` 失败返回 Invalid 值，`CborParsePrefix` 返回 `{Consumed, Doc}`。
- **Builder**：契约违例为编程错误，走异常。
- **不变量**：`Span` 零拷贝视图寿命绑定输入缓冲；`Move` 直拷字节串副本；`DecodeHalfFloat` 纯位构造不引 `math`。

## 依赖与复用

- 复用 `bytes.ops`/`bytes.builder` 单源（追加/拼接），不自建重复逻辑；与 `json` 家族共享 `text.view` 零拷贝纪律。
- 线程安全：解析与构建实例非线程安全，调用方同步；纯函数视图线程安全。

## 测试与门禁

```
make -C core/tests/nextpas.core.cbor clean test   # 若无独立 gate，则经 core 全量
fpc -Mobjfpc -Sh -Fi core/src -Fu core/src core/src/nextpas.core.cbor.pas
bash scripts/build-hygiene-check.sh
```

当前测试：`core/tests/nextpas.core.cbor/`（若缺则按 `bytes` 模板补 `test_cbor`）。
