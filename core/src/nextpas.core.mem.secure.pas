unit nextpas.core.mem.secure;

{$I nextpas.core.settings.inc}

{
  Memory utilities for secure data handling

  Purpose: Provide secure memory operations, particularly for
           clearing sensitive data (keys, passwords, etc.)
}

interface

uses
  nextpas.core.base;

{**
 * Securely zero memory to prevent sensitive data from remaining
 * in memory after use through the platform-owned secure-zero seam.
 *
 * This keeps backend selection inside nextpas.core.platform.memory.
 *
 * @param ABuffer Pointer to the buffer to zero
 * @param ASize Size of the buffer in bytes
 *}
procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt);

{**
 * Securely zero a byte array
 *
 * @param AData The byte array to zero
 *}
procedure SecureZeroBytes(var AData: TBytes);

{**
 * Securely zero a string
 *
 * @param AStr The string to zero
 *}
procedure SecureZeroString(var AStr: AnsiString);

implementation

uses
  nextpas.core.platform.memory;

procedure SecureZeroMemory(ABuffer: Pointer; ASize: NativeUInt);
begin
  platform_secure_zero_memory(ABuffer, ASize);
end;

procedure SecureZeroBytes(var AData: TBytes);
begin
  if Length(AData) > 0 then
  begin
    SecureZeroMemory(@AData[0], Length(AData));
    SetLength(AData, 0);
  end;
end;

procedure SecureZeroString(var AStr: AnsiString);
var
  LLen: Integer;
begin
  LLen := Length(AStr);
  if LLen > 0 then
  begin
    UniqueString(AStr);
    if Length(AStr) > 0 then
      SecureZeroMemory(@AStr[1], LLen);
    AStr := '';
  end;
end;

end.
