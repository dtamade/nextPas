# RTL Implementation Plan for Stage2

> **Goal:** Implement minimal RTL units needed for compiler modules to enable Stage2 self-hosting.

**Target:** Make `nextpas build compiler/diagnostics/np_diagnostics_sink.pas` succeed.

**Approach:** Implement only what compiler modules actually use, not full FPC RTL compatibility.

---

## Phase 1: SysUtils Core (Week 1)

### Priority 1: String Operations

**Functions needed by compiler modules:**
- `Trim(s: string): string` - Remove leading/trailing whitespace
- `Copy(s: string; index, count: Integer): string` - Substring
- `Pos(substr, s: string): Integer` - Find substring position
- `LowerCase(s: string): string` - Convert to lowercase
- `UpperCase(s: string): string` - Convert to uppercase
- `Length(s: string): Integer` - String length (built-in, but document)
- `Delete(var s: string; index, count: Integer)` - Remove substring
- `Insert(source: string; var s: string; index: Integer)` - Insert substring

**Implementation strategy:**
- Use FPC's built-in string type (AnsiString with {$H+})
- Leverage existing string primitives where possible
- Keep implementations simple and correct

### Priority 2: File Operations

**Functions needed:**
- `FileExists(filename: string): Boolean`
- `DirectoryExists(dirname: string): Boolean`
- `ExpandFileName(filename: string): string` - Convert to absolute path
- `ExtractFileDir(filename: string): string` - Get directory part
- `ExtractFileName(filename: string): string` - Get filename part
- `IncludeTrailingPathDelimiter(path: string): string`
- `ExcludeTrailingPathDelimiter(path: string): string`

**Implementation strategy:**
- Use FPC RTL's internal functions where available
- Implement path manipulation with string operations
- Use system calls for file existence checks

### Priority 3: Exception Support

**Types needed:**
- `Exception = class` - Base exception class
  - `constructor Create(const Msg: string)`
  - `property Message: string`

**Implementation strategy:**
- Minimal exception class
- Rely on FPC's exception handling mechanism

### Priority 4: Type Conversions

**Functions needed:**
- `IntToStr(value: Integer): string`
- `StrToInt(s: string): Integer`
- `StrToIntDef(s: string; default: Integer): Integer`

**Implementation strategy:**
- Use FPC's built-in conversion functions or implement simple versions

---

## Phase 2: Classes Subset (Week 2, if needed)

**Analysis first:** Check if compiler modules can use dynamic arrays instead of TStringList.

**If TStringList is needed:**
- `TStringList = class`
  - `Add(s: string): Integer`
  - `Count: Integer`
  - `Strings[Index: Integer]: string` (default property)
  - `Clear`
  - `LoadFromFile(filename: string)`

**Alternative:** Refactor compiler modules to use `array of string` instead.

---

## Phase 3: Integration & Testing (Week 2-3)

### Step 1: Create SysUtils unit

```
rtl/core/sysutils/
  np_sysutils.pas          - Main SysUtils implementation
  np_sysutils_test.pas     - Unit tests
  README.md                - Documentation
```

### Step 2: Install to runtime SDK

```bash
# Copy to units/linux-x86_64/
cp rtl/core/sysutils/np_sysutils.pas units/linux-x86_64/SysUtils.pas
```

### Step 3: Progressive verification

1. Try compiling `np_diagnostics_sink.pas`
2. Fix any missing functions
3. Try compiling `np_base_types.pas`
4. Expand to more modules
5. Iterate until all compiler modules compile

### Step 4: Add verification gates

Add to `build/verify_local.sh`:
```bash
printf 'rtl-sysutils-check=running\n'
# Compile SysUtils unit tests
# Verify basic functionality
printf 'rtl-sysutils-check=pass\n'

printf 'compiler-module-self-compile-check=running\n'
# Try compiling np_diagnostics_sink.pas with nextPas
printf 'compiler-module-self-compile-check=pass\n'
```

---

## Implementation Order

### Task 1: Create SysUtils skeleton

**Files:**
- `rtl/core/sysutils/np_sysutils.pas`
- `rtl/core/sysutils/README.md`

**Content:**
```pascal
unit SysUtils;

{$mode objfpc}{$H+}

interface

// String operations
function Trim(const S: string): string;
function Copy(const S: string; Index, Count: Integer): string;
function Pos(const Substr, S: string): Integer;
function LowerCase(const S: string): string;
function UpperCase(const S: string): string;

// File operations
function FileExists(const FileName: string): Boolean;
function DirectoryExists(const Directory: string): Boolean;
function ExpandFileName(const FileName: string): string;
function ExtractFileDir(const FileName: string): string;
function ExtractFileName(const FileName: string): string;
function IncludeTrailingPathDelimiter(const Path: string): string;
function ExcludeTrailingPathDelimiter(const Path: string): string;

// Exception support
type
  Exception = class
  private
    FMessage: string;
  public
    constructor Create(const Msg: string);
    property Message: string read FMessage;
  end;

// Type conversions
function IntToStr(Value: Integer): string;
function StrToInt(const S: string): Integer;
function StrToIntDef(const S: string; Default: Integer): Integer;

implementation

// Implementations here...

end.
```

### Task 2: Implement string operations

Focus on correctness, not performance.

### Task 3: Implement file operations

Use FPC's internal functions where possible.

### Task 4: Implement exception support

Minimal but functional.

### Task 5: Implement type conversions

Simple implementations.

### Task 6: Add unit tests

Test each function independently.

### Task 7: Install to runtime SDK

Copy to `units/linux-x86_64/SysUtils.pas`.

### Task 8: Verify with compiler module

Try compiling `np_diagnostics_sink.pas`.

### Task 9: Iterate

Fix any issues, add missing functions.

### Task 10: Add verification gates

Ensure future changes don't break RTL.

---

## Success Criteria

**Phase 1 complete when:**
- ✅ `nextpas build compiler/diagnostics/np_diagnostics_sink.pas` succeeds
- ✅ All SysUtils unit tests pass
- ✅ RTL verification gate passes

**Phase 2 complete when:**
- ✅ At least 3 compiler modules compile successfully
- ✅ No missing function errors

**Phase 3 complete when:**
- ✅ All compiler modules compile successfully
- ✅ Generated code is correct (verified by tests)
- ✅ Ready for Stage2 bootstrap cycle

---

## Risk Mitigation

**Risk:** SysUtils implementation has bugs
- **Mitigation:** Comprehensive unit tests, compare behavior with FPC

**Risk:** Missing functions discovered late
- **Mitigation:** Progressive verification, add functions as needed

**Risk:** Performance issues
- **Mitigation:** Focus on correctness first, optimize later if needed

**Risk:** ABI compatibility issues
- **Mitigation:** Use FPC-compatible types and calling conventions

---

## Timeline

- **Week 1**: Tasks 1-5 (SysUtils core implementation)
- **Week 2**: Tasks 6-9 (Testing and verification)
- **Week 3**: Task 10 + expand to more modules
- **Week 4+**: Full compiler module compilation

**Total**: ~3-4 weeks to Phase 3 completion.
