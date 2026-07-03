# nextpas.core.xml 代码契约

**模块路径**：`core/src/nextpas.core.xml*.pas`（5 个源文件）
**层级**：L1（依赖 L0: base, mem）
**Owner**：Claude（AI 负责）
**最后更新**：2026-07-01
**版本**：1.0

---

## 1. 接口契约

### 1.1 子模块

| 文件 | 职责 |
|------|------|
| xml.base | TXmlTokenKind, TXmlName, TXmlAttribute, EXmlError, TXmlPosition |
| xml.reader | TXmlReader 流式 SAX 解析器 |
| xml.writer | TXmlWriter 流式写入器 |
| xml.dom | TXmlDocument, TXmlNode DOM 树 |
| xml.pas | 门面 |

### 1.2 核心类型

```pascal
TXmlReader = record
  class function Create(const AInput: string): TXmlReader; static;
  function NextToken: Boolean;
  function Token: TXmlToken;
  // SAX 风格流式读取
end;

TXmlWriter = record
  class function Create: TXmlWriter; static;
  procedure WriteStartElement(const AName: string);
  procedure WriteAttribute(const AName, AValue: string);
  procedure WriteEndElement;
  procedure WriteText(const AText: string);
  function ToString: string;
end;

TXmlDocument = class
  // DOM 风格操作
  function Root: TXmlNode;
  function FindNode(const APath: string): TXmlNode;
  function ToString: string;
end;
```

---

## 2. 不变量

- **[INV-1]** TXmlReader 为 record，零堆分配（视图引用输入）
- **[INV-2]** EXmlError 包含位置信息（Line/Column）
- **[INV-3]** TXmlWriter 输出合法 XML（自闭合标签、转义特殊字符）
- **[INV-4]** DOM 树父节点拥有子节点

---

## 3. 错误处理

| 场景 | 异常 |
|------|------|
| 非法 XML 语法 | EXmlError + 位置信息 |
| 未闭合标签 | EXmlError |
| 非法字符引用 | EXmlError |

---

## 4-6. 概要

- **线程安全**: TXmlReader/Writer ✅（值类型）; TXmlDocument ❌
- **内存**: Reader 零分配; Writer 内部 buffer; Document 树结构拥有子节点
- **测试**: 7 个测试目录

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始版本 | Claude |
