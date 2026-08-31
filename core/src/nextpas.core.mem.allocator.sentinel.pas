{
# nextpas.core.mem.allocator.sentinel

## 摘要

哨兵守卫分配器 — 轻量级 double-free / buffer-overflow / use-after-free 检测。

特性:
- **哨兵值**: 每次分配前后写入 magic bytes，检测缓冲区溢出
- **延迟释放队列**: 释放的内存进入隔离区，真正释放最老的条目
- **校验和**: 元数据完整性校验，检测内存踩踏

布局:
```
[PreSentinel 8B][UserSize SizeUInt][AllocId 8B][Checksum 8B][User data...][PostSentinel 8B]
                                      ^ returned pointer
```

适用场景: 测试/诊断环境，检测堆安全问题。

Author:    nextpas.core
Copyright: (c) 2025 nextpas.core. All rights reserved.
}

unit nextpas.core.mem.allocator.sentinel;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.mem.base,
  nextpas.core.mem.intf;

const
  {** 默认隔离队列深度 }
  DEFAULT_QUARANTINE_DEPTH = 256;

type
  {** TSentinelAllocator
   *
   *  包装任意 IAllocator，添加哨兵值保护和延迟释放队列。
   *  检测: 缓冲区溢出、double-free、use-after-free、元数据损坏。
   *
   *  @warning 有内存和性能开销，仅用于测试/诊断场景。
   *}
  TSentinelAllocator = class(TInterfacedObject, IAllocator)
  private
    FInner: IAllocator;
    FNextAllocId: QWord;
    { Quarantine ring buffer }
    FQuarantinePtrs: array of Pointer;
    FQuarantineSizes: array of SizeUInt;
    FQuarantineHead: Integer;
    FQuarantineCount: Integer;
    FQuarantineDepth: Integer;
    procedure DrainOldest;
    procedure QuarantinePush(APtr: Pointer; ASize: SizeUInt);
    procedure VerifySentinel(APtr: Pointer);
  public
    {** 创建哨兵分配器
     *  @param AInner 内部分配器
     *  @param AQuarantineDepth 隔离队列深度 (0 = 禁用延迟释放) }
    constructor Create(AInner: IAllocator;
      AQuarantineDepth: Integer = DEFAULT_QUARANTINE_DEPTH);
    destructor Destroy; override;

    function GetMem(ASize: SizeUInt): Pointer; inline;
    function AllocMem(ASize: SizeUInt): Pointer; inline;
    function ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
    procedure FreeMem(APtr: Pointer); inline;

    {** 隔离队列中待释放的块数 }
    function QuarantineCount: Integer;
    {** 强制释放隔离队列中所有块 }
    procedure DrainQuarantine;

    function Traits: TAllocatorTraits; inline;
  end;

implementation

uses
  nextpas.core.mem.error;

const
  { Magic sentinel values — chosen for easy identification in hex dumps }
  SENTINEL_PRE  = UInt64($DEADBEEFCAFEBABE);
  SENTINEL_POST = UInt64($BAADF00DDEADC0DE);
  { Poison byte for freed memory — same as FPC's heaptrc }
  POISON_BYTE   = $DD;

type
  PSentinelHeader = ^TSentinelHeader;
  TSentinelHeader = record
    PreSentinel: UInt64;
    UserSize: SizeUInt;
    AllocId: QWord;
    Checksum: UInt64;
  end;

const
  HEADER_SIZE = SizeOf(TSentinelHeader);
  POST_SENTINEL_SIZE = SizeOf(UInt64);

{ Checksum = XOR of pointer, size, allocid, with bit mixing }
function CalcChecksum(APtr: Pointer; ASize: SizeUInt; AAllocId: QWord): UInt64; inline;
begin
  Result := UInt64(PtrUInt(APtr))
    xor (UInt64(ASize) shl 32)
    xor UInt64(AAllocId)
    xor (UInt64(AAllocId) shl 17);
  { Avalanche mixing }
  Result := Result xor (Result shr 33);
  Result := Result * $FF51AFD7ED558CCD;
  Result := Result xor (Result shr 33);
end;

function PostSentinelPtr(AHdrPtr: Pointer; AUserSize: SizeUInt): PUInt64; inline;
begin
  Result := PUInt64(PtrUInt(AHdrPtr) + HEADER_SIZE + AUserSize);
end;

{ --- TSentinelAllocator --- }

constructor TSentinelAllocator.Create(AInner: IAllocator;
  AQuarantineDepth: Integer);
begin
  inherited Create;
  if AInner = nil then
    raise EArgumentNil.Create('TSentinelAllocator.Create: AInner cannot be nil');
  FInner := AInner;
  FNextAllocId := 1;
  if AQuarantineDepth < 0 then
    AQuarantineDepth := 0;
  FQuarantineDepth := AQuarantineDepth;
  if FQuarantineDepth > 0 then
  begin
    SetLength(FQuarantinePtrs, FQuarantineDepth);
    SetLength(FQuarantineSizes, FQuarantineDepth);
  end;
  FQuarantineHead := 0;
  FQuarantineCount := 0;
end;

destructor TSentinelAllocator.Destroy;
begin
  DrainQuarantine;
  FInner := nil;
  inherited Destroy;
end;

procedure TSentinelAllocator.DrainOldest;
var
  LIdx: Integer;
  LPtr: Pointer;
begin
  if FQuarantineCount = 0 then Exit;
  LIdx := (FQuarantineHead + FQuarantineDepth - FQuarantineCount) mod FQuarantineDepth;
  LPtr := FQuarantinePtrs[LIdx];
  FQuarantinePtrs[LIdx] := nil;
  FQuarantineSizes[LIdx] := 0;
  Dec(FQuarantineCount);
  { Release the full block: header + user + post-sentinel }
  if LPtr <> nil then
    FInner.FreeMem(LPtr);
end;

procedure TSentinelAllocator.QuarantinePush(APtr: Pointer; ASize: SizeUInt);
begin
  if FQuarantineDepth = 0 then
  begin
    { No quarantine — release immediately }
    FInner.FreeMem(APtr);
    Exit;
  end;
  { If queue full, drain oldest to make room }
  if FQuarantineCount >= FQuarantineDepth then
    DrainOldest;
  { Poison user data to detect use-after-free }
  FillChar(Pointer(PtrUInt(APtr) + HEADER_SIZE)^, ASize, POISON_BYTE);
  { Push to ring buffer }
  FQuarantinePtrs[FQuarantineHead] := APtr;
  FQuarantineSizes[FQuarantineHead] := ASize;
  FQuarantineHead := (FQuarantineHead + 1) mod FQuarantineDepth;
  Inc(FQuarantineCount);
end;

procedure TSentinelAllocator.VerifySentinel(APtr: Pointer);
var
  LHdr: PSentinelHeader;
  LPost: PUInt64;
  LExpected: UInt64;
begin
  LHdr := PSentinelHeader(APtr);
  { Check pre-sentinel }
  if LHdr^.PreSentinel <> SENTINEL_PRE then
    raise EAllocError.Create(aeSentinelCorrupted,
      FormatAllocErrorMsg('TSentinelAllocator', 'FreeMem', 'Pre-sentinel corrupted — possible buffer underflow or wild pointer'));
  { Check post-sentinel }
  LPost := PostSentinelPtr(APtr, LHdr^.UserSize);
  if LPost^ <> SENTINEL_POST then
    raise EAllocError.Create(aeSentinelCorrupted,
      FormatAllocErrorMsg('TSentinelAllocator', 'FreeMem', 'Post-sentinel corrupted — possible buffer overflow'));
  { Check checksum }
  LExpected := CalcChecksum(Pointer(PtrUInt(APtr) + HEADER_SIZE),
    LHdr^.UserSize, LHdr^.AllocId);
  if LHdr^.Checksum <> LExpected then
    raise EAllocError.Create(aeChecksumFailure,
      FormatAllocErrorMsg('TSentinelAllocator', 'FreeMem', 'Checksum mismatch — metadata corrupted'));
end;

function TSentinelAllocator.GetMem(ASize: SizeUInt): Pointer; inline;
var
  LTotalSize: SizeUInt;
  LHdr: PSentinelHeader;
  LPost: PUInt64;
  LUserPtr: Pointer;
begin
  if ASize = 0 then
    Exit(nil);
  Result := nil;
  { Check for overflow in size calculation }
  LTotalSize := ASize + HEADER_SIZE + POST_SENTINEL_SIZE;
  if LTotalSize < ASize then Exit;

  LUserPtr := FInner.GetMem(LTotalSize);
  if LUserPtr = nil then Exit;

  { Write header }
  LHdr := PSentinelHeader(LUserPtr);
  LHdr^.PreSentinel := SENTINEL_PRE;
  LHdr^.UserSize := ASize;
  LHdr^.AllocId := FNextAllocId;
  Inc(FNextAllocId);

  { Write post-sentinel }
  LPost := PostSentinelPtr(LUserPtr, ASize);
  LPost^ := SENTINEL_POST;

  { Calculate and store checksum (after post-sentinel is written) }
  LHdr^.Checksum := CalcChecksum(
    Pointer(PtrUInt(LUserPtr) + HEADER_SIZE), ASize, LHdr^.AllocId);

  Result := Pointer(PtrUInt(LUserPtr) + HEADER_SIZE);
end;

function TSentinelAllocator.AllocMem(ASize: SizeUInt): Pointer; inline;
begin
  Result := GetMem(ASize);
  if Result <> nil then
    FillChar(Result^, ASize, 0);
end;

function TSentinelAllocator.ReallocMem(APtr: Pointer; ASize: SizeUInt): Pointer; inline;
var
  LHdr: PSentinelHeader;
  LOldSize: SizeUInt;
  LCopySize: SizeUInt;
  LBasePtr: Pointer;
begin
  if ASize = 0 then begin FreeMem(APtr); Exit(nil); end;
  if APtr = nil then
    Exit(GetMem(ASize));

  { Verify old block sentinels before realloc }
  LBasePtr := Pointer(PtrUInt(APtr) - HEADER_SIZE);
  VerifySentinel(LBasePtr);
  LHdr := PSentinelHeader(LBasePtr);
  LOldSize := LHdr^.UserSize;

  { Allocate new block }
  Result := GetMem(ASize);
  if Result = nil then Exit;

  { Copy old data }
  if LOldSize < ASize then
    LCopySize := LOldSize
  else
    LCopySize := ASize;
  if LCopySize > 0 then
    Move(APtr^, Result^, LCopySize);

  { Free old (through quarantine) }
  FreeMem(APtr);
end;

procedure TSentinelAllocator.FreeMem(APtr: Pointer); inline;
var
  LBasePtr: Pointer;
  LHdr: PSentinelHeader;
  LUserSize: SizeUInt;
begin
  if APtr = nil then Exit;

  LBasePtr := Pointer(PtrUInt(APtr) - HEADER_SIZE);
  { Verify sentinels before freeing }
  VerifySentinel(LBasePtr);
  LHdr := PSentinelHeader(LBasePtr);
  LUserSize := LHdr^.UserSize;

  { Clear pre-sentinel to detect double-free on this exact block }
  LHdr^.PreSentinel := 0;

  { Push to quarantine (poisons user data, may drain oldest) }
  QuarantinePush(LBasePtr, LUserSize);
end;

function TSentinelAllocator.QuarantineCount: Integer;
begin
  Result := FQuarantineCount;
end;

procedure TSentinelAllocator.DrainQuarantine;
begin
  while FQuarantineCount > 0 do
    DrainOldest;
end;

function TSentinelAllocator.Traits: TAllocatorTraits; inline;
begin
  if FInner <> nil then
    Result := FInner.Traits
  else
  begin
    Result.ZeroInitialized := False;
    Result.ThreadSafe := False;
    Result.SupportsRealloc := True;
  end;
end;

end.
