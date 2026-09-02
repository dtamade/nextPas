# nextpas.core.template 代码契约

**模块路径**：`core/src/nextpas.core.template.pas`（1 个源文件，~1110 行）
**层级**：L3（templates；L0-L2，需 `text.conv` + `errors`，`TryStrToInt64` 单源）
**Owner**：template lane
**最后更新**：2026-08-31
**版本**：1.1

---

## 1. 接口契约

### 1.1 载体

```pascal
type
  TStringArray = array of string;
  TTemplateVar = record Name: string; Value: string; end;
  TTemplateList = record Name: string; Items: array of string; end;
  TTemplateFunc = function(const AValue: string): string;
  TTemplateDefine = record Name: string; Body: string; end;

  TTemplateContext = record
    class function Create: TTemplateContext; static;
    procedure SetVar(const AName, AValue: string);
    procedure SetInt(const AName: string; AValue: Int64);
    procedure SetBool(const AName: string; AValue: Boolean);
    procedure SetList(const AName: string; const AItems: array of string);
    procedure RegisterFunc(const AName: string; AFunc: TTemplateFunc);
    procedure SetPrefix(const AValue: string);
    procedure Define(const AName, ABody: string);
    function GetDefine(const AName: string): string;
    function GetVar(const AName: string): string;
    function GetBool(const AName: string): Boolean;
    function GetList(const AName: string): TStringArray;
  end;

  TTemplate = record
    class function Create(const ASource: string): TTemplate; static;
    function Render(const ACtx: TTemplateContext): string;
    function RenderWith(const AVars: array of TTemplateVar): string;
  end;

function TemplateRender(const ATemplate: string; const ACtx: TTemplateContext): string;
```

### 1.2 模板语法

- 定界：`{{ expr }}`；字面量转义 `\{{` / `\}}`。
- 变量：`{{.Name}}` / `{{Name}}` / `{{.User.Name}}`（`with` 前缀 + 点分）。
- 管道：`{{.Name | upper | trim | default "N/A" | len}}`；`|` 分割，失败为 parse error。
- 条件：`{{if .Show}}…{{else}}…{{end}}`；`if` 表达式为单变量 truthiness（`''`/`0`/`false` 假）或比较 `eq/ne/gt/lt/ge/le .Var "literal"|$var|.Var`。
- 循环：`{{range .Items}}[{{.}}]{{end}}`；`.` 在循环内重绑为当前元素，原 `.` 于循环后恢复。
- 局部：`{{$x := .Name}}` / `{{$x := .Name | upper}}` / `{{$x}}`；块内 `ALocals` 栈，`if/range/with/define` 结束回滚 `ALocalCount`。
- 作用域：`{{with .User}}…{{end}}` 设置 `FPrefix`（嵌套 `Prefix+'.'+Var`），退出恢复。
- 定义：`{{define "name"}}body{{end}}` 收集 `body` 为 `Define`；`{{template "name"}}` 插入（缺失静默空）。

---

## 2. 过滤器与函数

| 名称 | 行为 |
|------|------|
| `upper` | `a-z → A-Z`（`UniqueString` + 单遍） |
| `lower` | `A-Z → a-z` |
| `trim` | 两端 `<= ' '` 空白去除 |
| `default "X"` | `'' → X` |
| `len` | `Length(string)` → `IntToStr` |
| 自定义 | `RegisterFunc(name, func)` 优先于内置；`nil` 抛 `EArgumentError` |

---

## 3. 错误契约

- 语法错误抛 `EParseError`（`nextpas.core.errors` taxonomy，经 `nextpas.core.base`/`exception` 链），包括：未闭合 `{{`/`}}`、空 `{{if}}`/`{{range}}`/`{{with}}`、`{{else}}`/`{{end}}` 悬挂、空管道段 `{{.Name |}}` / `{{.Name || upper}}`、空/非法 `define`/`template` 名称、比较操作数缺失等。
- `SkipBlock` 对被跳过的 `else` 分支仍做 `RequireExpressionSyntax/RequireBoolExpr/RequireBlockClosed` 完整校验（不因 `if` 真假而放过无效语法）。
- 未定义变量静默 `''`；未定义 `template` 静默 `''`；`range` 空列表跳过块（不定义块内 `define`）。

---

## 4. Lifetime / 所有权

- `TTemplateContext` 为 `record` 值语义，`Render` 内经 `CloneTemplateContext` 深拷贝 `FVars/FLists/FFuncs/FDefines`（`SetLength+Copy`），内联 `define` 修改不污染调用方上下文（`InlineDefineDoesNotMutateContext` 门禁）。
- `TTemplate` 为 `record` 持有 `FSource` string；`RenderSegment` 递归以 `var ALocals` 栈传递，块退出回滚 `ALocalCount`。
- 无句柄/文件/分配器外资源；均由字符串值语义管理。

---

## 5. 依赖边界

- 允许：`nextpas.core.text.conv`（`TryStrToInt64` 单源；`gt/lt/ge/le` 数值比较复用，禁止在 `template` 内重造数值解析）、`nextpas.core.errors`（`EParseError/EArgumentError` taxonomy）。
- 禁止：`SysUtils`（`Upper/Lower/Trim` 自实现，`IntToStr` 经 `text.conv`）、`platform`/`Windows`/`BaseUnix`、`regex`/`json` 等 L2 同层重实现。

---

## 6. 不变量

- **[INV-1]** `Render` 必须克隆上下文；调用方 `Define` 在多遍 `Render` 间可见，单遍内 `define` 不回写调用方。
- **[INV-2]** `with` 前缀解析：`GetVar` 先试 `FPrefix+'.'+Name` 再试 `Name`。
- **[INV-3]** `range` 恢复 `.`：循环前 `LSavedDot := GetVar('.')`，每次迭代 `SetVar('.', Item)`，迭代后还原。
- **[INV-4]** `if` 比较：`gt/lt/ge/le` 先试 `TryStrToInt64` 双数值比较，否则字典序。

---

## 7. 性能

- `TrimInternal/UpperInternal/LowerInternal` 采用 `UniqueString` + 原地单遍，无临时 `Copy` 循环外分配；`ApplyFilterWithFuncs` 对自定义函数表线性查找（小表 `FFuncCount`），内置过滤为 `StrEqCI` 分支。
- `EvalExpr` 管道分割为固定 `LParts[0..15]` 栈数组，零堆分配；`RenderSegment` 以 `LPos`/`TTagStart/End` 指针游走，字面量经 `AppendLiteral` 单次 `Copy` 追加。
- `CloneTemplateContext` 为按需深拷贝（`SetLength` 仅在 `Render` 入口一次）；`GetList` 返回快照拷贝（防外部篡改）。

---

## 8. 测试入口

```bash
make -C core/tests/nextpas.core.template clean test
make focused FOCUS=core/tests/nextpas.core.template/test_template
```

套件：`test_template`（变量/条件/range/过滤链/管道校验/define/template/with/局部变量/比较/自定义函数/失败不污染等 60+ 用例）。

---

## 9. Out of scope

- 不做 `html/template` 自动转义；不做 `Sprig` 级函数全集（仅 `upper/lower/trim/default/len` + 自定义扩展点）。
- 不做文件系统模板加载（`fs` 缝由消费方组合）。

---

## 变更记录

| 日期 | 版本 | 变更描述 | 作者 |
|------|------|----------|------|
| 2026-07-01 | 1.0 | 初始实现：Go `text/template` 简化版 | template lane |
| 2026-08-31 | 1.1 | 文档矩阵补齐：新增 `docs/template/`（README+CONTRACT），对齐 `core-module-registry` L3 `template`（`module-registry` deprecated alias），`text.conv` 单源/克隆隔离证据 | core-docs |
