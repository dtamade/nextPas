# nextpas.core.html

容错 HTML→纯文本提取 + 实体解码（B2 批次）。单遍扫描、不构建 DOM、无外部依赖。

## 文件结构

```
src/nextpas.core.html.base.pas   — 公共类型：THtmlExtractOptions（record 值语义）+
                                    DefaultHtmlExtractOptions 默认值
src/nextpas.core.html.pas        — 门面：HtmlTextOf / TryHtmlTextOf / HtmlDecodeEntities
core/tests/nextpas.core.html/    — test_html_extract（focused 门禁）
core/docs/html/README.md         — 本文件
```

## Quick Start

```pascal
uses nextpas.core.html;

// 默认选项：去标签、剔除 script/style/noscript/head、实体解码、空白折叠
Text := HtmlTextOf('<p>Hi <b>there</b> &amp; welcome</p>');   // 'Hi there & welcome'

// 保留链接 URL 与标题结构
Opt := DefaultHtmlExtractOptions;
Opt.KeepLinks    := True;
Opt.KeepHeadings := True;
Text := HtmlTextOf('<a href="https://x.com">click</a>', Opt); // 'click (https://x.com)'

// 仅解码实体
Raw := HtmlDecodeEntities('a &amp; b &#x2F; c');              // 'a & b / c'
```

## 规则表

| 输入 | 处理 |
| --- | --- |
| `<tag attr="v">` | 标签与属性剥离，标签名大小写不敏感 |
| `<script>/<style>/<noscript>/<head>` | 内容整体剔除（大小写不敏感；`</scriptx` 不算闭合） |
| `<!-- ... -->` | 注释剔除（未闭合吞掉剩余输入） |
| `<!DOCTYPE ...>` | 声明剔除（尊重属性值引号内的 `>`） |
| `<![CDATA[ ... ]]>` | 内容整体剔除 |
| `<?xml ... ?>` | 处理指令剔除 |
| `&name;` / `&#N;` / `&#xH;` | 解码（见下）；未知/畸形实体原样保留 |
| `&name`（无分号） | 下一个字符非字母数字时宽容解码（`&ampx` 不误吞） |
| 块级元素（p/div/li/td/br/h1-h6 等） | 块边界产生一个换行；连续块边界去重 |
| 行内元素（span/b/a/img alt 等） | 内容并回文本流，不产生换行 |
| 空白（含 `&nbsp;`） | CollapseWhitespace=true：折叠为单个空格，块边界前空白丢弃；false：原样保留 |
| BOM / 前导空白 | UTF-8 BOM 跳过；输出两端空白裁掉 |
| 畸形输入（未闭合、截断、缺引号、`<3`、`a < b`） | 不抛异常，容错吞掉或作字面文本 |

### THtmlExtractOptions

| 字段 | 默认 | 含义 |
| --- | --- | --- |
| `KeepLinks` | False | `<a href=...>` 输出 `文本 (url)`（URL 实体已解码）；否则只留文本 |
| `KeepHeadings` | False | h1-h6 视为块级（内容前后换行）；否则折叠进文本流（紧凑预览） |
| `CollapseWhitespace` | True | 折叠连续空白为单个空格；false 时原样保留（块边界换行不受影响） |

### 实体子集

命名实体支持常用 HTML5 子集约 140 个（大小写敏感）：基本五件
`&amp; &lt; &gt; &quot; &apos;`、Latin-1 补集（`&nbsp; &copy; &reg; &eacute; …`）、
常用符号（`&hellip; &mdash; &lsquo; &euro; &trade; …`）、希腊字母大小写全套、
标点（`&num; &sol; &semi; …`）。数字实体支持十进制与十六进制（`&#169; &#xA9;`）。

## 已知限制

- 命名实体为常用子集，非完整 HTML5 2231 个名称表；未收录的名称为字面保留。
- `&#0;`、代理区、超过 `U+10FFFF` 的数字实体视为非法，原样保留（不做浏览器式 U+FFFD 替换）。
- 未实现 `html`/`body`/`<pre>` 特殊空白语义；`pre` 按普通块处理。
- 实体单遍解码（`&amp;amp;` → `&amp;`），不做二次递归。
- 属性值内的 `>` 正确跳过，但属性值内的 `&` 不做解码（避免歧义）。
- 输入上限 `MaxHtmlInputLength`（64 MiB）：超过时 `HtmlTextOf` 抛 `EArgumentError`，
  `TryHtmlTextOf` 返回 `False`。