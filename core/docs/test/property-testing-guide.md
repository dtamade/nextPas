# Property-based Testing & Fuzzing API Reference

> nextpas.core.test v8.0b — QuickCheck-style property testing with coverage-guided fuzzing

## Quick Start

```pascal
uses nextpas.core.test;

{ 1. Define a property }
procedure TestReverseTwice(const S: string);
begin
  CheckEqual(S, ReverseString(ReverseString(S)));
end;

{ 2. Register and run }
Prop('Reverse twice is identity', @TestReverseTwice, GenString(1000), 500);
```

## Generators

Generators produce random values for property testing. All generators support automatic shrinking on failure.

### Basic Generators

| Generator | Type | Description |
|-----------|------|-------------|
| `GenString(maxLen)` | `IStringGenerator` | Random printable ASCII string (0..maxLen) |
| `GenString(minLen, maxLen)` | `IStringGenerator` | Random string with length range |
| `GenInt(max)` | `IIntGenerator` | Random Int64 in [0, max] |
| `GenInt(min, max)` | `IIntGenerator` | Random Int64 in [min, max] |
| `GenBytes(maxLen)` | `IBytesGenerator` | Random byte array (0..maxLen) |
| `GenBytes(minLen, maxLen)` | `IBytesGenerator` | Random bytes with length range |
| `GenBool` | `IBoolGenerator` | Random Boolean |

### Choice & OneOf

```pascal
{ Pick from predefined values }
GenChoiceInt([1, 10, 100, 1000])
GenChoiceString(['hello', 'world', ''])
GenChoiceBool([True, False])

{ Combine multiple generators (randomly pick one per Generate) }
GenOneOfInt([GenInt(0, 10), GenInt(100, 200), GenChoiceInt([999])])
GenOneOfString([GenString(10), GenString(100)])
```

### Structured Generators (v8.0a)

```pascal
{ Random-length array of Int64 }
GenArray(GenInt(0, 100), 50)           { max length 50 }
GenArray(GenInt(0, 100), 5, 20)        { length in [5, 20] }

{ Tuple (Int64, String) }
GenTuple(GenInt(1, 100), GenString(50))

{ FlatMap: second generator depends on first }
BindInt(GenInt(1, 100), function(V: Int64): IIntGenerator
begin
  Result := GenInt(0, V);  { second value in [0, first value] }
end)
```

### Combinators

```pascal
{ Map: transform Int64 to String }
MapIntToStr(GenInt(0, 9999), function(V: Int64): string
begin
  Result := IntToStr(V);
end)

{ Filter: reject values not matching predicate }
FilterInt(GenInt(0, 1000), function(V: Int64): Boolean
begin
  Result := V mod 2 = 0;  { even numbers only }
end)

FilterString(GenString(100), function(const S: string): Boolean
begin
  Result := Length(S) > 0;  { non-empty only }
end)

FilterBytes(GenBytes(100), function(const V: TBytes): Boolean
begin
  Result := Length(V) > 0;
end)
```

## Property Testing

### Prop — Register a Property Test

```pascal
{ String property }
Prop('name', stringTest, gen, runs, shrink);

{ Int64 property }
Prop('name', intTest, gen, runs, shrink);

{ Boolean property }
Prop('name', boolTest, gen, runs, shrink);

{ TBytes property }
Prop('name', bytesTest, gen, runs, shrink);

{ Array property (v8.0a) }
PropArray('name', arrayTest, gen, runs, shrink);

{ Tuple property (v8.0a) }
PropTuple('name', tupleTest, gen, runs);
```

Parameters:
- `name`: Test name for reporting
- `test`: Anonymous procedure receiving the generated value
- `gen`: Generator producing random inputs
- `runs`: Number of random inputs to try (default 100)
- `shrink`: Whether to shrink on failure (default True)

### PropFail — Signal a Property Failure

Use `PropFail` inside property test bodies instead of `FailTest`:

```pascal
Prop('no negatives', procedure(const V: Int64)
begin
  if V < 0 then
    PropFail('Negative value: ' + IntToStr(V));
end, GenInt(0, 1000));
```

### PropWithResult — Get Shrunk Value

```pascal
var LResult: string;
LResult := PropWithResult('name', test, gen, runs, shrink);
if LResult <> '' then
  WriteLn('Minimal failing input: ', LResult);
```

## Shrinking

When a property fails, the framework automatically tries to find a minimal failing input:

1. **Int64**: Binary search toward 0, respecting generator min bounds
2. **String**: 8 strategies — empty, half, remove-last, replace-all, remove-first, remove-mid, shorter, half-shorter
3. **TBytes**: Binary chunk removal + individual byte removal
4. **Array**: Element removal toward empty array

Shrinking preserves the property failure — the minimal input still fails the test.

## Fuzzing

### Basic Fuzzing (v7.2a)

```pascal
{ Fuzz with byte corpus }
Fuzz('parser test', procedure(const Data: TBytes)
begin
  MyParser.Parse(Data);
end, [seed1, seed2], 10000);

{ Fuzz with string corpus }
FuzzString('json test', procedure(const S: string)
begin
  JsonDecode(S);
end, ['{"a":1}', '[]'], 10000);

{ Generate seed corpus }
FuzzGenBytes(32);   { random 32 bytes }
FuzzGenString(50);  { random 50-char string }
```

Mutation strategies (weighted random):
- 40% bit flip (1-3 bits)
- 25% byte replace
- 15% byte insert
- 10% byte delete
- 5% block duplicate
- 5% block swap

### Corpus Management (v7.3a)

```pascal
{ Persistent corpus — loads from disk, saves new discoveries }
FuzzWithCorpus('test', testProc, '/tmp/corpus_dir', 10000);
FuzzStringWithCorpus('test', testProc, '/tmp/corpus_dir', 10000);

{ Manual corpus management }
var Corpus: TFuzzCorpus;
Corpus := TFuzzCorpus.Create('/tmp/my_corpus');
try
  Corpus.Load;
  Corpus.Add(someBytes);
  Corpus.AddString('some string');
  Corpus.Save;
  WriteLn('Corpus: ', Corpus.Count, ' items');
finally
  Corpus.Free;
end;
```

### Structured Fuzzing (v8.0b)

Uses generators for structured input with coverage-guided exploration:

```pascal
{ Int64 structured fuzzing with coverage tracking }
var Tracker: ICoverageTracker;
Tracker := CreateCoverageTracker;

FuzzStructured('range test', procedure(const V: Int64; ACoverage: ICoverageTracker)
begin
  { Mark coverage points based on value ranges }
  if V < 0 then ACoverage.Hit(0)
  else if V < 100 then ACoverage.Hit(1)
  else if V < 1000 then ACoverage.Hit(2)
  else ACoverage.Hit(3);

  { Property to test }
  if V < 0 then
    PropFail('Negative: ' + IntToStr(V));
end, GenInt(0, 1000), Tracker, 5000);

{ String structured fuzzing }
FuzzStructured('string test', procedure(const S: string; ACoverage: ICoverageTracker)
begin
  if Length(S) = 0 then ACoverage.Hit(0)
  else if Length(S) < 10 then ACoverage.Hit(1)
  else ACoverage.Hit(2);
end, GenString(100), Tracker, 5000);
```

### Parallel Fuzzing (v8.0b)

Multiple workers with different mutation strategies sharing a corpus:

```pascal
FuzzParallel('parser test', procedure(const Data: TBytes)
begin
  MyParser.Parse(Data);
end, [seed1, seed2, seed3],  { seed corpus }
  4,    { workers: 1-4, each with different strategy }
  2500  { iterations per worker }
);
```

Strategies:
- Worker 0: BitFlip — bit-level mutations
- Worker 1: ByteReplace — byte-level replacements
- Worker 2: Havoc — heavy mutations (insert/delete/dup/swap)
- Worker 3: Structured — mixed mutations

Coverage tracking ensures only inputs expanding coverage are kept.

## Coverage Tracking (v8.0b)

```pascal
var Tracker: ICoverageTracker;
Tracker := CreateCoverageTracker;

{ Mark coverage points in your code }
Tracker.Hit(0);  { coverage point 0 }
Tracker.Hit(5);  { coverage point 5 }

{ Check state }
Tracker.HasNewCoverage;   { True if new points hit since last reset }
Tracker.CoverageCount;    { unique points hit }
Tracker.TotalHits;        { total hits including duplicates }

{ Reset for next iteration }
Tracker.ResetNewCoverage;
```

Supports 4096 coverage points (IDs 0-4095). Uses bitset for O(1) lookup.

## Assertion API (v8.0c)

### Array Comparison

```pascal
{ Compare Int64 arrays }
CheckArrayEqual([1, 2, 3], [1, 2, 3]);           { pass }
CheckArrayEqual([1, 2, 3], [1, 99, 3]);          { fail: "Arrays differ at index 1: expected 2 but got 99" }
CheckArrayEqual([1, 2], [1, 2, 3]);               { fail: "Expected array length 2 but got 3" }
CheckArrayEqual([1, 2], [1, 99], 'my context');   { fail: "my context: Arrays differ at index 1..." }
```

### Interface Nil Checks

```pascal
var LI: IInterface;
LI := nil;
CheckIsNil(LI);        { pass }
CheckIsNotNil(LI);     { fail: "Expected non-nil interface but got nil" }

var Obj: IInterface;
Obj := CreateCoverageTracker;
CheckIsNotNil(Obj);    { pass }
CheckIsNil(Obj);       { fail: "Expected nil interface but got non-nil" }
CheckIsNotNil(Obj, 'tracker created');  { pass, custom message on fail }
```

## Test Suite Summary

| Suite | Tests | Coverage |
|-------|-------|----------|
| test_assertions | 135 | Check* API, NaN, Unicode, snapshots, array/interface |
| test_prop | 37 | Property testing, fuzzing, corpus, coverage, parallel |
| test_expect | 42 | Expect fluent API |
| test_mock | 45 | Mock framework |
| test_subtests | 28 | Subtests, nesting, skip |
| test_parallel | 24 | Parallel execution |
| test_runner | 18 | CLI, filtering, config |
| test_output | 15 | TAP/JSON/JUnit output |
| test_lifecycle | 12 | BeforeAll/AfterAll/BeforeEach/AfterEach |
| test_diagnostics | 10 | Error messages, stack traces |
| test_stress | 8 | Load/stress tests |
| test_advanced | 12 | Property-based advanced features |
| **Total** | **386** | |
