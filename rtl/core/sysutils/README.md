# nextPas SysUtils Implementation

**Purpose:** Minimal SysUtils implementation for compiler modules to enable Stage2 self-hosting.

**Scope:** Only implements functions actually used by nextPas compiler modules, not full FPC RTL compatibility.

## Design Principles

1. **Correctness over performance**: Focus on correct behavior first
2. **Minimal but complete**: Implement only what's needed, but implement it fully
3. **FPC-compatible**: Use compatible types and calling conventions
4. **Well-tested**: Every function has unit tests

## Implemented Functions

### String Operations

- `Trim(s: string): string` - Remove leading/trailing whitespace
- `Copy(s: string; index, count: Integer): string` - Substring (built-in, documented)
- `Pos(substr, s: string): Integer` - Find substring position (built-in, documented)
- `LowerCase(s: string): string` - Convert to lowercase
- `UpperCase(s: string): string` - Convert to uppercase
- `Delete(var s: string; index, count: Integer)` - Remove substring
- `Insert(source: string; var s: string; index: Integer)` - Insert substring

### File Operations

- `FileExists(filename: string): Boolean` - Check if file exists
- `DirectoryExists(dirname: string): Boolean` - Check if directory exists
- `ExpandFileName(filename: string): string` - Convert to absolute path
- `ExtractFileDir(filename: string): string` - Get directory part
- `ExtractFileName(filename: string): string` - Get filename part
- `IncludeTrailingPathDelimiter(path: string): string` - Ensure trailing /
- `ExcludeTrailingPathDelimiter(path: string): string` - Remove trailing /

### Exception Support

- `Exception` class - Base exception class with Message property

### Type Conversions

- `IntToStr(value: Integer): string` - Integer to string
- `StrToInt(s: string): Integer` - String to integer (raises exception on error)
- `StrToIntDef(s: string; default: Integer): Integer` - String to integer with default

## Usage

```pascal
uses SysUtils;

var
  s: string;
begin
  s := Trim('  hello  ');  // 'hello'
  if FileExists('test.pas') then
    WriteLn('File exists');
end.
```

## Testing

See `np_sysutils_test.pas` for unit tests.

## Future Work

- Add more functions as needed by compiler modules
- Performance optimization if needed
- Extended error handling
