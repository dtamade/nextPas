# Changelog

## 0.9.0 (2026-06-01) — Migration Complete

Full migration from fafafa.tui to nextpas.core.tui.

### Architecture
- Immediate-mode rendering with double-buffered diff (ratatui model)
- 77 source units, layered: base → buffer → layout → widgets → terminal → app
- All 40 widgets implement IWidget interface (class + COM reference counting)
- Platform integration via nextpas.core.platform (console/signal/time/io)

### Widgets (40 total)
- Core: Block, Paragraph, List, Table, Gauge, Tabs, Scrollbar, Clear, Input, Sparkline, BarChart, Canvas
- Extended: Tree, Dialog, Menu, Panel, SplitPane, Modal, Popover, Tooltip, Select, ScrollView, Calendar, Breadcrumb, StatusBar, Timeline, ProgressGroup, LineChart, InputEditor, DiffView, FileTree, Kanban, Markdown, VirtualList, CommandPalette, NotificationCenter, ToastManager, Checkbox, RadioGroup

### Performance Optimizations
- AVX2+SSE2 SIMD for StringDisplayWidth (3.4-5x faster on ASCII)
- Dirty-row bitmap in TBuffer (skips ~80% of CompareByte in real apps)
- Zero-allocation hot path (packed records, array-based cells)

### Unicode
- UAX#11 East Asian Width (63 ranges, 45 zero-width ranges)
- UAX#29 Grapheme Cluster segmentation (Extend, ZWJ, Regional Indicator, SpacingMark)
- Full UTF-8 decode/encode with SIMD validation

### Input
- CSI sequences (arrows, function keys, modifiers)
- Kitty keyboard protocol (CSI u)
- SGR mouse protocol (1006h) with motion tracking (1003h)
- Bracketed paste (CSI 200~/201~)

### Testing
- 32 TUI test projects, 240 TUI test cases, 0 memory leaks in heaptrc-covered runs
- 4K terminal stress tests (300x80, 10000-item lists)
- Input parser fuzz harness with 12-file corpus
- 4 benchmarks (diff, render, input, layout)
- TUI benchmark smoke entrypoint for CI compile/run coverage

### Documentation
- ARCHITECTURE.md, WIDGET_CATALOG.md, BENCHMARK.md
- Goal tree with full phase tracking
