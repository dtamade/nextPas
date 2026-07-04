unit nextpas.core.mem.pool.base;

{$I nextpas.core.settings.inc}

interface

type
  {** 最小基座接口（可用于统一抽象，但不强制大小语义）
   *
   * 接口选择决策树:
   *   - 需要固定大小块池 + 容量/可用量查询？→ IBlockPool (blockpool.pas)
   *   - 需要可变大小分配 + 固定大小 Acquire 兼容？→ IMemoryPool (pool.memory_pool.pas)
   *   - 只需通用 Acquire/Release 抽象？→ IPool (本单元)
   *
   * IPool vs IBlockPool 签名差异说明:
   *   - IPool.Acquire(out APtr: Pointer): Boolean — Boolean + out param 模式，
   *     适用于需要区分"池耗尽"和"分配失败"的场景
   *   - IBlockPool.Acquire: Pointer — 直接返回指针，nil = 池耗尽，
   *     适用于热路径（减少分支，inline 友好）
   *   - 两者是不同层次的接口，不建议强行统一签名
   *}
  IPool = interface
    ['{6B2E8E2D-0C3A-4E6C-9D7F-2B7E4B7A9A10}']
    function Acquire(out APtr: Pointer): Boolean;
    function TryAcquire(out APtr: Pointer): Boolean;
    function AcquireN(out APtrs: array of Pointer; ACount: Integer): Integer;
    procedure Release(APtr: Pointer);
    procedure ReleaseN(const APtrs: array of Pointer; ACount: Integer);
    procedure Reset;
  end;

{ Method-of-object types for batch operation helpers. }
type
  TAcquireOneFunc = function: Pointer of object;
  TReleaseOneProc = procedure(APtr: Pointer) of object;

{**
 * @desc Default AcquireN loop: call AAcquire repeatedly, fill APtrs up to
 *       min(ACount, Length(APtrs)), stop on nil. Returns acquired count.
 *}
function DefaultAcquireN(const AAcquire: TAcquireOneFunc;
  out APtrs: array of Pointer; ACount: Integer): Integer;

{**
 * @desc Default ReleaseN loop: call ARelease for each entry in APtrs,
 *       up to min(ACount, Length(APtrs)).
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
