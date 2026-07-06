# nextpas.core.yaml 模块规划

> **目标：** FreePascal 领域最优秀的 YAML 1.2 Core Schema 解析器/序列化器。
> **标杆：** 性能对标 Go yaml.v3 / Rust yaml-rust2，API 优雅度对标 nextpas.core.json。

## 设计哲学

1. **三层架构**（libyaml 经典模式）：Scanner → Parser → Composer
2. **零拷贝**：标量值用 TStringView 借用输入缓冲区
3. **flat node array**：与 JSON 模块一致的内存布局，cache-friendly
4. **SIMD 加速**：空白跳过、plain scalar 扫描用 Vec16
5. **Core Schema**：覆盖 95%+ 实际场景（K8s/CI/CD/配置文件）
6. **渐进式**：先 flow style（类 JSON），再 block style，最后高级特性

## 规范范围

### 支持（Core Schema + 实用扩展）

- 标量：null/bool/int/float/string（4 种风格：plain/single-quoted/double-quoted/block）
- 集合：mapping/sequence（block + flow 两种风格）
- Block scalar：literal `|` / folded `>`，chomping `-`/`+`/默认
- 锚点/别名：`&anchor` / `*alias`（含循环检测）
- 多文档：`---` / `...`
- 注释：`#`
- UTF-8

### 不支持（v1 scope out）

- 自定义 tag (`!foo`, `!!type`)
- Merge key `<<`
- Complex key（mapping 作为 key）
- UTF-16/32 BOM 自动检测
- Directive `%YAML` / `%TAG`

## 模块结构

```
nextpas.core.yaml.pas                  ← 门面 re-export
nextpas.core.yaml.types.pas            ← TYamlNodeKind, TYamlNode, TYamlError
nextpas.core.yaml.scanner.pas          ← 字符流 → token 流（缩进栈 + flow level）
nextpas.core.yaml.parser.pas           ← token 流 → event 流（SAX 风格）
nextpas.core.yaml.value.pas            ← TYamlValue（DOM 访问，类 TJsonValue）
nextpas.core.yaml.writer.pas           ← TYamlWriter（序列化输出）
nextpas.core.yaml.builder.pas          ← IYamlBuilder（编程式构建）
```

## 接口设计

```pascal
{ yaml.types.pas }
type
  TYamlNodeKind = (
    ynkNull,
    ynkBool,
    ynkInt,
    ynkFloat,
    ynkString,
    ynkSequence,
    ynkMapping,
    ynkAlias
  );

  TYamlScalarStyle = (
    yssPlain,
    yssSingleQuoted,
    yssDoubleQuoted,
    yssLiteral,    // |
    yssFolded      // >
  );

  TYamlNode = record
    Kind: TYamlNodeKind;
    Next: UInt32;
    Anchor: TStringView;   // 空 = 无锚点
    case Byte of
      0: (BoolVal: Boolean);
      1: (IntVal: Int64);
      2: (RealVal: Double);
      3: (Str: TStringView);
      4: (Container: record
            FirstChild: UInt32;
            Count: UInt32;
          end);
      5: (AliasTarget: UInt32);  // 指向锚点节点索引
  end;

{ yaml.pas — 门面 API }
type
  IYamlDocument = interface
    function Root: TYamlValue;
    function HasError: Boolean;
    function Error: TYamlError;
    function Stringify: string;
    function StringifyPretty(const AIndent: Int32 = 2): string;
  end;

function YamlParse(const AInput: string): IYamlDocument; overload;
function YamlParse(const AInput: TStringView): IYamlDocument; overload;
function YamlStringify(const AValue: TYamlValue): string;

{ yaml.value.pas — DOM 访问 }
type
  TYamlValue = record
    function IsValid: Boolean;
    function Kind: TYamlNodeKind;
    function IsNull: Boolean;
    function IsBool: Boolean;
    function IsInt: Boolean;
    function IsFloat: Boolean;
    function IsStr: Boolean;
    function IsSeq: Boolean;
    function IsMap: Boolean;
    function AsBool: Boolean;
    function AsInt: Int64;
    function AsFloat: Double;
    function AsStr: TStringView;
    function SeqLen: UInt32;
    function SeqGet(AIndex: UInt32): TYamlValue;
    function MapGet(const AKey: TStringView): TYamlValue; overload;
    function MapGet(const AKey: string): TYamlValue; overload;
    function MapHas(const AKey: TStringView): Boolean; overload;
    function MapHas(const AKey: string): Boolean; overload;
    function MapLen: UInt32;
    function MapKeyAt(AIndex: UInt32): TStringView;
    function MapValueAt(AIndex: UInt32): TYamlValue;
  end;
```

## Scanner 架构（核心难点）

```
输入字符流
    │
    ▼
┌─────────────────────────────────┐
│  TYamlScanner                   │
│  ├── FIndentStack: array of Int32│  ← 缩进级别栈
│  ├── FFlowLevel: Int32          │  ← flow 嵌套深度
│  ├── FTokenQueue: ring buffer   │  ← 预读 token 队列
│  └── FSimpleKeyStack            │  ← 隐式 key 候选栈
└─────────────────────────────────┘
    │
    ▼
Token 流: StreamStart, DocStart, BlockMappingStart,
          Key, Scalar("name"), Value, Scalar("Alice"), ...
```

关键设计决策：
- **缩进栈**：每次缩进增加 push，减少时 pop 并发射 BlockEnd token
- **Simple key**：plain scalar 后跟 `:` 时回溯标记为 key
- **Flow level**：`{` `[` 进入 flow 模式，忽略缩进
- **SIMD 空白跳过**：用 Vec16 批量跳过 space/tab/newline

## 实施顺序

| Phase | 内容 | 预估行数 |
|-------|------|----------|
| P1 | types + scanner 骨架（flow-only tokens） | ~400 |
| P2 | parser（token → event 流） | ~300 |
| P3 | composer + value（event → DOM 树） | ~300 |
| P4 | block scalar + 缩进栈 | ~500 |
| P5 | block mapping/sequence | ~400 |
| P6 | multi-line string (literal/folded) | ~200 |
| P7 | anchors/aliases + 循环检测 | ~150 |
| P8 | multi-document (`---`/`...`) | ~100 |
| P9 | writer（DOM → YAML 输出） | ~300 |
| P10 | builder（编程式构建） | ~150 |
| P11 | 门面 + 完整测试 | ~200 |
| P12 | SIMD 优化 + 基准对比 | ~200 |
| P13 | 3 轮 Codex 审查 | — |

## 测试计划

| 测试组 | 覆盖 |
|--------|------|
| Flow scalars | null/bool/int/float/string 各种写法 |
| Flow collections | `[1, 2, 3]`, `{a: 1, b: 2}` |
| Block sequence | `- item` 列表 |
| Block mapping | `key: value` |
| Block scalar | `\|`/`>` + chomping |
| Nested | 深层嵌套 block + flow 混合 |
| Anchors | `&`/`*` 定义和引用 |
| Multi-doc | `---`/`...` 分隔 |
| Edge cases | 空文档、纯标量、trailing newline |
| Error | 非法缩进、未闭合引号、循环引用 |
| Interop | 与 Go yaml.v3 输出对比 |
| Round-trip | parse → stringify → parse = 等价 |

## 基准对比

```
benchmarks/nextpas.core.yaml/bench_yaml/bench_yaml.lpr

- Parse small YAML (K8s pod spec, ~500B) — 对比 Go yaml.v3
- Parse medium YAML (docker-compose, ~2KB) — 对比 Go yaml.v3
- Parse large YAML (10KB config) — 对比 Go yaml.v3, Rust yaml-rust2
- Stringify — 对比 Go yaml.v3
```

## 依赖

```
nextpas.core.yaml (L2)
  ├── nextpas.core.text.view (L1) — TStringView
  ├── nextpas.core.text.number (L1) — ParseInt64/ParseDouble
  ├── nextpas.core.text.char (L1) — IsDigit/IsWhitespace
  ├── nextpas.core.text.scan (L1) — ScanSkipWhitespace
  ├── nextpas.core.text.escape (L1) — Unicode escape
  ├── nextpas.core.mem.intf (L1) — IAllocator
  ├── nextpas.core.simd (L1) — Vec16 SIMD 加速
  └── nextpas.core.errors (L0) — EParseError
```

## 质量门禁

- [ ] 所有 API 100% 单元测试覆盖
- [ ] heaptrc 0 泄漏
- [ ] yaml-test-suite 核心子集通过
- [ ] 基准对比 Go yaml.v3（目标：持平或超越）
- [ ] 3 轮 Codex 审查 LGTM
- [ ] gunzip/interop 等价验证
