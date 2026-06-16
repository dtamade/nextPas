unit nextpas.core.mem.pool.base;

{$I nextpas.core.settings.inc}

interface

type
  {** 最小基座接口（可用于统一抽象，但不强制大小语义） *}
  IPool = interface
    ['{6B2E8E2D-0C3A-4E6C-9D7F-2B7E4B7A9A10}']
    function Acquire(out aPtr: Pointer): Boolean;
    function TryAcquire(out aPtr: Pointer): Boolean;
    function AcquireN(out aPtrs: array of Pointer; aCount: Integer): Integer;
    procedure Release(aPtr: Pointer);
    procedure ReleaseN(const aPtrs: array of Pointer; aCount: Integer);
    procedure Reset;
  end;

{ Method-of-object types for batch operation helpers. }
type
  TAcquireOneFunc = function: Pointer of object;
  TReleaseOneProc = procedure(APtr: Pointer) of object;

{**
 * @desc Default AcquireN loop: call AAcquire repeatedly, fill APtrs up to
 *       min(aCount, Length(aPtrs)), stop on nil. Returns acquired count.
 *}
function DefaultAcquireN(const AAcquire: TAcquireOneFunc;
  out APtrs: array of Pointer; ACount: Integer): Integer;

{**
 * @desc Default ReleaseN loop: call ARelease for each entry in APtrs,
 *       up to min(aCount, Length(aPtrs)).
 *}
procedure DefaultReleaseN(const ARelease: TReleaseOneProc;
  const APtrs: array of Pointer; ACount: Integer);

implementation

function DefaultAcquireN(const AAcquire: TAcquireOneFunc;
  out APtrs: array of Pointer; ACount: Integer): Integer;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  Result := 0;
  if ACount <= 0 then Exit;
  for LIdx := 0 to ACount - 1 do
  begin
    if LIdx > High(APtrs) then
      Break;
    LPtr := AAcquire();
    if LPtr = nil then
      Break;
    APtrs[LIdx] := LPtr;
    Inc(Result);
  end;
end;

procedure DefaultReleaseN(const ARelease: TReleaseOneProc;
  const APtrs: array of Pointer; ACount: Integer);
var
  LIdx: Integer;
begin
  if ACount <= 0 then Exit;
  for LIdx := 0 to ACount - 1 do
  begin
    if LIdx > High(APtrs) then
      Break;
    ARelease(APtrs[LIdx]);
  end;
end;

end.
