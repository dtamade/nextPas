unit nextpas.core.mem.allocator.tracking;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf,
  nextpas.core.mem.allocator.base;

type
  {** TAllocRecord — 单次分配的跟踪信息 }
  TAllocRecord = record
    Ptr: Pointer;
    Size: SizeUInt;
    AllocId: QWord;
  end;

  TAllocRecordArray = array of TAllocRecord;

  {** TTrackingAllocator
   *
   *  包装任意 IAllocator，记录所有分配/释放操作，
   *  用于测试时检测内存泄漏。
   *
   *  线程安全（内部用 TRTLCriticalSection 保护记录表）。
   *  仅用于测试/诊断场景，不建议在生产热路径使用。
   *}
  TTrackingAllocator = class(TAllocator)
  private
    FInner: IAllocator;
    FRecords: TAllocRecordArray;
    FCount: SizeInt;
    FCapacity: SizeInt;
    FNextAllocId: QWord;
    FLock: TRTLCriticalSection;
    function FindRecordIndex(aPtr: Pointer): SizeInt;
    procedure AddRecord(aPtr: Pointer; aSize: SizeUInt);
    procedure RemoveRecord(aPtr: Pointer);
    procedure UpdateRecord(aOldPtr, aNewPtr: Pointer; aNewSize: SizeUInt);
  protected
    function DoGetMem(aSize: SizeUInt): Pointer; override;
    function DoAllocMem(aSize: SizeUInt): Pointer; override;
    function DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer; override;
    procedure DoFreeMem(aDst: Pointer); override;
  public
    constructor Create(aInner: IAllocator);
    destructor Destroy; override;

    {** 当前活跃分配数 }
    function ActiveAllocCount: SizeInt;
    {** 当前活跃分配字节 }
    function ActiveAllocBytes: SizeUInt;
    {** 是否有泄漏 }
    function HasLeaks: Boolean;
    {** 生成泄漏报告（包含每个未释放块的地址和大小） }
    function ReportLeaks: string;
    {** 内部分配器 }
    property Inner: IAllocator read FInner;

    function Traits: TAllocatorTraits; override;
  end;

implementation

uses
  SysUtils;

{ TTrackingAllocator }

constructor TTrackingAllocator.Create(aInner: IAllocator);
begin
  inherited Create;
  if aInner = nil then
    raise EArgumentNil.Create('TTrackingAllocator.Create: aInner cannot be nil');
  FInner := aInner;
  FRecords := nil;
  FCount := 0;
  FCapacity := 0;
  FNextAllocId := 1;
  InitCriticalSection(FLock);
end;

destructor TTrackingAllocator.Destroy;
begin
  DoneCriticalSection(FLock);
  FInner := nil;
  inherited;
end;

function TTrackingAllocator.FindRecordIndex(aPtr: Pointer): SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to FCount - 1 do
    if FRecords[I].Ptr = aPtr then
      Exit(I);
  Result := -1;
end;

procedure TTrackingAllocator.AddRecord(aPtr: Pointer; aSize: SizeUInt);
var
  LNewCapacity: SizeInt;
begin
  if aPtr = nil then
    Exit;
  if FCount >= FCapacity then
  begin
    if FCapacity = 0 then
      LNewCapacity := 16
    else
      LNewCapacity := FCapacity * 2;
    SetLength(FRecords, LNewCapacity);
    FCapacity := LNewCapacity;
  end;
  FRecords[FCount].Ptr := aPtr;
  FRecords[FCount].Size := aSize;
  FRecords[FCount].AllocId := FNextAllocId;
  Inc(FNextAllocId);
  Inc(FCount);
end;

procedure TTrackingAllocator.RemoveRecord(aPtr: Pointer);
var
  LIdx: SizeInt;
begin
  if aPtr = nil then
    Exit;
  LIdx := FindRecordIndex(aPtr);
  if LIdx >= 0 then
  begin
    { 用最后一个元素覆盖被删除的元素 }
    Dec(FCount);
    if LIdx < FCount then
      FRecords[LIdx] := FRecords[FCount];
  end;
end;

procedure TTrackingAllocator.UpdateRecord(aOldPtr, aNewPtr: Pointer; aNewSize: SizeUInt);
var
  LIdx: SizeInt;
begin
  LIdx := FindRecordIndex(aOldPtr);
  if LIdx >= 0 then
  begin
    FRecords[LIdx].Ptr := aNewPtr;
    FRecords[LIdx].Size := aNewSize;
  end
  else
  begin
    { 旧指针未跟踪，可能是直接用 FInner 分配的，直接添加新记录 }
    AddRecord(aNewPtr, aNewSize);
  end;
end;

function TTrackingAllocator.DoGetMem(aSize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(aSize);
  EnterCriticalSection(FLock);
  try
    AddRecord(Result, aSize);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.DoAllocMem(aSize: SizeUInt): Pointer;
begin
  Result := FInner.AllocMem(aSize);
  EnterCriticalSection(FLock);
  try
    AddRecord(Result, aSize);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.DoReallocMem(aDst: Pointer; aSize: SizeUInt): Pointer;
begin
  Result := FInner.ReallocMem(aDst, aSize);
  EnterCriticalSection(FLock);
  try
    if Result <> nil then
    begin
      if aDst <> nil then
        UpdateRecord(aDst, Result, aSize)
      else
        AddRecord(Result, aSize);
    end
    else if aDst <> nil then
    begin
      { ReallocMem 失败：原指针仍有效 }
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTrackingAllocator.DoFreeMem(aDst: Pointer);
begin
  FInner.FreeMem(aDst);
  EnterCriticalSection(FLock);
  try
    RemoveRecord(aDst);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.ActiveAllocCount: SizeInt;
begin
  EnterCriticalSection(FLock);
  try
    Result := FCount;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.ActiveAllocBytes: SizeUInt;
var
  I: SizeInt;
begin
  EnterCriticalSection(FLock);
  try
    Result := 0;
    for I := 0 to FCount - 1 do
      Inc(Result, FRecords[I].Size);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.HasLeaks: Boolean;
begin
  Result := ActiveAllocCount > 0;
end;

function TTrackingAllocator.ReportLeaks: string;
var
  I: SizeInt;
  LSb: TStringBuilder;
begin
  EnterCriticalSection(FLock);
  try
    if FCount = 0 then
      Exit('No leaks detected.');
    LSb := TStringBuilder.Create;
    try
      LSb.AppendLine('Leak report: ' + IntToStr(FCount) + ' block(s) not freed:');
      for I := 0 to FCount - 1 do
      begin
        LSb.Append('  [' + IntToStr(FRecords[I].AllocId) + '] ');
        LSb.Append('$' + IntToHex(PtrUInt(FRecords[I].Ptr), SizeOf(Pointer) * 2));
        LSb.Append(' size=' + IntToStr(FRecords[I].Size));
        LSb.AppendLine;
      end;
      Result := LSb.ToString;
    finally
      LSb.Free;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := True;
  Result.HasMemSize      := True;
  Result.SupportsAligned := False;
end;

end.
