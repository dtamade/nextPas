# nextpas.core.regex

Production-quality regular expression engine for FreePascal.

## Features

- Thompson NFA with O(n) time guarantee (no backtracking)
- SIMD-accelerated literal prefix search
- Start byte class prefilter for non-literal patterns
- POSIX leftmost-longest match semantics
- Case-insensitive matching (`(?i)` inline flag or `rfCaseInsensitive` compile flag)
- Named capture groups `(?P<name>...)`
- Compile-time safety limits (depth, repeat count, program size)
- Zero memory leaks (including error paths)
- 106 unit tests

## Quick Start

```pascal
uses nextpas.core.regex;

var
  R: TRegex;
  M: TMatch;
  Matches: TMatchArray;
  Parts: TStringArray;
begin
  // Compile a pattern
  R := TRegex.Compile('\d{4}-\d{2}-\d{2}');

  // Check if input matches
  if R.IsMatch('Today is 2026-05-31') then
    WriteLn('Found a date!');

  // Find first match
  M := R.Find('Dates: 2026-05-31 and 2026-06-01');
  if M.Found then
    WriteLn('First date: ', M.Value('Dates: 2026-05-31 and 2026-06-01'));

  // Find all matches
  Matches := R.FindAll('Dates: 2026-05-31 and 2026-06-01');
  WriteLn('Found ', Length(Matches), ' dates');

  // Replace all occurrences
  WriteLn(R.ReplaceAll('Date: 2026-05-31', 'REDACTED'));

  // Split by pattern
  R := TRegex.Compile('[,;]\s*');
  Parts := R.Split('one, two; three, four');
  // Parts = ['one', 'two', 'three', 'four']
end.
```

## API Reference

### TRegex (record)

| Method | Description |
|--------|-------------|
| `Compile(APattern)` | Compile pattern, raises `ERegexCompileError` on failure |
| `Compile(APattern, AFlags)` | Compile with explicit flags |
| `TryCompile(APattern, ARegex, AError)` | Compile without raising; returns false on failure |
| `IsMatch(AInput)` | Returns true if pattern matches anywhere in input |
| `IsFullMatch(AInput)` | Returns true if pattern matches the entire input |
| `Find(AInput)` | Find first match, returns `TMatch` |
| `FindAt(AInput, AStartPos)` | Find first match starting at byte offset |
| `FindAll(AInput)` | Find all non-overlapping matches |
| `ReplaceFirst(AInput, AReplacement)` | Replace first match with literal string |
| `ReplaceAll(AInput, AReplacement)` | Replace all matches with literal string |
| `ReplaceFirstFunc(AInput, AFunc)` | Replace first match using callback |
| `ReplaceAllFunc(AInput, AFunc)` | Replace all matches using callback |
| `ReplaceAllExpand(AInput, ATemplate)` | Replace all with template expansion (`$1`, `${name}`) |
| `Split(AInput, AMaxSplits)` | Split input by pattern (default: unlimited splits) |
| `GroupByName(AMatch, AName)` | Get named capture group from a match |
| `GroupIndexByName(AName)` | Get capture group index by name |
| `NumCaptures` | Number of capture groups in the pattern |

### Convenience Functions

| Function | Description |
|----------|-------------|
| `RegexIsMatch(APattern, AInput)` | One-shot match test (compiles + matches) |
| `RegexFind(APattern, AInput)` | One-shot find |
| `RegexFindAll(APattern, AInput)` | One-shot find all |
| `RegexReplaceAll(APattern, AInput, AReplacement)` | One-shot replace all |
| `RegexSplit(APattern, AInput)` | One-shot split |
| `RegexQuoteMeta(AStr)` | Escape all regex metacharacters in a string |

### Types

```pascal
TRegexFlags = set of (rfCaseInsensitive, rfMultiLine, rfDotAll);

TMatch = record
  Start: SizeInt;   // 0-based byte offset (-1 if not found)
  Len: SizeInt;     // length in bytes
  Groups: TGroupArray;
  function Found: Boolean;
  function Value(const AInput: string): string;
end;

TGroup = record
  Start: SizeInt;   // 0-based byte offset (-1 if not captured)
  Len: SizeInt;
  function Found: Boolean;
  function Value(const AInput: string): string;
end;

TReplaceFunc = function(const AInput: string; const AMatch: TMatch): string;
```

## Supported Syntax

| Syntax | Description |
|--------|-------------|
| `.` | Any byte except `\n` (any byte if `rfDotAll`) |
| `\d` | Digit `[0-9]` |
| `\D` | Non-digit `[^0-9]` |
| `\w` | Word character `[a-zA-Z0-9_]` |
| `\W` | Non-word character |
| `\s` | Whitespace `[ \t\n\r\f\v]` |
| `\S` | Non-whitespace |
| `[abc]` | Character class |
| `[^abc]` | Negated character class |
| `[a-z]` | Character range |
| `\|` | Alternation |
| `(...)` | Capture group |
| `(?P<name>...)` | Named capture group |
| `(?:...)` | Non-capturing group |
| `(?i)` | Case-insensitive flag (inline) |
| `*` | Zero or more (greedy) |
| `+` | One or more (greedy) |
| `?` | Zero or one (greedy) |
| `{n}` | Exactly n |
| `{n,}` | At least n |
| `{n,m}` | Between n and m |
| `^` | Start of input (or line if `rfMultiLine`) |
| `$` | End of input (or line if `rfMultiLine`) |
| `\b` | Word boundary |
| `\B` | Non-word boundary |
| `\\` | Literal backslash |
| `\t \n \r \f \v` | Escape sequences |

## Match Semantics

- **POSIX leftmost-longest**: when multiple matches start at the same position, the longest is returned
- **Byte-oriented**: all positions (`Start`, `Len`) are byte offsets (0-based)
- **ASCII character classes**: `\w`, `\d`, `\s` operate on ASCII only
- **Dot**: `.` matches any byte except `\n` (unless `rfDotAll` is set)
- **Anchors**: `^` and `$` match start/end of input (or line boundaries with `rfMultiLine`)

## Unsupported Features

- Unicode properties (`\p{L}`, `\p{N}`)
- Non-greedy quantifiers (syntax `*?` `+?` is accepted but behaves as greedy)
- Lookahead / lookbehind assertions
- Backreferences (`\1`)
- Atomic groups / possessive quantifiers
- Conditional patterns

## Performance

Typical results on x86-64 (10KB input, compiled with `-O3`):

| Benchmark | nextpas | Go regexp | Speedup |
|-----------|---------|-----------|---------|
| Literal IsMatch | ~800 ns | ~5,000 ns | ~6x |
| Digit Find (`\d+`) | ~2,500 ns | ~12,000 ns | ~5x |
| Alternation (4 alts) | ~4,000 ns | ~25,000 ns | ~6x |
| Compile (date pattern) | ~1,200 ns | ~6,500 ns | ~5x |

The SIMD literal prefix optimization gives the largest speedup for patterns starting with a fixed string.

## Thread Safety

- A compiled `TRegex` is immutable and safe to share across threads
- Each match operation allocates its own state (no shared mutable data)
- Convenience functions (`RegexIsMatch`, etc.) compile on every call; cache `TRegex` for hot paths

## Error Handling

```pascal
var
  R: TRegex;
  Err: string;
begin
  // Option 1: raises ERegexCompileError
  try
    R := TRegex.Compile('[invalid');
  except
    on E: ERegexCompileError do
      WriteLn('Error at pos ', E.Position, ': ', E.Message);
  end;

  // Option 2: returns false
  if not TRegex.TryCompile('[invalid', R, Err) then
    WriteLn('Error: ', Err);
end.
```

## Template Expansion

`ReplaceAllExpand` supports these template variables:

| Template | Meaning |
|----------|---------|
| `$0` | Entire match |
| `$1` .. `$9` | Capture group by index |
| `${name}` | Capture group by name |
| `$$` | Literal `$` |

## Architecture

The engine is split into focused units:

- `nextpas.core.regex.charclass` — 256-bit character class bitmaps
- `nextpas.core.regex.parser` — recursive descent parser producing an AST
- `nextpas.core.regex.compiler` — AST to NFA bytecode compiler
- `nextpas.core.regex.nfa` — Thompson NFA executor with SIMD prefilter
- `nextpas.core.regex.base` — shared types (`TMatch`, `TGroup`, opcodes)
- `nextpas.core.regex` — public facade
