unit nextpas.core.mem.allocator.base;
{**
 * @desc Allocator 基类和类型定义。
 *
 * @note Canonical IAllocator 定义在 nextpas.core.mem.intf。
 *       本单元提供 TAllocator/TMemAllocator 基类便利层。
 *       门面 mem.pas 统一 re-export mem.intf 的 IAllocator。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.mem.base,
  nextpas.core.mem.utils,
  nextpas.core.mem.intf
  ;

const
  {** DEBUG 模式下追踪最近释放指针的环形缓冲区大小 }
  FREED_PTR_RING_SIZE = 256;

type
  TAllocatorTraits = nextpas.core.mem.intf.TAllocatorTraits;
  IAllocator = nextpas.core.mem.intf.IAllocator;
  TMemAllocator = nextpas.core.mem.intf.IAllocator;

  {**
   * TAllocator
   *
   * @desc 内存分配器的抽象基类, 实现了 IAllocator 接口。
   *
   * DEBUG 模式特性：
   * - 分配时填充 MEM_POISON_ALLOC（检测未初始化读取）
   * - 环形缓冲区追踪最近释放的指针（检测 double-free）
   *}
  TAllocator = class(TInterfacedObject, IAllocator)
  {$IFDEF DEBUG}
  private
    FFreedRing: array[0..FREED_PTR_RING_SIZE - 1] of Pointer;
    FFreedRingPos: Integer;
    function IsFreedPointer(APtr: Pointer): Boolean;
    procedure RecordFreedPointer(APtr: Pointer);
  {$ENDIF}
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoAllocMem(ASize: SizeUInt): Pointer; virtual; abstract;
    function DoReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; virtual; abstract;
    procedure DoFreeMem(APtr: Pointer); virtual; abstract;
  public
    function  GetMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  AllocMem(ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    procedure FreeMem(APtr: Pointer); {$IFDEF NEXTPAS_CORE_INLINE}inline;{$ENDIF}
    function  Traits: TAllocatorTraits; virtual;
  end;


implementation

uses
  nextpas.core.mem.error;

{$PUSH}
{$WARN 4055 OFF} // pointer/ordinal conversions in aligned alloc helpers

{$IFDEF DEBUG}
function TAllocator.IsFreedPointer(APtr: Pointer): Boolean;
var
  I: Integer;
begin
  for I := 0 to FREED_PTR_RING_SIZE - 1 do
    if FFreedRing[I] = APtr then
      Exit(True);
  Result := False;
end;

procedure TAllocator.RecordFreedPointer(APtr: Pointer);
begin
  FFreedRing[FFreedRingPos] := APtr;
  FFreedRingPos := (FFreedRingPos + 1) mod FREED_PTR_RING_SIZE;
end;
{$ENDIF}

function TAllocator.Traits: TAllocatorTraits;
begin
  // 基类缺省值：
  // - ThreadSafe=False: 大多数中间件分配器无线程安全，需显式开启
  // - ZeroInitialized=False: GetMem 不保证零填充
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := False;
  Result.SupportsRealloc := True;
end;

function TAllocator.GetMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoGetMem(ASize);
  {$IFDEF DEBUG}
  if Result <> nil then
    FillChar(Result^, ASize, MEM_POISON_ALLOC);
  {$ENDIF}
end;

function TAllocator.AllocMem(ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := DoAllocMem(ASize);
end;

function TAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer;
begin
  if ASize = 0 then
  begin
    if APtr <> nil then
      DoFreeMem(APtr);
    Exit(nil);
  end;
  if APtr = nil then
    Exit(GetMem(ASize));
  Result := DoReallocMem(APtr, ASize);
end;

procedure TAllocator.FreeMem(APtr: Pointer);
begin
  if APtr = nil then
  begin
    {$IFDEF NEXTPAS_CORE_STRICT_NULL_FREE}
    Assert(False, 'TAllocator.FreeMem: APtr must not be nil');
    {$ELSE}
    Exit;
    {$ENDIF}
  end;
  {$IFDEF DEBUG}
  if IsFreedPointer(APtr) then
    raise EAllocError.Create(aeDoubleFree,
      'TAllocator.FreeMem: double free detected at $' + HexStr(APtr));
  {$ENDIF}
  DoFreeMem(APtr);
  {$IFDEF DEBUG}
  RecordFreedPointer(APtr);
  {$ENDIF}
end;

{$POP}

end.
