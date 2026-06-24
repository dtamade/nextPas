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
    function FindRecordIndex(APtr: Pointer): SizeInt;
    procedure AddRecord(APtr: Pointer; ASize: SizeUInt);
    procedure RemoveRecord(APtr: Pointer);
    procedure UpdateRecord(aOldPtr, aNewPtr: Pointer; aNewSize: SizeUInt);
  protected
    function DoGetMem(ASize: SizeUInt): Pointer; override;
    function DoAllocMem(ASize: SizeUInt): Pointer; override;
    function DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer; override;
    procedure DoFreeMem(ADst: Pointer); override;
    function DoMemSize(APtr: Pointer): SizeUInt; override;
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

function TTrackingAllocator.FindRecordIndex(APtr: Pointer): SizeInt;
var
  I: SizeInt;
begin
  for I := 0 to FCount - 1 do
    if FRecords[I].Ptr = APtr then
      Exit(I);
  Result := -1;
end;

procedure TTrackingAllocator.AddRecord(APtr: Pointer; ASize: SizeUInt);
var
  LNewCapacity: SizeInt;
begin
  if APtr = nil then
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
  FRecords[FCount].Ptr := APtr;
  FRecords[FCount].Size := ASize;
  FRecords[FCount].AllocId := FNextAllocId;
  Inc(FNextAllocId);
  Inc(FCount);
end;

procedure TTrackingAllocator.RemoveRecord(APtr: Pointer);
var
  LIdx: SizeInt;
begin
  if APtr = nil then
    Exit;
  LIdx := FindRecordIndex(APtr);
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

function TTrackingAllocator.DoGetMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.GetMem(ASize);
  EnterCriticalSection(FLock);
  try
    AddRecord(Result, ASize);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.DoAllocMem(ASize: SizeUInt): Pointer;
begin
  Result := FInner.AllocMem(ASize);
  EnterCriticalSection(FLock);
  try
    AddRecord(Result, ASize);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.DoReallocMem(ADst: Pointer; ASize: SizeUInt): Pointer;
begin
  Result := FInner.ReallocMem(ADst, ASize);
  EnterCriticalSection(FLock);
  try
    if Result <> nil then
    begin
      if ADst <> nil then
        UpdateRecord(ADst, Result, ASize)
      else
        AddRecord(Result, ASize);
    end
    else if ADst <> nil then
    begin
      { ReallocMem 失败：原指针仍有效 }
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

procedure TTrackingAllocator.DoFreeMem(ADst: Pointer);
begin
  FInner.FreeMem(ADst);
  EnterCriticalSection(FLock);
  try
    RemoveRecord(ADst);
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.DoMemSize(APtr: Pointer): SizeUInt;
begin
  Result := FInner.MemSize(APtr);
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

function PtrToHexString(AValue: PtrUInt): string;
const
  HexDigits: array[0..15] of AnsiChar = '0123456789ABCDEF';
var
  LBuf: array[0..SizeOf(Pointer) * 2 - 1] of AnsiChar;
  LIdx: Integer;
begin
  for LIdx := High(LBuf) downto 0 do
  begin
    LBuf[LIdx] := HexDigits[AValue and $F];
    AValue := AValue shr 4;
  end;
  SetString(Result, PAnsiChar(@LBuf[0]), Length(LBuf));
end;

function TTrackingAllocator.ReportLeaks: string;
var
  I: SizeInt;
  LLine: string;
  LCountStr: string;
begin
  EnterCriticalSection(FLock);
  try
    if FCount = 0 then
      Exit('No leaks detected.');
    Str(FCount, LCountStr);
    Result := 'Leak report: ' + LCountStr + ' block(s) not freed:' + #10;
    for I := 0 to FCount - 1 do
    begin
      Str(FRecords[I].AllocId, LLine);
      Result := Result + '  [' + LLine + '] $';
      Result := Result + PtrToHexString(PtrUInt(FRecords[I].Ptr));
      Str(FRecords[I].Size, LLine);
      Result := Result + ' size=' + LLine + #10;
    end;
  finally
    LeaveCriticalSection(FLock);
  end;
end;

function TTrackingAllocator.Traits: TAllocatorTraits;
begin
  Result.ZeroInitialized := False;
  Result.ThreadSafe      := True;
  Result.HasMemSize      := FInner.Traits.HasMemSize;
  Result.SupportsAligned := False;
end;

end.
