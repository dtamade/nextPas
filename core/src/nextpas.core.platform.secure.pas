unit nextpas.core.platform.secure;

{$I nextpas.core.settings.inc}

interface

{**
 * platform_secure_zero
 *
 * Zero memory in a way the compiler cannot optimize away.
 * Uses FillChar followed by a CPU/compiler barrier.
 *
 * @param Buffer  Pointer to the buffer to zero
 * @param Size    Size of the buffer in bytes
 *}
procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);

implementation

procedure platform_secure_zero(Buffer: Pointer; Size: NativeUInt);
begin
  if (Buffer = nil) or (Size = 0) then
    Exit;

  FillChar(Buffer^, Size, 0);

  { CPU / compiler barrier to prevent the zeroing from being optimized away }
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

end.
