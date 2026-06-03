# TUI Dual-track Strengthening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Freeze `nextpas.core.tui` into `core / ext / experimental / full` facades, land the terminal capability runtime-truth model, and prove the split with focused TUI tests only.

**Architecture:** Keep the current wide facade available through `nextpas.core.tui.full`, narrow `nextpas.core.tui` to the correctness-first default surface, move stable app/runtime contracts to `nextpas.core.tui.ext`, isolate volatile protocols in `nextpas.core.tui.experimental`, and make `TTerminal.CapabilityProfile` the single runtime truth for enhanced terminal features.

**Tech Stack:** FreePascal, `nextpas.core.testing`, Makefile-driven focused tests, heaptrc `-gh`, TUI benchmark smoke runners.

---

## File structure

### New source units

- Create: `core/src/nextpas.core.tui.cap.base.pas`
  - Owns `TTuiCapabilityTier`, `TTuiCapabilityPolicy`, and `TTuiCapabilityStatus`.
- Create: `core/src/nextpas.core.tui.ext.pas`
  - Stable app/runtime facade layered on top of `nextpas.core.tui`.
- Create: `core/src/nextpas.core.tui.experimental.pas`
  - Opt-in facade for image and clipboard protocols.
- Create: `core/src/nextpas.core.tui.full.pas`
  - Migration compatibility facade that preserves the current broad export set.

### Modified source units

- Modify: `core/src/nextpas.core.tui.pas`
  - Narrow the default facade to the correctness-first surface only.
- Modify: `core/src/nextpas.core.tui.terminal.pas`
  - Replace boolean capability fields with structured runtime-truth status records.
- Modify: `core/src/nextpas.core.tui.image_cap.pas`
  - Add deterministic hint-based detection helper used by terminal contract tests.

### New tests

- Create: `core/tests/nextpas.core.tui/test_tui_cap_base/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_cap_base/test_tui_cap_base.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_app.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_clipboard.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_experimental.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_ext_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_ext_facade/test_tui_ext_facade.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_experimental_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_experimental_facade/test_tui_experimental_facade.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_image_cap/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_image_cap/test_tui_image_cap.lpr`

### Modified tests

- Modify: `core/tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr`
  - Turn it into the compatibility proof for `nextpas.core.tui.full`.
- Modify: `core/tests/nextpas.core.tui/test_tui_terminal/test_tui_terminal.lpr`
  - Add capability-profile truth tests.

### Docs

- Modify: `core/docs/tui/README.md`
- Modify: `core/docs/tui/ARCHITECTURE.md`
- Create: `core/docs/tui/TIER_REGISTRY.md`

## Task 1: Add tier primitives and positive facade scaffolding

**Files:**

- Create: `core/src/nextpas.core.tui.cap.base.pas`
- Create: `core/src/nextpas.core.tui.ext.pas`
- Create: `core/src/nextpas.core.tui.experimental.pas`
- Create: `core/tests/nextpas.core.tui/test_tui_cap_base/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_cap_base/test_tui_cap_base.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_ext_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_ext_facade/test_tui_ext_facade.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_experimental_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_experimental_facade/test_tui_experimental_facade.lpr`

- [ ] **Step 1: Write the failing facade-scaffolding tests**

```pascal
program test_tui_cap_base;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.cap.base,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestCapabilityStatus;
var
  LStatus: TTuiCapabilityStatus;
begin
  LStatus := TTuiCapabilityStatus.Create(True, True, False, False, 'probe-failed');
  Check(LStatus.Requested, 'requested is stored');
  Check(LStatus.Detected, 'detected is stored');
  Check(not LStatus.Active, 'active is stored');
  CheckEqual('probe-failed', LStatus.FallbackReason, 'fallback reason is stored');
end;
```

```pascal
program test_tui_ext_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.ext,
  nextpas.core.testing;

procedure TestExtSurface;
var
  LApp: TApp;
  LTheme: TChatTheme;
  LPanel: IPanel;
begin
  LApp := TApp.Create;
  try
    LTheme := ThemeDefaultDark;
    LPanel := TPanel.Grid(1, 1);
    Check(LApp <> nil, 'ext facade exposes app');
    Check(ColorIsSet(LTheme.FgPrimary), 'ext facade exposes theme presets');
    Check(LPanel <> nil, 'ext facade exposes stable advanced widgets');
  finally
    LApp.Free;
  end;
end;
```

```pascal
program test_tui_experimental_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.experimental,
  nextpas.core.testing;

procedure TestExperimentalSurface;
var
  LProtocol: TImageProtocol;
  LClipboard: TClipboard;
begin
  LProtocol := DetectImageProtocol;
  LClipboard := TClipboard.Detect;
  Check(Ord(LProtocol) >= Ord(ipAuto), 'experimental facade exposes image protocol contract');
  Check(Ord(LClipboard.Method) >= Ord(cmOSC52), 'experimental facade exposes clipboard contract');
end;
```

- [ ] **Step 2: Run the new tests and confirm they fail because the units do not exist yet**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_cap_base clean test
make -C core/tests/nextpas.core.tui/test_tui_ext_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_experimental_facade clean test
```

Expected:

- `Fatal: Can't find unit nextpas.core.tui.cap.base`
- `Fatal: Can't find unit nextpas.core.tui.ext`
- `Fatal: Can't find unit nextpas.core.tui.experimental`

- [ ] **Step 3: Add the tier primitive and the two opt-in facades**

`core/src/nextpas.core.tui.cap.base.pas`

```pascal
unit nextpas.core.tui.cap.base;

{$I nextpas.core.settings.inc}

interface

type
  TTuiCapabilityTier = (tctCore, tctExtended, tctExperimental, tctFullOnly);
  TTuiCapabilityPolicy = (tcpAuto, tcpEnable, tcpDisable, tcpRequire);

  TTuiCapabilityStatus = record
    Requested: Boolean;
    Detected: Boolean;
    Active: Boolean;
    Verified: Boolean;
    FallbackReason: AnsiString;

    class function Create(ARequested, ADetected, AActive, AVerified: Boolean;
      const AFallbackReason: AnsiString): TTuiCapabilityStatus; static;
  end;
```

`core/src/nextpas.core.tui.ext.pas`

```pascal
unit nextpas.core.tui.ext;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui,
  nextpas.core.tui.focus,
  nextpas.core.tui.interaction,
  nextpas.core.tui.keybind,
  nextpas.core.tui.theme,
  nextpas.core.tui.anim,
  nextpas.core.tui.animator,
  nextpas.core.tui.frame_budget,
  nextpas.core.tui.task,
  nextpas.core.tui.loading,
  nextpas.core.tui.app,
  nextpas.core.tui.app.screen,
  nextpas.core.tui.widget.panel,
  nextpas.core.tui.widget.chat_theme;
```

`core/src/nextpas.core.tui.experimental.pas`

```pascal
unit nextpas.core.tui.experimental;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui,
  nextpas.core.tui.image_cap,
  nextpas.core.tui.sixel,
  nextpas.core.tui.image_mgr,
  nextpas.core.tui.clipboard;
```

Use the existing TUI test Makefiles as the template. For example, `test_tui_ext_facade/Makefile` should mirror `test_tui_terminal/Makefile` with only `BUILD_DIR` and `PROGRAM` adjusted:

```make
FPC ?= fpc
CORE_ROOT := ../../..
BUILD_DIR ?= $(CORE_ROOT)/build/projects/nextpas.core.tui/test_tui_ext_facade
PROGRAM := test_tui_ext_facade
SOURCE := $(PROGRAM).lpr
FPC_FLAGS ?= -MObjFPC -Sh -O2 -gl -gh
FPC_FLAGS += -FU$(BUILD_DIR) -FE$(BUILD_DIR) -Fu$(CORE_ROOT)/src -Fi$(CORE_ROOT)/src
```

- [ ] **Step 4: Run the three focused tests again and make them pass**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_cap_base clean test
make -C core/tests/nextpas.core.tui/test_tui_ext_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_experimental_facade clean test
```

Expected:

- `1 total, 1 passed, 0 failed` from `test_tui_cap_base`
- `1 total, 1 passed, 0 failed` from `test_tui_ext_facade`
- `1 total, 1 passed, 0 failed` from `test_tui_experimental_facade`
- heaptrc summary includes `0 unfreed memory blocks`

- [ ] **Step 5: Commit the scaffolding slice**

```bash
git add \
  core/src/nextpas.core.tui.cap.base.pas \
  core/src/nextpas.core.tui.ext.pas \
  core/src/nextpas.core.tui.experimental.pas \
  core/tests/nextpas.core.tui/test_tui_cap_base \
  core/tests/nextpas.core.tui/test_tui_ext_facade \
  core/tests/nextpas.core.tui/test_tui_experimental_facade
git commit -m "feat(tui): add tier facade scaffolding"
```

## Task 2: Preserve the current broad API through `nextpas.core.tui.full`

**Files:**

- Create: `core/src/nextpas.core.tui.full.pas`
- Modify: `core/tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr`

- [ ] **Step 1: Repoint the wide compatibility test to the future full facade**

Change the `uses` clause in `core/tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr` from:

```pascal
uses
  nextpas.core.tui,
  nextpas.core.testing;
```

to:

```pascal
uses
  nextpas.core.tui.full,
  nextpas.core.testing;
```

- [ ] **Step 2: Run the compatibility test and confirm it fails because `full` is missing**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_facade clean test
```

Expected:

- `Fatal: Can't find unit nextpas.core.tui.full`

- [ ] **Step 3: Create `nextpas.core.tui.full` by copying the current wide facade**

Use the current `core/src/nextpas.core.tui.pas` as the seed:

```bash
cp core/src/nextpas.core.tui.pas core/src/nextpas.core.tui.full.pas
perl -0pi -e 's/unit nextpas\.core\.tui;/unit nextpas.core.tui.full;/' \
  core/src/nextpas.core.tui.full.pas
```

Then adjust the file header comment so the unit self-describes as the compatibility facade:

```pascal
unit nextpas.core.tui.full;

{**
 * @desc nextpas.core.tui.full 兼容门面——保留迁移期的全量公共 API。
 *       通过类型别名和 inline 转发聚合子模块。
 *}
```

- [ ] **Step 4: Re-run the compatibility test and make it pass unchanged**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_facade clean test
```

Expected:

- `5 total, 5 passed, 0 failed`
- heaptrc summary includes `0 unfreed memory blocks`

- [ ] **Step 5: Commit the compatibility-preservation slice**

```bash
git add \
  core/src/nextpas.core.tui.full.pas \
  core/tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr
git commit -m "feat(tui): preserve wide facade through full tier"
```

## Task 3: Narrow the default core facade and prove it with negative tests

**Files:**

- Modify: `core/src/nextpas.core.tui.pas`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_app.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_clipboard.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_core_facade/test_tui_core_facade_rejects_experimental.lpr`

- [x] **Step 1: Write the positive core-surface test and three negative compile probes**

`test_tui_core_facade.lpr`

```pascal
program test_tui_core_facade;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui,
  nextpas.core.testing;

procedure TestCoreSurface;
var
  LArea: TRect;
  LBuffer: TBuffer;
  LBlock: IBlock;
begin
  LArea := TRect.Make(0, 0, 10, 2);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    LBlock := TBlock.New.WithBorders(BORDERS_ALL).WithTitle('Core');
    LBlock.Render(LArea, LBuffer);
    Check(LBlock <> nil, 'core facade exposes basic widget contracts');
    CheckEqual(Word(10), LBuffer.Area.Width, 'core facade exposes buffer contract');
  finally
    LBuffer.Free;
  end;
end;
```

Negative probes:

```pascal
program test_tui_core_facade_rejects_app;
uses nextpas.core.tui;
var LApp: TApp;
begin
  LApp := nil;
end.
```

```pascal
program test_tui_core_facade_rejects_clipboard;
uses nextpas.core.tui;
var
  LClipboard: TClipboard;
  LMethod: Integer;
begin
  LClipboard := Default(TClipboard);
  LMethod := Ord(cmOSC52);
end.
```

```pascal
program test_tui_core_facade_rejects_experimental;
uses nextpas.core.tui;
var
  LProtocol: TImageProtocol;
begin
  LProtocol := DetectImageProtocol;
end.
```

- [x] **Step 2: Run the new core facade test target and confirm the negative probes currently fail the policy**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_core_facade clean test
```

Expected:

- the positive test may compile
- the `negative` target fails because `TApp`, `TClipboard`, or `TImageProtocol` are still visible from `nextpas.core.tui`

- [x] **Step 3: Shrink `core/src/nextpas.core.tui.pas` to the correctness-first export set**

Keep only the focused `uses` list:

```pascal
uses
  nextpas.core.tui.base,
  nextpas.core.tui.error,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.overlay,
  nextpas.core.tui.text,
  nextpas.core.tui.text.format,
  nextpas.core.tui.borders,
  nextpas.core.tui.layout,
  nextpas.core.tui.layout.grid,
  nextpas.core.tui.layout.dsl,
  nextpas.core.tui.event,
  nextpas.core.tui.input,
  nextpas.core.tui.ansi,
  nextpas.core.tui.backend.ansi,
  nextpas.core.tui.backend.test,
  nextpas.core.tui.terminal,
  nextpas.core.tui.widget.intf,
  nextpas.core.tui.widget.block,
  nextpas.core.tui.widget.paragraph,
  nextpas.core.tui.widget.list,
  nextpas.core.tui.widget.clear,
  nextpas.core.tui.widget.tabs,
  nextpas.core.tui.widget.scrollbar,
  nextpas.core.tui.widget.table,
  nextpas.core.tui.widget.input;
```

Delete re-exports for:

- `app`, `app.screen`
- `focus`, `interaction`, `keybind`
- `theme`, `anim`, `animator`, `frame_budget`, `task`, `loading`
- `image_cap`, `sixel`, `image_mgr`, `clipboard`
- advanced widget helpers that now belong in `ext` or remain only in `full`

- [x] **Step 4: Run the core-facade and compatibility tests together**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_core_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_ext_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_experimental_facade clean test
```

Expected:

- `test_tui_core_facade` passes
- the negative compiler logs contain `Identifier not found` for the rejected symbols
- `test_tui_facade` still passes through `nextpas.core.tui.full`
- `ext` and `experimental` continue to compile

- [x] **Step 5: Commit the default-surface freeze**

```bash
git add \
  core/src/nextpas.core.tui.pas \
  core/tests/nextpas.core.tui/test_tui_core_facade \
  core/tests/nextpas.core.tui/test_tui_facade/test_tui_facade.lpr
git commit -m "feat(tui): freeze correctness-first core facade"
```

## Task 4: Freeze terminal capability truth and conservative image-protocol hints

**Files:**

- Modify: `core/src/nextpas.core.tui.terminal.pas`
- Modify: `core/src/nextpas.core.tui.image_cap.pas`
- Modify: `core/tests/nextpas.core.tui/test_tui_terminal/test_tui_terminal.lpr`
- Create: `core/tests/nextpas.core.tui/test_tui_image_cap/Makefile`
- Create: `core/tests/nextpas.core.tui/test_tui_image_cap/test_tui_image_cap.lpr`

- [x] **Step 1: Add the failing capability-truth tests**

Append to `test_tui_terminal.lpr`:

```pascal
procedure TestCapabilityProfileSeparatesDetectedAndActiveStates;
var
  LProfile: TTuiTerminalCapabilityProfile;
begin
  LProfile := TTerminal.DetectCapabilityProfileFromHints(
    'truecolor', 'kitty', 'xterm-kitty', '', 'kitty-window');

  Check(LProfile.Truecolor.Requested, 'truecolor requested by default');
  Check(LProfile.Truecolor.Detected, 'truecolor env hint is recorded');
  Check(LProfile.Truecolor.Active, 'truecolor becomes active when hint is sufficient');
  Check(not LProfile.Truecolor.Verified, 'truecolor is not yet verified');
end;
```

Create `test_tui_image_cap.lpr`:

```pascal
program test_tui_image_cap;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.image_cap,
  nextpas.core.testing;

procedure TestDetectsKittyProtocolFromKnownHints;
begin
  CheckEqual(Ord(ipKitty), Ord(DetectImageProtocolFromHints(
    'xterm-kitty', '', '', '')),
    'TERM=xterm-kitty selects kitty');
end;
```

- [x] **Step 2: Run the terminal/image-cap tests and confirm they fail on missing types and helpers**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_terminal clean test
make -C core/tests/nextpas.core.tui/test_tui_image_cap clean test
```

Expected:

- compile failure for `TTuiTerminalCapabilityProfile` / `DetectCapabilityProfileFromHints`
- compile failure for `DetectImageProtocolFromHints`

- [x] **Step 3: Replace boolean capability fields with structured status records**

Add the new terminal-side contract:

```pascal
uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.cap.base,
  nextpas.core.tui.error,
  ...
```

```pascal
type
  TTuiImageProtocolCapability = record
    DetectedProtocol: TImageProtocol;
    ActiveProtocol: TImageProtocol;
    Status: TTuiCapabilityStatus;
  end;

  TTuiTerminalCapabilityProfile = record
    Truecolor: TTuiCapabilityStatus;
    KittyKeyboard: TTuiCapabilityStatus;
    ImageProtocol: TTuiImageProtocolCapability;
  end;
```

Replace the old fields:

```pascal
FHasTruecolor: Boolean;
FHasKittyKeyboard: Boolean;
FImageProtocol: TImageProtocol;
```

with:

```pascal
FCapabilityProfile: TTuiTerminalCapabilityProfile;
function GetHasTruecolor: Boolean; inline;
function GetHasKittyKeyboard: Boolean; inline;
function GetImageProtocol: TImageProtocol; inline;
```

Add deterministic hint helper to `image_cap`:

```pascal
function DetectImageProtocolFromHints(const ATerm, ATermProgram,
  ATermFeatures, AKittyWindowId: AnsiString): TImageProtocol;
```

Implement the conservative branches exactly as the tests demand:

- empty hints -> `ipHalfBlock`
- kitty/wezterm/ghostty hints -> `ipKitty`
- sixel/foot/mlterm/contour/xterm/yaft hints -> `ipSixel`

- [x] **Step 4: Re-run the capability-focused tests and make them pass**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_cap_base clean test
make -C core/tests/nextpas.core.tui/test_tui_terminal clean test
make -C core/tests/nextpas.core.tui/test_tui_image_cap clean test
```

Expected:

- `test_tui_terminal` passes with the new capability profile checks
- `test_tui_image_cap` passes with deterministic hint coverage
- heaptrc summary remains `0 unfreed memory blocks`

- [x] **Step 5: Commit the capability-truth slice**

```bash
git add \
  core/src/nextpas.core.tui.terminal.pas \
  core/src/nextpas.core.tui.image_cap.pas \
  core/tests/nextpas.core.tui/test_tui_terminal/test_tui_terminal.lpr \
  core/tests/nextpas.core.tui/test_tui_image_cap
git commit -m "feat(tui): freeze terminal capability runtime truth"
```

## Task 5: Align docs and lock the focused verification envelope

**Files:**

- Modify: `core/docs/tui/README.md`
- Modify: `core/docs/tui/ARCHITECTURE.md`
- Create: `core/docs/tui/TIER_REGISTRY.md`

- [x] **Step 1: Update the public docs to explain the four facades**

`core/docs/tui/README.md` must lead with:

```markdown
- `uses nextpas.core.tui`
  Core 默认入口。只带终端正确性的最小闭包。
- `uses nextpas.core.tui.ext`
  稳定增强入口。需要 `TApp`、panel、theme、task、frame budget 时用它。
- `uses nextpas.core.tui.experimental`
  实验能力入口。图像协议、clipboard 这类高波动能力显式 opt-in。
- `uses nextpas.core.tui.full`
  迁移兼容入口。保留旧的宽门面。
```

`core/docs/tui/ARCHITECTURE.md` must add:

```markdown
Since the surface-freeze slice, the public surface is split into four facades:

- `nextpas.core.tui`
- `nextpas.core.tui.ext`
- `nextpas.core.tui.experimental`
- `nextpas.core.tui.full`
```

- [x] **Step 2: Add the tier registry**

Create `core/docs/tui/TIER_REGISTRY.md` with the frozen ownership list:

```markdown
## Core facade

- `nextpas.core.tui.base`
- `nextpas.core.tui.buffer`
- `nextpas.core.tui.terminal`
- `nextpas.core.tui.widget.block`

## Extended facade

- `nextpas.core.tui.app`
- `nextpas.core.tui.task`
- `nextpas.core.tui.widget.panel`

## Experimental facade

- `nextpas.core.tui.image_cap`
- `nextpas.core.tui.sixel`
- `nextpas.core.tui.clipboard`
```

- [x] **Step 3: Run the full focused TUI envelope for this milestone**

Run:

```bash
make -C core/tests/nextpas.core.tui/test_tui_cap_base clean test
make -C core/tests/nextpas.core.tui/test_tui_core_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_ext_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_experimental_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_facade clean test
make -C core/tests/nextpas.core.tui/test_tui_terminal clean test
make -C core/tests/nextpas.core.tui/test_tui_image_cap clean test
make -C core/tests/nextpas.core.tui/test_tui_backend clean test
make -C core/tests/nextpas.core.tui/test_tui_buffer clean test
make -C core/tests/nextpas.core.tui/test_tui_widget_intf clean test
core/benchmarks/nextpas.core.tui/run_all.sh
```

Expected:

- all focused tests pass
- every test program prints heaptrc `0 unfreed memory blocks`
- benchmark smoke exits `status=0`

- [x] **Step 4: Check repo hygiene before the closeout commit**

Run:

```bash
git diff --check
git status --short --branch
```

Expected:

- `git diff --check` prints nothing
- `git status` only shows the intended doc/test/source changes

- [ ] **Step 5: Commit the docs and verification slice**

```bash
git add \
  core/docs/tui/README.md \
  core/docs/tui/ARCHITECTURE.md \
  core/docs/tui/TIER_REGISTRY.md
git commit -m "docs(tui): publish tiered facade contract"
```

## Self-review checklist

- Spec coverage:
  - facade split -> Tasks 1, 2, 3
  - capability runtime truth -> Task 4
  - focused TUI-only verification -> Task 5
  - docs and migration guidance -> Tasks 2 and 5
- Placeholder scan:
  - no placeholder markers or unnamed “appropriate handling” steps remain
- Type consistency:
  - `TTuiCapabilityStatus`, `TTuiTerminalCapabilityProfile`, `DetectImageProtocolFromHints`,
    `nextpas.core.tui.ext`, `nextpas.core.tui.experimental`, and `nextpas.core.tui.full`
    are introduced before later tasks depend on them
