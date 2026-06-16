# nextpas.core.csv

RFC 4180 compliant CSV parser and writer. Zero SysUtils dependency. Go encoding/csv compatible API.

## Failure and lifetime contract

`ReadRow` and `ReadAll` report ordinary parse failures in-band through `HasError`, `GetError`, and structured `Error`.

`ReadAll` returns only the complete rows that finished before the failing record. It does not append the malformed or width-mismatched row that set the error state.

`TCsvError` exposes `Message`, `Line`, `Column`, and `Offset`.

`TCsvReader` keeps its input string alive internally, while returned field strings are owned copies.

## Quick Start

```pascal
uses nextpas.core.csv;

var
  Reader: TCsvReader;
  Fields: TStringArray;
begin
  Reader := TCsvReader.Create('name,age' + #10 + 'Alice,30' + #10 + 'Bob,25' + #10);
  while Reader.ReadRow(Fields) do
  begin
    WriteLn(Fields[0], ' is ', Fields[1], ' years old');
  end;
  if Reader.HasError then
    WriteLn('CSV error: ', Reader.GetError);
end;

// Read all at once
var Matrix: TStringMatrix;
Matrix := Reader.ReadAll;
```

## File Structure

```
src/nextpas.core.csv.pas — TCsvReader, TCsvWriter, TCsvError
```

## Feature Coverage

- RFC 4180 compliance
- Configurable delimiter (default: comma)
- Configurable quote character (default: double-quote)
- Trim whitespace option
- Comment line skip
- Fixed field count validation
- Multi-line field support (quoted fields with embedded newlines)
- Streaming read via `ReadRow`
- Bulk read via `ReadAll`

## Performance

- Zero SysUtils dependency
- Simple state-machine parser
- Minimal memory allocation