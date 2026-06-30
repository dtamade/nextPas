unit nextpas.core.mem.allocator.rtl;

{$I nextpas.core.settings.inc}

interface

uses
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
    function  Traits: TAllocatorTraits; override;
  end;

function GetRtlAllocator: TAllocator;
function TryGetRtlAllocator(out A: TAllocator): Boolean;
{** ResolveAllocator: 返回 AAllocator（非 nil），否则返回 GetRtlAllocator。
    消除构造函数中重复的 nil→default 分支。 }
function ResolveAllocator(AAllocator: TAllocator): TAllocator; inline;

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

function TRtlAllocator.Traits: TAllocatorTraits;
begin
  Result := inherited Traits;
  Result.ZeroInitialized := True;
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

function ResolveAllocator(AAllocator: TAllocator): TAllocator;
begin
  if AAllocator <> nil then
    Result := AAllocator
  else
    Result := GetRtlAllocator;
end;

initialization
  InitCriticalSection(GRtlAllocLock);
finalization
  DoneCriticalSection(GRtlAllocLock);
  _RTLAllocatorIntf := nil;
  _RTLAllocatorObj := nil;

end.
