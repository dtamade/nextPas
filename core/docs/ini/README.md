# nextpas.core.ini

INI configuration file parser. Zero SysUtils dependency, Go ini compatible API.

Supports sections, key=value pairs, comments (`;` and `#`), empty line skipping, and preserving whitespace in values.

## Failure and ownership contract

`LoadFromString` stays permissive, while `LoadFromFile` raises `ENextPasError` on file I/O failures.

`TryLoadFromString` and `TryLoadFromFile` return `False` and populate `Error`.

`LoadFromString` and the try-load validators recognize LF, CRLF, and lone CR as physical line endings; source diagnostics report byte offsets against the original input.

Duplicate parsed sections merge into the existing section, and duplicate parsed keys update the existing key slot with the last parsed value. Try-load accepts those duplicates.

`TIniError` exposes `Message`, `Line`, `Column`, and `Offset`; non-source file I/O failures use `Line = 0` and `Column = 0`.

Callers own `TIniFile` instances and must free them.

## Quick Start

```pascal
uses nextpas.core.ini;

var
  Ini: TIniFile;
begin
  Ini := TIniFile.Create;
  try
    Ini.LoadFromString('[server]' + #10 + 'host=localhost' + #10 + 'port=8080');
    WriteLn(Ini.ReadString('server', 'host', ''));
    WriteLn(Ini.ReadInteger('server', 'port', 0));
  finally
    Ini.Free;
  end;

// Try-load pattern
var
  Error: string;
begin
  if not Ini.TryLoadFromString('[broken' + #10, Error) then
    WriteLn('Parse error: ', Error);
end;

// Save
Ini.SaveToFile('config.ini');
```

## File Structure

```
src/nextpas.core.ini.pas — TIniFile, TIniSection, TIniEntry
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
- Try-load with error reporting

## Performance

- Zero SysUtils dependency
- Simple line-by-line parser
- Minimal memory allocation