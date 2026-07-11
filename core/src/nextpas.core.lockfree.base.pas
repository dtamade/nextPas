unit nextpas.core.lockfree.base;

{$I nextpas.core.settings.inc}

interface

const
  LOCKFREE_SPIN_COUNT = 32;
  LOCKFREE_YIELD_COUNT = 32;

type
  TCacheLinePad = array[0..3] of Int64;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
function LockFreeIsPow2(const AValue: PtrUInt): Boolean;

{** @desc 预取内存地址到缓存（x86_64 专用）
  @param AAddr 要预取的内存地址
  @note 使用 prefetchnta 指令，减少对缓存的污染 }
procedure LockFreePrefetch(const AAddr: Pointer); inline;

implementation

uses
  nextpas.core.errors;

function LockFreeMaxPowerOfTwo: PtrUInt; inline;
var
  LMax: PtrUInt;
begin
  LMax := not PtrUInt(0);
  Result := LMax - (LMax shr 1);
end;

function LockFreeIsPow2(const AValue: PtrUInt): Boolean;
begin
  Result := (AValue > 0) and ((AValue and (AValue - 1)) = 0);
end;

function LockFreeNextPow2(const AValue: PtrUInt): PtrUInt;
begin
  if AValue = 0 then
    Exit(0);
  if LockFreeIsPow2(AValue) then
    Exit(AValue);
  if AValue > LockFreeMaxPowerOfTwo then
    raise EArgumentError.CreateFmt('LockFreeNextPow2: capacity %d exceeds maximum power-of-two', [AValue]);
  Result := 1;
  while Result < AValue do
    Result := Result shl 1;
end;

procedure LockFreePrefetch(const AAddr: Pointer); inline;
begin
  {$IFDEF CPUX86_64}
  {$ASMMODE intel}
  asm
    prefetchnta [AAddr]
  end;
  {$ENDIF}
end;

end.
