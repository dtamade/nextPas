# nextpas.core.tui Architecture

## Overview

`nextpas.core.tui` is a FreePascal TUI rendering framework inspired by ratatui's design: immediate-mode rendering, double-buffered diff, and array-based cell layout.

## Layer Diagram

```
┌─────────────────────────────────────────────┐
│  Application (TApp, event loop)             │
├─────────────────────────────────────────────┤
│  Widgets (IWidget interface hierarchy)      │
│  Block, Paragraph, List, Table, Tree, ...   │
├─────────────────────────────────────────────┤
│  Layout (TConstraint solver, Grid, DSL)     │
├─────────────────────────────────────────────┤
│  Buffer (TBuffer: cell array + diff engine) │
│  Text (TSpan/TLine/TText)                   │
├─────────────────────────────────────────────┤
│  Terminal (TTerminal: frame lifecycle)       │
│  ANSI Backend (escape sequence emitter)     │
├─────────────────────────────────────────────┤
│  Platform (console, signal, time, io)       │
└─────────────────────────────────────────────┘
```

## Core Design Principles

### 1. Immediate Mode Rendering

Widgets do not hold render state. Every frame:
1. `TTerminal.BeginFrame` → fresh `TBuffer`
2. Application calls `widget.Render(area, buffer)` for each widget
3. `TTerminal.EndFrame` → diff prev/curr buffers → emit ANSI patches

### 2. Interface-First Widget System

All widgets implement `IWidget`:
```pascal
IWidget = interface
  procedure Render(const AArea: TRect; ABuffer: TBuffer);
end;
```

Each widget has a specific interface (e.g., `IBlock`, `ITable`, `ITree`) extending `IWidget` with builder methods and stateful render. Factory pattern: `TXxx.New(...): IXxx`.

### 3. Zero-Allocation Hot Path

- `TCell` = 40-byte packed record (inline glyph + style + width)
- `TBuffer.FContent` = contiguous `array of TCell`
- Diff engine uses QWord×5 comparison per cell
- ANSI output via `TStringBuilder` (append-only byte buffer)
- Dirty-row bitmap skips unchanged rows without memcmp

### 4. Data Types as Records

`TRect`, `TColor`, `TStyle`, `TCell`, `TModifier`, layout constraints, state types — all records. Zero heap allocation for data flow.

## Key Units (77 total)

| Layer | Units |
|-------|-------|
| Base types | base, error, color, modifier, style, cell |
| Buffer | buffer, overlay, image_cap |
| Text | text, text.format |
| Layout | layout, layout.grid, layout.dsl |
| Borders | borders |
| ANSI | ansi, backend.ansi, backend.test |
| Terminal | terminal |
| Event/Input | event, input, interaction, focus, keybind |
| Widgets | widget.intf + 40 widget units |
| App | app, app.screen, anim, animator, theme, task, frame_budget, clipboard, sixel |
| Facade | nextpas.core.tui (re-exports) |

## Public Facade

`nextpas.core.tui` is the preferred public entry point. Because FPC does not automatically re-export
symbols from units listed in `uses`, the facade declares explicit type aliases and inline forwarding
functions for public TUI contracts.

The facade exposes natural names (`TRect`, `TBuffer`, `IWidget`, `TBlock`, `BORDERS_ALL`) and keeps
existing `TTui*` / `ITui*` compatibility aliases. `TWidgetAdapter` is intentionally retained as an
extension bridge for wrapping a non-nil `TWidgetRenderFn` as `IWidget`; built-in widgets should still
prefer dedicated `class(TInterfacedObject, IWidget, IXxx)` implementations.

## Performance

Measured on x86_64, FPC 3.3.1, -O2:

- Full render (120×40, 4 widgets): 119μs/frame
- Buffer diff (200×50): 26-47μs/frame
- Input parse: 44-134ns/event
- Layout solve: 354ns-4.3μs
- StringDisplayWidth: 20ns/80B ASCII (AVX2+SSE2 SIMD)

All well within 60 FPS budget (16ms).
