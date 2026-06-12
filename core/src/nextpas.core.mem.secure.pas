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
 * in memory after use. Uses explicit zeroing followed by a barrier.
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

procedure SecureZeroBarrier; inline;
begin
  {$IFDEF CPUX86_64}
  asm
    mfence
  end;
  {$ENDIF}
  {$IFDEF CPUI386}
  asm
    lock
    addl $0, (%esp)
  end;
  {$ENDIF}
  {$IFDEF CPUARM}
  asm
    dmb
  end;
  {$ENDIF}
  {$IFDEF CPUAARCH64}
  asm
    dmb sy
  end;
  {$ENDIF}
  {$IFNDEF CPUX86_64}
  {$IFNDEF CPUI386}
  {$IFNDEF CPUARM}
  {$IFNDEF CPUAARCH64}
  ReadWriteBarrier;
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
  {$ENDIF}
end;

procedure SecureZeroMemory(Buffer: Pointer; Size: NativeUInt);
begin
  if (Buffer = nil) or (Size = 0) then
    Exit;

  FillChar(Buffer^, Size, 0);
  SecureZeroBarrier;
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
