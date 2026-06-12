unit nextpas.core.mem.secure;

{$mode ObjFPC}{$H+}

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
 * in memory after use. Uses platform-specific secure zeroing if available.
 * 
 * This function ensures the compiler cannot optimize away the zeroing operation.
 * 
 * @param Buffer Pointer to the buffer to zero
 * @param Size Size of the buffer in bytes
 *}
procedure SecureZeroMemory(Buffer: Pointer; Size: NativeUInt);

{**
 * Securely zero a byte array
 * 
 * @param Data The byte array to zero
 *}
procedure SecureZeroBytes(var Data: TBytes);

{**
 * Securely zero a string
 * 
 * @param Str The string to zero
 *}
procedure SecureZeroString(var Str: AnsiString);

implementation

uses
  nextpas.core.platform.memory;

procedure SecureZeroMemory(Buffer: Pointer; Size: NativeUInt);
begin
  platform_secure_zero(Buffer, Size);
end;

procedure SecureZeroBytes(var Data: TBytes);
begin
  if Length(Data) > 0 then
  begin
    SecureZeroMemory(@Data[0], Length(Data));
    SetLength(Data, 0);
  end;
end;

procedure SecureZeroString(var Str: AnsiString);
var
  Len: Integer;
begin
  Len := Length(Str);
  if Len > 0 then
  begin
    // 确保字符串可写（处理常量字符串引用）
    UniqueString(Str);
    // 再次检查长度（UniqueString 可能改变引用）
    if Length(Str) > 0 then
      SecureZeroMemory(@Str[1], Len);
    Str := '';
  end;
end;

end.
