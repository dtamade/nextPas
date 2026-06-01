# nextpas.core API 一致性公约

本文档定义 core 框架跨模块的 API 命名、错误处理、生命周期约定。
所有新模块必须遵循；已有模块渐进迁移（不破坏现有 API）。

经 Codex 评审确定（session 019e82dd）。

---

## 1. 入口动词公约

| 动词 | 语义 | 返回 | 示例 |
|------|------|------|------|
| `Parse` | 纯文本 → 语法树/文档 | 新建的文档对象 | `JsonParse`, `XmlParse`, `TomlParse` |
| `Load` | 加载进**已有**对象/配置 | 无（填充入参对象） | `TConfig.LoadFromIni`, `TIniFile.LoadFromString` |
| `Read` | 增量消费输入流 | 单个 token/row | `TCsvReader.ReadRow`, `TXmlReader.Next` |
| `Decode`/`Encode` | 编解码转换（无语法树） | 转换结果 | `XmlDecodeEntities`, `Base64Decode` |

**规则：**
- 模块顶层解析入口统一命名 `<Module>Parse`（如 `JsonParse`/`XmlParse`/`TomlParse`/`YamlParse`）
- 加载进已有可变对象用 `LoadFromXxx`
- 流式增量用 `Read`/`Next`

---

## 2. 错误处理公约（P0）

遵循框架 design-conventions「默认用异常」原则：

### 默认形态：抛异常
```pascal
// Parse 失败抛异常，调用方写直线代码
Doc := JsonParse(Input);  // 失败抛 EJsonError（含 position）
```

### 补充形态：TryXxx 返回 Boolean + out Error
```pascal
// 调用方需要区分成功/失败分支时
if TryJsonParse(Input, Doc, Err) then
  // 成功
else
  // Err 含错误信息和位置
```

### 错误对象必须携带位置上下文
```pascal
EXmlError = class(EParseError)
  Position: TXmlPosition;  // ByteOffset + Line + Column
end;
```

### Legacy：HasError/Error 模式
- JSON/YAML/TOML 现有的 `IDocument.HasError`/`Error` **保留兼容**
- 标记为 legacy/diagnostic，**不再向新模块扩散**
- 新解析器优先用异常 + TryXxx

---

## 3. 生命周期公约

| 形态 | 适用 | 释放 |
|------|------|------|
| `interface` (IXxxDocument) | 解析结果文档、Builder | 引用计数自动 |
| `class` (TXxxDocument) | 有明确父子所有权的可变树（DOM） | 手动 Free 或 owner 释放 |
| `record` (TXxxReader) | 值语义、无堆所有权的游标 | 无需释放 |

**XML 例外（合理）：** TXmlDocument 用 class（DOM 树有父子所有权、节点可变、显式释放自然）。
可补 `XmlParseRef: IXmlDocument` 便利层对齐脚本式用法（P1，非强制）。

---

## 4. 参数命名公约

| 类别 | 约定 | 示例 |
|------|------|------|
| 输入文本 | `AInput` | `JsonParse(const AInput: string)` |
| 文件路径 | `AFilePath` / `APath` | `LoadFromFile(const APath: string)` |
| 输出参数 | `out AResult` | `TryParse(...; out AValue)` |
| 默认值 | `ADefault` | `GetString(AKey, ADefault)` |
| 错误输出 | `out AError` | `TryParse(...; out AError: string)` |

---

## 5. 迁移优先级

| 项 | 优先级 | 行动 |
|----|--------|------|
| 错误模型（异常 + TryXxx 补充） | **P0** | 新代码遵循；解析器补 TryParse |
| 入口命名公约 | **P0** | 新模块强制；Config 已补 TryLoadFromXxx/TryLoadXxx |
| HasError 标记 legacy | P1 | 文档注明，不删除 |
| XML IXmlDocument 便利层 | P1 | 补充，旧 API 保留 |
| 生命周期统一 | 非 P0 | 保持现状（class/interface/record 各得其所）|

---

## 6. 当前模块合规状态

| 模块 | 入口 | 错误 | 合规度 |
|------|------|------|--------|
| json | JsonParse ✅ | HasError (legacy) | 待补 TryParse |
| yaml | YamlParse ✅ | HasError (legacy) | 待补 TryParse |
| toml | TomlParse ✅ | HasError (legacy) | 待补 TryParse |
| xml | XmlParse ✅ | EXmlError (异常+position) ✅ | 待补 IXmlDocument |
| ini | LoadFromString ✅ | 无 | 待补错误 + TryLoad |
| csv | ReadRow ✅ | HasError/GetError | 合规 |
| config | LoadFromXxx ✅ | EConfigError + TryLoadFromXxx/TryLoadXxx ✅ | 合规 |
| validation | (Builder) | 错误收集模式 ✅ | 合规（特殊领域）|
