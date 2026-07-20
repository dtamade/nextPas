# nextpas.core.ini

INI configuration file parser. Zero SysUtils dependency, Go ini compatible API.

Supports sections, key=value pairs, comments (`;` and `#`), empty line skipping, and preserving whitespace in values.

## Failure and ownership contract

`LoadFromString` stays permissive, while `LoadFromFile` raises `ENextPasError` on file I/O failures.

`TryLoadFromString` and `TryLoadFromFile` return `False` and populate `Error`.
Both string and structured `TIniError` overloads are available.

`LoadFromString` and the try-load validators recognize LF, CRLF, and lone CR as physical line endings; source diagnostics report byte offsets against the original input.

Duplicate parsed sections merge into the existing section, and duplicate parsed keys update the existing key slot with the last parsed value. Try-load accepts those duplicates.

`TIniError` exposes `Message`, `Line`, `Column`, and `Offset`; non-source file I/O failures use `Line = 0` and `Column = 0`.
`Column` and `Col` are aliases on `TIniError`.

When `TIniFile.Strict = True`, try-load rejects non-comment lines that are neither section headers nor `key=value` pairs. Default is permissive (`Strict = False`), matching historical Go-style ignore-of-bare lines.

`IniParse(IReader)` bulk-loads via `IoReadAll` and is subject to `FORMAT_BULK_PARSE_MAX_BYTES` (see `nextpas.core.format.limits`).

Callers own `TIniFile` instances and must free them.

## Quick Start

Runnable smoke: `core/examples/nextpas.core.ini/ini_smoke/` (`make run`).

```pascal
uses nextpas.core.ini;

var
  Ini: TIniFile;
  Err: TIniError;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[server]' + #10 + 'host=localhost' + #10 + 'port=8080');
    WriteLn(Ini.ReadString('server', 'host', ''));
    WriteLn(Ini.ReadInteger('server', 'port', 0));

    Ini.Strict := True;
    if not Ini.TryLoadFromString('[broken' + #10, Err) then
      WriteLn('Parse error at ', Err.Line, ':', Err.Column, ' ', Err.Message);
  finally
    Ini.Free;
  end;

// Save
Ini.SaveToFile('config.ini');
```

## File Structure

```
src/nextpas.core.ini.pas — TIniFile, TIniError, TIniSection, TIniEntry
```

## Feature Coverage

- Sections `[section]`
- Key=value pairs
- Comments (`;` and `#`)
- Empty line skipping
- Whitespace preservation in values
- Section/key existence checks
- Read/write string, integer, bool
- Delete key/section
- LF, CRLF, CR line ending support
- Try-load with string and structured `TIniError`
- Optional `Strict` mode for bare-line rejection
- `Col` / `Column` diagnostic aliases

## Performance

- Zero SysUtils dependency
- Simple line-by-line parser
- Minimal memory allocation
