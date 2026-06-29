unit nextpas.core.mem.allocator.rtl;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.mem.allocator.base;

type
  {**
   * TRtlAllocator
   * @desc 使用标准 Pascal RTL 内存管理器实现的分配器。
   *       FreeMem/ASize 参数被忽略（RTL 通过 header 知道大小）。
   *}
  TRtlAllocator = class(TAllocator)
  protected
    function  DoGetMem(ASize: SizeUInt): Pointer; override;
    function  DoAllocMem(ASize: SizeUInt): Pointer; override;
    function  DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
  public
    { Phase 1: 新签名 override。ASize/AOldSize 被忽略。 }
    procedure FreeMem(APtr: Pointer; ASize: SizeUInt); override;
    function ReallocMem(APtr: Pointer; AOldSize, ANewSize: SizeUInt): Pointer; override;
    function  Traits: TAllocatorTraits; override;
  end;

function GetRtlAllocator: TAllocator;
function TryGetRtlAllocator(out A: TAllocator): Boolean;

implementation

var
  _RTLAllocatorObj: TRtlAllocator;
  _RTLAllocatorIntf: IAllocator;
  GRtlAllocLock: TRTLCriticalSection;

function TRtlAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := System.GetMem(ASize);
end;

function TRtlAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := System.AllocMem(ASize);
end;

function TRtlAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := System.ReallocMem(ADst, ASize);
end;

procedure TRtlAllocator.DoFreeMem(ADst: Pointer);
begin
  System.FreeMem(ADst);
end;

procedure TRtlAllocator.FreeMem(APtr: Pointer; ASize: SizeUInt);
begin
  { RTL knows block size via its own header — ASize ignored. }
  System.FreeMem(APtr);
end;

function TRtlAllocator.ReallocMem(APtr: Pointer;
  AOldSize, ANewSize: SizeUInt): Pointer;
begin
  { RTL handles old size internally — AOldSize ignored. }
  if APtr = nil then
    Exit(System.GetMem(ANewSize));
  if ANewSize = 0 then
  begin
    System.FreeMem(APtr);
    Exit(nil);
  end;
  Result := System.ReallocMem(APtr, ANewSize);
end;

function TRtlAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ZeroInitialized := True;
  Result.SupportsAligned := False;
  Result.HasMemSize      := False;
end;

function GetRtlAllocator: TAllocator;
begin
  if _RTLAllocatorObj = nil then
  begin
    EnterCriticalSection(GRtlAllocLock);
    try
      if _RTLAllocatorObj = nil then
      begin
        _RTLAllocatorObj := TRtlAllocator.Create;
        _RTLAllocatorIntf := _RTLAllocatorObj as IAllocator;
      end;
    finally
      LeaveCriticalSection(GRtlAllocLock);
    end;
  end;
  Result := _RTLAllocatorObj;
end;

function TryGetRtlAllocator(out A: TAllocator): Boolean;
begin
  try
    A := GetRtlAllocator;
    Result := True;
  except
    A := nil;
    Result := False;
  end;
end;

initialization
  InitCriticalSection(GRtlAllocLock);
finalization
  DoneCriticalSection(GRtlAllocLock);
  _RTLAllocatorIntf := nil;
  _RTLAllocatorObj := nil;

end.
