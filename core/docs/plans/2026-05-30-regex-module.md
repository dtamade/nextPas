# nextpas.core.regex — Regex Engine Design

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Best-in-class regex engine for FreePascal — O(n) guaranteed matching, SIMD-accelerated literal search, compile-once/match-many.

**Architecture:** Thompson NFA with SIMD literal prefix optimization. No backtracking (RE2 safety guarantee). Submatch capture via tagged NFA simulation.

**Reference implementations:** Go regexp, Rust regex crate, RE2.

---

## Architecture Overview

```
Pattern string
    │
    ▼
┌─────────┐     ┌──────────┐     ┌───────────┐
│  Parser  │────▶│ Compiler │────▶│  TRegex   │ (compiled, reusable)
└─────────┘     └──────────┘     └───────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   NFA Executor   │
                              │  + SIMD Prefilter│
                              └─────────────────┘
                                       │
                                       ▼
                              ┌─────────────────┐
                              │   TMatch result  │
                              └─────────────────┘
```

## Module Structure

```
src/
  nextpas.core.regex.pas           — facade (RegexCompile/RegexMatch/RegexFind)
  nextpas.core.regex.parser.pas    — pattern → AST
  nextpas.core.regex.compiler.pas  — AST → NFA bytecode
  nextpas.core.regex.nfa.pas       — NFA execution engine
  nextpas.core.regex.types.pas     — shared types (TRegex, TMatch, opcodes)
  nextpas.core.regex.charclass.pas — character class tables (\d, \w, \s, Unicode)
tests/
  test_regex_basic/test_regex_basic.lpr
  test_regex_charclass/test_regex_charclass.lpr
  test_regex_capture/test_regex_capture.lpr
benchmarks/
  bench_regex/bench_regex.lpr
  bench_regex/compare_go/main.go
  bench_regex/compare_rust/main.rs
```

## Core Types

```pascal
type
  TRegex = record
  private
    FProgram: TRegexProgram;   // compiled NFA bytecode
    FLiteralPrefix: string;    // for SIMD prefilter
    FFlags: TRegexFlags;
  public
    class function Compile(const APattern: string): TRegex; static;
    function IsMatch(const AInput: string): Boolean;
    function Find(const AInput: string): TMatch;
    function FindAll(const AInput: string): TMatchArray;
    function Replace(const AInput, AReplacement: string): string;
    function Split(const AInput: string): TStringArray;
  end;

  TMatch = record
    Found: Boolean;
    Start: SizeUInt;      // 0-based byte offset
    Len: SizeUInt;
    Value: string;        // matched substring
    Groups: TGroupArray;  // captured groups
  end;

  TGroup = record
    Start: SizeUInt;
    Len: SizeUInt;
    Value: string;
  end;
```

## Supported Syntax (Phase 1)

| Syntax | Meaning |
|--------|---------|
| `.` | any char (except newline) |
| `*` | zero or more |
| `+` | one or more |
| `?` | zero or one |
| `\|` | alternation |
| `()` | capture group |
| `[]` | character class |
| `[^]` | negated class |
| `^` `$` | anchors |
| `\d` `\D` | digit / non-digit |
| `\w` `\W` | word char / non-word |
| `\s` `\S` | whitespace / non-whitespace |
| `\b` | word boundary |
| `{n}` `{n,m}` | repetition |
| `(?:)` | non-capturing group |

## NFA Bytecode (Instruction Set)

```pascal
type
  TOpCode = (
    opLiteral,      // match single byte
    opAnyChar,      // match any (except \n)
    opCharClass,    // match character class
    opSplit,        // fork: try both branches (NFA non-determinism)
    opJump,         // unconditional jump
    opMatch,        // accept state
    opSave,         // save submatch position
    opAssertStart,  // ^ anchor
    opAssertEnd,    // $ anchor
    opAssertWord    // \b word boundary
  );

  TInstruction = record
    Op: TOpCode;
    case TOpCode of
      opLiteral: (Ch: Byte);
      opCharClass: (ClassIdx: UInt16; Negated: Boolean);
      opSplit: (X, Y: UInt16);  // two target PCs
      opJump: (Target: UInt16);
      opSave: (Slot: UInt16);   // submatch slot index
  end;
```

## SIMD Prefilter Strategy

Before running the NFA, extract literal prefix from the pattern:
- `hello.*world` → prefix = "hello", use ScanFindByte/memchr to skip
- `\d+@\w+` → no useful prefix, run NFA from every position
- `[Hh]ello` → first byte candidates {H, h}, use ScanFindByte2

This gives 10-100x speedup for patterns with literal prefixes (most real-world patterns).

## Execution Model (Thompson NFA Simulation)

```
for each input position:
  1. SIMD prefilter: skip to next candidate position
  2. Initialize NFA: add start state to current-set
  3. For each input byte:
     - For each state in current-set:
       - If state matches input byte: add next-state to next-set
       - If state is Split: add both targets to current-set (epsilon closure)
     - Swap current-set and next-set
  4. If any state in current-set is Match: return success
```

Key property: current-set size is bounded by program length (no exponential blowup).

## Performance Targets

| Operation | Target | Go regexp | Rust regex |
|-----------|--------|-----------|------------|
| Compile simple | < 5μs | ~10μs | ~5μs |
| IsMatch literal | < 100ns/KB | ~200ns/KB | ~50ns/KB |
| IsMatch complex | < 500ns/KB | ~1μs/KB | ~200ns/KB |
| FindAll | < 1μs/match | ~2μs | ~0.5μs |

## Implementation Phases

### Phase 1: Core Engine (this PR)
- Parser: pattern → AST
- Compiler: AST → NFA bytecode
- Executor: Thompson NFA simulation
- SIMD prefilter for literal prefixes
- Basic API: Compile/IsMatch/Find/FindAll/Replace/Split
- Tests: 30+ covering all syntax elements
- Zero memory leaks

### Phase 2: Performance (next PR)
- Lazy DFA cache for hot patterns
- One-pass NFA for simple patterns (O(n) with capture)
- Benchmark vs Go/Rust

### Phase 3: Advanced (future)
- Unicode categories (\p{L}, \p{N})
- Named groups (?P<name>...)
- Lookahead/lookbehind (limited, non-backtracking subset)
- Regex set (match multiple patterns simultaneously)

## Quality Gates

- All syntax elements have at least 2 tests (positive + negative)
- heaptrc zero leaks
- No exponential blowup: `a?^30 a^30` must complete in < 1ms
- Compile errors produce clear messages with position
- Thread-safe: compiled TRegex is immutable, safe to share
