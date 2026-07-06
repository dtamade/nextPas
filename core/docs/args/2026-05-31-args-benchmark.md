# nextpas.core.args Benchmark Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Benchmark nextpas.core.args parse performance against Go flag/cobra and Rust clap, proving competitive or superior throughput.

**Architecture:** Single benchmark binary using `nextpas.core.bench.TBenchRunner`, plus Go and Rust comparison programs with identical workloads.

**Tech Stack:** Free Pascal (nextpas.core.bench), Go (flag + cobra), Rust (clap)

---

## Benchmark Scenarios

| Scenario | Description |
|----------|-------------|
| ParseEmpty | Parse with no args (baseline overhead) |
| ParseFlags | Parse 5 boolean flags |
| ParseMixed | Parse flags + string + int + positional (compiler-like) |
| ParseStringList | Parse 10 repeatable -I flags |
| ParseCluster | Parse clustered short flags -vdfO3 |
| SubcommandDispatch | TArgApp route to 1 of 10 commands |
| HelpGeneration | Generate help text for complex parser |

---

## Task 1: Pascal Benchmark

**Files:**
- Create: `benchmarks/nextpas.core.args/bench_args/bench_args.lpr`
- Create: `benchmarks/nextpas.core.args/bench_args/Makefile`

**Step 1: Write benchmark program**

```pascal
program bench_args;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.bench,
  nextpas.core.args;

var
  B: TBenchRunner;

procedure BenchParseEmpty(aIters: Int64);
var it: Int64; P: TArgParser;
begin
  for it := 1 to aIters do
  begin
    P := TArgParser.Create('test', '');
    P.SetAutoHelp(False);
    P.ParseFrom([]);
    P.Free;
  end;
end;

procedure BenchParseFlags(aIters: Int64);
var it: Int64; P: TArgParser;
begin
  for it := 1 to aIters do
  begin
    P := TArgParser.Create('test', '');
    P.AddFlag('verbose', 'v', '');
    P.AddFlag('debug', 'd', '');
    P.AddFlag('force', 'f', '');
    P.AddFlag('quiet', 'q', '');
    P.AddFlag('recursive', 'r', '');
    P.ParseFrom(['-v', '-d', '-f', '-q', '-r']);
    P.Free;
  end;
end;

procedure BenchParseMixed(aIters: Int64);
var it: Int64; P: TArgParser;
begin
  for it := 1 to aIters do
  begin
    P := TArgParser.Create('nextpas', '');
    P.SetAutoHelp(False);
    P.AddFlag('verbose', 'v', '');
    P.AddString('output', 'o', '', 'a.out');
    P.AddInt('opt-level', 'O', '', 2);
    P.AddChoice('target', 't', '', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
    P.AddPositional('input', '', True);
    P.ParseFrom(['-v', '--output', 'main', '-O', '3', '--target=aarch64', 'input.pas']);
    P.Free;
  end;
end;

procedure BenchParseStringList(aIters: Int64);
var it: Int64; P: TArgParser;
begin
  for it := 1 to aIters do
  begin
    P := TArgParser.Create('test', '');
    P.SetAutoHelp(False);
    P.AddStringList('include', 'I', '');
    P.ParseFrom(['-I', '/a', '-I', '/b', '-I', '/c', '-I', '/d', '-I', '/e',
                  '-I', '/f', '-I', '/g', '-I', '/h', '-I', '/i', '-I', '/j']);
    P.Free;
  end;
end;

procedure BenchParseCluster(aIters: Int64);
var it: Int64; P: TArgParser;
begin
  for it := 1 to aIters do
  begin
    P := TArgParser.Create('test', '');
    P.SetAutoHelp(False);
    P.AddFlag('verbose', 'v', '');
    P.AddFlag('debug', 'd', '');
    P.AddFlag('force', 'f', '');
    P.AddInt('opt-level', 'O', '', 0);
    P.ParseFrom(['-vdfO3']);
    P.Free;
  end;
end;

procedure BenchSubcommand(aIters: Int64);
var it: Int64; A: TArgApp; i: Integer;
const
  CMDS: array[0..9] of string = (
    'build','run','test','fmt','lint','doc','clean','install','publish','check');
begin
  for it := 1 to aIters do
  begin
    A := TArgApp.Create('tool', '', '1.0');
    for i := 0 to 9 do
      A.AddCommand(CMDS[i], '');
    A.RunFrom(['check']);
    A.Free;
  end;
end;

procedure BenchHelpGen(aIters: Int64);
var it: Int64; P: TArgParser; s: string;
begin
  P := TArgParser.Create('nextpas', 'NextPas Compiler');
  P.AddFlag('verbose', 'v', 'Enable verbose output');
  P.AddFlag('debug', 'd', 'Debug mode');
  P.AddString('output', 'o', 'Output file', 'a.out');
  P.AddInt('opt-level', 'O', 'Optimization level', 2);
  P.AddChoice('target', 't', 'Target', ['x86_64', 'aarch64', 'wasm32'], 'x86_64');
  P.AddStringList('include', 'I', 'Include path');
  P.AddRequiredString('config', 'c', 'Config file');
  P.AddPositional('input', 'Input file', True);
  P.AddPositional('extra', 'Extra files', False);
  for it := 1 to aIters do
    s := P.HelpText;
  P.Free;
end;

begin
  B := TBenchRunner.Create;
  WriteLn('=== nextpas.core.args benchmark ===');
  B.Run('ParseEmpty', @BenchParseEmpty);
  B.Run('ParseFlags(5)', @BenchParseFlags);
  B.Run('ParseMixed(compiler-like)', @BenchParseMixed);
  B.Run('ParseStringList(10x-I)', @BenchParseStringList);
  B.Run('ParseCluster(-vdfO3)', @BenchParseCluster);
  B.Run('SubcommandDispatch(10cmds)', @BenchSubcommand);
  B.Run('HelpGeneration', @BenchHelpGen);
  B.Summary;
  B.Free;
end.
```

**Step 2: Write Makefile**

Standard project Makefile matching existing benchmark pattern.

**Step 3: Build and run**

Run: `make run`
Expected: benchmark output with ns/op and ops/s

---

## Task 2: Go Comparison

**Files:**
- Create: `benchmarks/nextpas.core.args/bench_args/compare_go/main.go`

Implements identical scenarios using Go `flag` package (ParseEmpty, ParseFlags, ParseMixed) to establish baseline.

---

## Task 3: Rust Comparison

**Files:**
- Create: `benchmarks/nextpas.core.args/bench_args/compare_rust/main.rs`

Implements identical scenarios using Rust `clap` crate to establish high-water mark.

---

## Execution Order

1. Task 1 (Pascal benchmark) — verify it runs
2. Task 2 (Go comparison) — compile and run
3. Task 3 (Rust comparison) — compile and run
4. Compare results and report
