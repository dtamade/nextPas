unit nextpas.core.git.native.pack;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.io.mapped,
  nextpas.core.collections.smallcache,
  nextpas.core.git.native.base,
  nextpas.core.git.native.zlib;

{ Packfile reader: mmapped .pack + .idx v2; delta chains capped at 64. }

type
  TPackFile = class
  private
    FPackPath: string;
    FMapped: IMappedFile;
    FData: PByte;
    FDataSize: SizeUInt;
    FIdxMapped: IMappedFile;
    FIdxData: PByte;
    FIdxSize: SizeUInt;
    FOids: array of TGitOid;
    FOffsets: array of Int64;
    function GetCount: Integer; inline;
    function IdxByteAt(APos: SizeUInt): Byte; inline;
    function IdxBE32(APos: SizeUInt): Cardinal; inline;
    function IdxBE64(APos: SizeUInt): Int64; inline;
    procedure LoadIndex(const AIdxPath: string);
    function FindOffset(const AOid: TGitOid): Int64;
    function ByteAt(APos: SizeUInt): Byte; inline;
    function InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
    procedure InflateInto(APos: SizeUInt; AExpectSize: Int64; var AReuse: TBytes);
    function TryPeekDeltaTargetSize(APos: SizeUInt; out ATargetSize: Int64): Boolean;
    function TryPeekCacheHit(APos: SizeUInt; out ATargetSize: Int64): Boolean; inline;
    procedure PeekCacheStore(APos: SizeUInt; ATargetSize: Int64); inline;
    function TryGetObjectSizeAtOffset(AOff: Int64; out AKind: TGitObjectKind; out ASize: Int64): Boolean;
    function TryGetObjectSizeAtOffsetDepth(AOff: Int64; ADepth: Integer; out AKind: TGitObjectKind; out ASize: Int64): Boolean;
    procedure ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
      out AData: TBytes; ADepth: Integer);
    function TryParsePackHeader(var APos: SizeUInt; out ATyp: Byte; out ASz: Int64): Boolean; inline;
    function TryParseOfsDelta(var APos: SizeUInt; out ARel: Int64): Boolean; inline;
  private
    FPeekCache: TPeekSmallCache;
  public
    constructor Create(const AIdxPath, APackPath: string);
    function Contains(const AOid: TGitOid): Boolean;
    function ReadObject(const AOid: TGitOid; out AKind: TGitObjectKind): TBytes;
    function TryReadObject(const AOid: TGitOid; out AKind: TGitObjectKind;
      out AData: TBytes): Boolean;
    function TryGetObjectSize(const AOid: TGitOid; out AKind: TGitObjectKind;
      out ASize: Int64): Boolean;
    property Count: Integer read GetCount;
    property PackPath: string read FPackPath;
  end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;
function GitApplyDeltaReuse(const ABase, ADelta: TBytes; var AReuse: TBytes): TBytes;

const
  GitMaxDeltaDepth = 64;
  GitMaxDeltaTargetSize = 256 * 1024 * 1024;
  // pack header varint: type(3b @4) + size(4b low + 7b/cont)
  PackHdrContBit = $80;
  PackHdrTypeMask = $07;
  PackHdrTypeShift = 4;
  PackHdrSizeLowMask = $0F;
  PackHdrSizeLowBits = 4;
  PackHdrSizeContMask = $7F;
  PackHdrSizeContBits = 7;
  // ofs_delta offset varint
  OfsDeltaContBit = $80;
  OfsDeltaPayloadMask = $7F;
  OfsDeltaPayloadBits = 7;
  // delta op: copy $80 set, off bits 0..3, size bits 4..6, zero size => $10000
  DeltaCopyFlag = $80;
  DeltaCopyOffMask = $0F;
  DeltaCopySizeMask = $70;
  DeltaCopySizeBit0 = $10;
  DeltaCopySizeDefault = $10000;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.encoding.varint,
  nextpas.core.collections.algorithms;

{ Delta apply: bytes.ops SpanCopy single source. }
procedure GitApplyDeltaInto(const ABase, ADelta: TBytes; var AOut: TBytes);
var
  P: SizeInt;
  SrcSize, TgtSize, OutPos, CopyOff, CopySize: Int64;
  Op: Byte;
  I: Integer;
  LBaseSpan, LDeltaSpan, LOutSpan: TByteSpan;
  USrc, UTgt: UInt64;
begin
  LBaseSpan := TByteSpan.FromBytes(ABase);
  LDeltaSpan := TByteSpan.FromBytes(ADelta);
  P := 0;
  if not TryVarintDecode(ADelta, P, USrc) then
    raise EGitError.Create('truncated varint in pack data');
  if USrc > UInt64(High(Int64)) then
    raise EGitError.Create('delta base size out of range');
  SrcSize := Int64(USrc);
  if SrcSize <> Int64(LBaseSpan.Len) then
    raise EGitError.Create('delta base size mismatch');
  if not TryVarintDecode(ADelta, P, UTgt) then
    raise EGitError.Create('truncated varint in pack data');
  if UTgt > UInt64(MaxInt) then
    raise EGitError.Create('delta target size out of range');
  if UTgt > UInt64(GitMaxDeltaTargetSize) then
    raise EGitError.Create('delta target size exceeds limit');
  TgtSize := Int64(UTgt);
  if Int64(Length(AOut)) <> TgtSize then
    SetLength(AOut, TgtSize); // single SetLength exact
  if TgtSize = 0 then
    Exit;
  LOutSpan := TByteSpan.FromBytes(AOut);
  OutPos := 0;
  while P < Length(ADelta) do
  begin
    Op := ADelta[P];
    Inc(P);
    if (Op and DeltaCopyFlag) <> 0 then
    begin
      CopyOff := 0;
      CopySize := 0;
      for I := 0 to 3 do
        if (Op and (1 shl I)) <> 0 then
        begin
          CopyOff := CopyOff or (Int64(ADelta[P]) shl (8 * I));
          Inc(P);
        end;
      for I := 0 to 2 do
        if (Op and (DeltaCopySizeBit0 shl I)) <> 0 then
        begin
          CopySize := CopySize or (Int64(ADelta[P]) shl (8 * I));
          Inc(P);
        end;
      if CopySize = 0 then
        CopySize := DeltaCopySizeDefault;
      if (CopyOff < 0) or (CopySize <= 0) or (CopyOff > Int64(LBaseSpan.Len) - CopySize)
        or (OutPos > TgtSize - CopySize) or (P > Length(ADelta)) then
        raise EGitError.Create('delta copy instruction out of bounds');
      // bytes.ops single source
      SpanCopy(TByteSpan.Create(LOutSpan.Data + SizeUInt(OutPos), SizeUInt(CopySize)),
        TByteSpan.Create(LBaseSpan.Data + SizeUInt(CopyOff), SizeUInt(CopySize)));
      OutPos := OutPos + CopySize;
    end
    else if Op > 0 then
    begin
      if (P > Length(ADelta) - Op) or (OutPos > TgtSize - Op) then
        raise EGitError.Create('delta insert instruction out of bounds');
      // bytes.ops single source
      SpanCopy(TByteSpan.Create(LOutSpan.Data + SizeUInt(OutPos), SizeUInt(Op)),
        TByteSpan.Create(LDeltaSpan.Data + SizeUInt(P), SizeUInt(Op)));
      OutPos := OutPos + Op;
      Inc(P, Op);
    end
    else
      raise EGitError.Create('invalid delta opcode 0');
  end;
  if OutPos <> TgtSize then
    raise EGitError.Create('delta produced wrong output size');
end;

function GitApplyDeltaReuse(const ABase, ADelta: TBytes; var AReuse: TBytes): TBytes;
begin
  GitApplyDeltaInto(ABase, ADelta, AReuse);
  Result := AReuse;
end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;
var
  LReuse: TBytes;
begin
  LReuse := nil;
  GitApplyDeltaInto(ABase, ADelta, LReuse);
  Result := LReuse;
end;

{ TPackFile }

constructor TPackFile.Create(const AIdxPath, APackPath: string);
begin
  inherited Create;
  FPackPath := APackPath;
  FMapped := MmapOpen(APackPath);
  FData := FMapped.Data;
  FDataSize := SizeUInt(FMapped.Size);
  FPeekCache.Init;
  LoadIndex(AIdxPath);
end;

function TPackFile.GetCount: Integer; inline;
begin
  Result := Length(FOids);
end;

function TPackFile.IdxByteAt(APos: SizeUInt): Byte; inline;
begin
  if APos >= FIdxSize then
    raise EGitError.Create('truncated pack index');
  Result := FIdxData[APos];
end;

function TPackFile.IdxBE32(APos: SizeUInt): Cardinal; inline;
begin
  if APos + 4 > FIdxSize then
    raise EGitError.Create('truncated pack index');
  Result := ReadUInt32BE(FIdxData + APos);
end;

function TPackFile.IdxBE64(APos: SizeUInt): Int64; inline;
var
  Hi, Lo: Cardinal;
begin
  Hi := IdxBE32(APos);
  Lo := IdxBE32(APos + 4);
  Result := (Int64(Hi) shl 32) or Int64(Lo);
end;

procedure TPackFile.LoadIndex(const AIdxPath: string);
var
  N, I, J: Integer;
  Off32: Cardinal;
  LargeBase, LOff: SizeUInt;
  LargeCount: Cardinal;
  LOidBase, LCrcBase, LOff32Base, LLargeCountPos: SizeUInt;
  Tmp: SizeUInt;
begin
  // mmap zero-copy view: no TBytes alloc/copy, single page-backed span; resource held via FIdxMapped interface
  FIdxMapped := MmapOpen(AIdxPath);
  FIdxData := FIdxMapped.Data;
  FIdxSize := SizeUInt(FIdxMapped.Size);
  if FIdxSize < 8 then
    raise EGitError.Create('truncated pack index');
  if (FIdxData[0] <> $FF) or (FIdxData[1] <> Ord('t')) or (FIdxData[2] <> Ord('O'))
    or (FIdxData[3] <> Ord('c')) then
    raise EGitError.Create('unsupported pack index format (need v2)');
  if IdxBE32(4) <> 2 then
    raise EGitError.Create('unsupported pack index version');
  N := Integer(IdxBE32(8 + 255 * 4));
  if N < 0 then
    raise EGitError.Create('corrupt pack index object count');
  // overflow guards before any size-derived allocation or offset calc
  if (N > 0) and (SizeUInt(N) > High(SizeUInt) div 20) then
    raise EGitError.Create('pack index too large');
  if (N > 0) and (SizeUInt(N) > High(SizeUInt) div 4) then
    raise EGitError.Create('pack index too large');
  LOidBase := 8 + 256 * 4;
  if (N > 0) and (LOidBase > High(SizeUInt) - SizeUInt(N) * 20) then
    raise EGitError.Create('pack index offset overflow');
  LCrcBase := LOidBase + SizeUInt(N) * 20;
  if (N > 0) and (LCrcBase > High(SizeUInt) - SizeUInt(N) * 4) then
    raise EGitError.Create('pack index offset overflow');
  LOff32Base := LCrcBase + SizeUInt(N) * 4;
  if (N > 0) and (LOff32Base > High(SizeUInt) - SizeUInt(N) * 4) then
    raise EGitError.Create('pack index offset overflow');
  LLargeCountPos := LOff32Base + SizeUInt(N) * 4;
  SetLength(FOids, N);
  SetLength(FOffsets, N);
  for I := 0 to N - 1 do
  begin
    // overflow-safe oid slice: LOidBase + I*20
    if SizeUInt(I) > (High(SizeUInt) - LOidBase) div 20 then
      raise EGitError.Create('pack index offset overflow');
    Tmp := LOidBase + SizeUInt(I) * 20;
    if Tmp + GitOidRawLen > FIdxSize then
      raise EGitError.Create('truncated pack index');
    // bytes.ops single source: SpanCopy via TByteSpan (zero-copy mmap view, inline, single Move)
    SpanCopy(TByteSpan.Create(@FOids[I].Bytes[0], GitOidRawLen),
      TByteSpan.Create(FIdxData + Tmp, GitOidRawLen));
  end;
  for I := 0 to N - 1 do
  begin
    if SizeUInt(I) > (High(SizeUInt) - LOff32Base) div 4 then
      raise EGitError.Create('pack index offset overflow');
    Tmp := LOff32Base + SizeUInt(I) * 4;
    Off32 := IdxBE32(Tmp);
    if (Off32 and $80000000) <> 0 then
    begin
      J := Integer(Off32 and $7FFFFFFF);
      if LLargeCountPos > High(SizeUInt) - 4 then
        raise EGitError.Create('pack index offset overflow');
      if LLargeCountPos + 4 > FIdxSize then
        raise EGitError.Create('truncated pack index');
      LargeCount := IdxBE32(LLargeCountPos);
      if (J < 0) or (Cardinal(J) >= LargeCount) then
        raise EGitError.Create('large offset index out of range');
      if LLargeCountPos > High(SizeUInt) - 4 then
        raise EGitError.Create('pack index offset overflow');
      LargeBase := LLargeCountPos + 4;
      if SizeUInt(J) > (High(SizeUInt) - LargeBase) div 8 then
        raise EGitError.Create('pack index offset overflow');
      LOff := LargeBase + SizeUInt(J) * 8;
      if LOff > High(SizeUInt) - 8 then
        raise EGitError.Create('pack index offset overflow');
      if LOff + 8 > FIdxSize then
        raise EGitError.Create('truncated pack index');
      FOffsets[I] := IdxBE64(LOff);
    end
    else
      FOffsets[I] := Int64(Off32);
  end;
end;

function PackOidCompare(const A, B: TGitOid; AData: Pointer): SizeInt;
begin
  Result := CompareBytesOrdered(@A.Bytes[0], @B.Bytes[0], GitOidRawLen, GitOidRawLen);
end;

function TPackFile.FindOffset(const AOid: TGitOid): Int64;
var
  LIdx: SizeInt;
begin
  if specialize BinarySearch<TGitOid>(FOids, AOid, @PackOidCompare, nil, LIdx) then
    Result := FOffsets[LIdx]
  else
    Result := -1;
end;

function TPackFile.Contains(const AOid: TGitOid): Boolean;
begin
  Result := FindOffset(AOid) >= 0;
end;

function TPackFile.ByteAt(APos: SizeUInt): Byte; inline;
begin
  if APos >= FDataSize then
    raise EGitError.Create('truncated packfile');
  Result := FData[APos];
end;

function TPackFile.TryParsePackHeader(var APos: SizeUInt; out ATyp: Byte; out ASz: Int64): Boolean; inline;
var
  B: Byte;
  Shift: Integer;
begin
  Result := False;
  if APos >= FDataSize then Exit;
  B := FData[APos]; Inc(APos);
  ATyp := (B shr PackHdrTypeShift) and PackHdrTypeMask;
  ASz := B and PackHdrSizeLowMask;
  Shift := PackHdrSizeLowBits;
  while (B and PackHdrContBit) <> 0 do
  begin
    if Shift > 63 then Exit;
    if APos >= FDataSize then Exit;
    B := FData[APos]; Inc(APos);
    ASz := ASz or (Int64(B and PackHdrSizeContMask) shl Shift);
    if ASz < 0 then Exit;
    Inc(Shift, PackHdrSizeContBits);
  end;
  Result := (ASz >= 0) and (ASz <= MaxInt);
end;

function TPackFile.TryParseOfsDelta(var APos: SizeUInt; out ARel: Int64): Boolean; inline;
var
  B: Byte;
begin
  Result := False;
  if APos >= FDataSize then Exit;
  B := FData[APos]; Inc(APos);
  ARel := B and OfsDeltaPayloadMask;
  while (B and OfsDeltaContBit) <> 0 do
  begin
    if ARel > (High(Int64) shr OfsDeltaPayloadBits) then Exit;
    if APos >= FDataSize then Exit;
    B := FData[APos]; Inc(APos);
    ARel := ((ARel + 1) shl OfsDeltaPayloadBits) or (B and OfsDeltaPayloadMask);
  end;
  Result := True;
end;

function TPackFile.InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
var
  LReuse: TBytes;
begin
  // Heavy zlib path.
  LReuse := nil;
  InflateInto(APos, AExpectSize, LReuse);
  Result := LReuse;
end;

procedure TPackFile.InflateInto(APos: SizeUInt; AExpectSize: Int64; var AReuse: TBytes);
var
  EndPos: SizeUInt;
  Got: SizeUInt;
  PDst: PByte;
begin
  // bytes.ops single source: single SetLength exact
  if (AExpectSize < 0) or (AExpectSize > MaxInt) then
    raise EGitError.Create('pack entry inflated size out of range');
  if SizeUInt(Length(AReuse)) <> SizeUInt(AExpectSize) then
    SetLength(AReuse, SizeUInt(AExpectSize));
  if AExpectSize = 0 then
    PDst := nil
  else
    PDst := PByte(AReuse);
  Got := GitZlibDecompressPtrToBuffer(FData, FDataSize, APos, EndPos, PDst, SizeUInt(AExpectSize));
  if Int64(Got) <> AExpectSize then
    raise EGitError.Create('pack entry inflated size mismatch');
end;

function TPackFile.TryPeekDeltaTargetSize(APos: SizeUInt; out ATargetSize: Int64): Boolean;
var
  Buf: array[0..31] of Byte;
  EndPos: SizeUInt;
  Got: SizeUInt;
  LSpan: TByteSpan;
  USrc, UTgt: UInt64;
begin
  // 32B prefix via GitZlibDecompressPrefix, bytes.ops single source
  Result := False;
  ATargetSize := 0;
  if APos >= FDataSize then
    Exit;
  if TryPeekCacheHit(APos, ATargetSize) then
    Exit(True);
  // corrupt prefix propagates EGitError (no silent swallow) for caller to distinguish missing->False vs corrupt->raise
  Got := GitZlibDecompressPrefix(FData, FDataSize, APos, @Buf[0], SizeUInt(Length(Buf)), EndPos);
  if Got = 0 then
    Exit;
  LSpan := TByteSpan.Create(@Buf[0], Got);
  if not TryVarintDecode(LSpan, USrc) then
    Exit;
  if not TryVarintDecode(LSpan, UTgt) then
    Exit;
  if UTgt > UInt64(High(Int64)) then
    Exit;
  if UTgt > UInt64(GitMaxDeltaTargetSize) then
    Exit;
  ATargetSize := Int64(UTgt);
  PeekCacheStore(APos, ATargetSize);
  Result := True;
end;

function TPackFile.TryPeekCacheHit(APos: SizeUInt; out ATargetSize: Int64): Boolean; inline;
begin
  Result := FPeekCache.TryGet(APos, ATargetSize);
end;

procedure TPackFile.PeekCacheStore(APos: SizeUInt; ATargetSize: Int64); inline;
begin
  FPeekCache.Put(APos, ATargetSize);
end;

procedure TPackFile.ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
  out AData: TBytes; ADepth: Integer);
type
  TChainEnt = record
    Typ: Byte;
    Sz: Int64;
    P: SizeUInt;
    BaseOff: SizeUInt;
    BaseOid: TGitOid;
    IsOfs: Boolean;
    IsRef: Boolean;
  end;
var
  Chain: array[0..GitMaxDeltaDepth] of TChainEnt;
  ChainLen: Integer;
  CurOff: SizeUInt;
  Typ: Byte;
  Sz: Int64;
  P: SizeUInt;
  Rel: Int64;
  BaseOffSigned: Int64;
  I: Integer;
  CurKind: TGitObjectKind;
  CurData, ReuseBuf, DeltaBuf, Tmp: TBytes;
  BaseOid: TGitOid;
begin
  if ADepth > GitMaxDeltaDepth then
    raise EGitError.Create('delta chain too deep');
  ChainLen := 0;
  CurOff := AOffset;
  while True do
  begin
    if ChainLen > GitMaxDeltaDepth - ADepth then
      raise EGitError.Create('delta chain too deep');
    if ChainLen > High(Chain) then
      raise EGitError.Create('delta chain too deep');
    P := CurOff;
    if not TryParsePackHeader(P, Typ, Sz) then
      raise EGitError.Create('truncated pack entry header');
    Chain[ChainLen].Typ := Typ;
    Chain[ChainLen].Sz := Sz;
    Chain[ChainLen].IsOfs := False;
    Chain[ChainLen].IsRef := False;
    if Typ in [1..4] then
    begin
      Chain[ChainLen].P := P;
      Inc(ChainLen);
      Break;
    end
    else if Typ = 6 then
    begin
      if not TryParseOfsDelta(P, Rel) then
        raise EGitError.Create('truncated ofs_delta header');
      BaseOffSigned := Int64(CurOff) - Rel;
      if (BaseOffSigned < 0) or (BaseOffSigned >= Int64(CurOff)) then
        raise EGitError.Create('corrupt ofs_delta base offset');
      Chain[ChainLen].P := P;
      Chain[ChainLen].IsOfs := True;
      Chain[ChainLen].BaseOff := SizeUInt(BaseOffSigned);
      Inc(ChainLen);
      CurOff := SizeUInt(BaseOffSigned);
      Continue;
    end
    else if Typ = 7 then
    begin
      if P + GitOidRawLen > FDataSize then
        raise EGitError.Create('truncated ref_delta header');
      // bytes.ops single source: SpanCopy via TByteSpan (zero-copy, inline, single Move)
      SpanCopy(TByteSpan.Create(@BaseOid.Bytes[0], GitOidRawLen),
        TByteSpan.Create(FData + P, GitOidRawLen));
      Inc(P, GitOidRawLen);
      if FindOffset(BaseOid) < 0 then
        raise EGitError.CreateFmt('ref_delta base %s not in same pack',
          [GitOidToHex(BaseOid)]);
      Chain[ChainLen].P := P;
      Chain[ChainLen].IsRef := True;
      Chain[ChainLen].BaseOid := BaseOid;
      Chain[ChainLen].BaseOff := SizeUInt(FindOffset(BaseOid));
      Inc(ChainLen);
      CurOff := Chain[ChainLen-1].BaseOff;
      Continue;
    end
    else
      raise EGitError.CreateFmt('unknown pack entry type %d', [Typ]);
  end;
  // ChainLen >=1, last is base object, earlier are deltas in file order (delta -> ... -> base)
  // Base kind maps Typ 1..4
  case Chain[ChainLen-1].Typ of
    1: CurKind := gokCommit;
    2: CurKind := gokTree;
    3: CurKind := gokBlob;
    4: CurKind := gokTag;
  else
    raise EGitError.Create('unreachable base type');
  end;
  // inflate base once via zero-alloc buffer reuse (bytes.ops single source)
  CurData := nil;
  ReuseBuf := nil;
  DeltaBuf := nil;
  InflateInto(Chain[ChainLen-1].P, Chain[ChainLen-1].Sz, CurData);
  for I := ChainLen - 2 downto 0 do
  begin
    InflateInto(Chain[I].P, Chain[I].Sz, DeltaBuf);
    GitApplyDeltaInto(CurData, DeltaBuf, ReuseBuf);
    // ping-pong swap to keep capacity for next iteration, avoids O(depth*size) alloc jitter
    Tmp := CurData;
    CurData := ReuseBuf;
    ReuseBuf := Tmp;
    // DeltaBuf reused next iteration (capacity retained); managed TBytes no leak, try/finally via refcount
  end;
  AKind := CurKind;
  AData := CurData;
end;

function TPackFile.ReadObject(const AOid: TGitOid;
  out AKind: TGitObjectKind): TBytes;
var
  Off: Int64;
begin
  Off := FindOffset(AOid);
  if Off < 0 then
    raise EGitError.CreateFmt('object %s not found in pack %s',
      [GitOidToHex(AOid), FPackPath]);
  ReadEntry(SizeUInt(Off), AKind, Result, 0);
end;

function TPackFile.TryReadObject(const AOid: TGitOid; out AKind: TGitObjectKind;
  out AData: TBytes): Boolean;
var
  Off: Int64;
begin
  // Binary search single source; missing->False, corrupt->raise.
  Off := FindOffset(AOid);
  if Off < 0 then
    Exit(False);
  ReadEntry(SizeUInt(Off), AKind, AData, 0);
  Result := True;
end;

function TPackFile.TryGetObjectSize(const AOid: TGitOid; out AKind: TGitObjectKind;
  out ASize: Int64): Boolean;
var
  Off: Int64;
begin
  // Single FindOffset per OID.
  Off := FindOffset(AOid);
  if Off < 0 then
    Exit(False);
  Result := TryGetObjectSizeAtOffset(Off, AKind, ASize);
end;

function TPackFile.TryGetObjectSizeAtOffset(AOff: Int64; out AKind: TGitObjectKind; out ASize: Int64): Boolean;
begin
  Result := TryGetObjectSizeAtOffsetDepth(AOff, 0, AKind, ASize);
end;

function TPackFile.TryGetObjectSizeAtOffsetDepth(AOff: Int64; ADepth: Integer; out AKind: TGitObjectKind; out ASize: Int64): Boolean;
var
  BaseOff: Int64;
  P, DeltaStart: SizeUInt;
  Typ: Byte;
  Sz: Int64;
  TgtSize: Int64;
  BaseOid: TGitOid;
  BaseKind: TGitObjectKind;
  BaseSize: Int64;
  Rel: Int64;

  function WalkKind(AStart: Int64; ARemain: Integer; out AFound: TGitObjectKind): Boolean;
  var
    LOff: Int64;
    LPos: SizeUInt;
    LTyp: Byte;
    LDepth: Integer;
    LRel: Int64;
    LSz: Int64;
    LTmpOid: TGitOid;
  begin
    Result := False;
    if ARemain < 0 then Exit;
    LOff := AStart;
    LDepth := 0;
    while LDepth <= ARemain do
    begin
      if (LOff < 0) or (LOff >= Int64(FDataSize)) then Exit;
      LPos := SizeUInt(LOff);
      if not TryParsePackHeader(LPos, LTyp, LSz) then Exit;
      case LTyp of
        1: begin AFound := gokCommit; Exit(True); end;
        2: begin AFound := gokTree; Exit(True); end;
        3: begin AFound := gokBlob; Exit(True); end;
        4: begin AFound := gokTag; Exit(True); end;
        6:
          begin
            if not TryParseOfsDelta(LPos, LRel) then Exit;
            LOff := LOff - LRel;
            if LOff < 0 then Exit;
            Inc(LDepth);
            Continue;
          end;
        7:
          begin
            if LPos + GitOidRawLen > FDataSize then Exit;
            SpanCopy(TByteSpan.Create(@LTmpOid.Bytes[0], GitOidRawLen),
              TByteSpan.Create(FData + LPos, GitOidRawLen));
            LOff := FindOffset(LTmpOid);
            if LOff < 0 then Exit;
            Inc(LDepth);
            Continue;
          end;
      else
        Exit;
      end;
    end;
  end;

begin
  Result := False;
  AKind := gokBlob;
  ASize := 0;
  if ADepth > GitMaxDeltaDepth then Exit;
  if (AOff < 0) or (AOff >= Int64(FDataSize)) then
    Exit;
  P := SizeUInt(AOff);
  if not TryParsePackHeader(P, Typ, Sz) then Exit;
  case Typ of
    1: begin AKind := gokCommit; ASize := Sz; Exit(True); end;
    2: begin AKind := gokTree; ASize := Sz; Exit(True); end;
    3: begin AKind := gokBlob; ASize := Sz; Exit(True); end;
    4: begin AKind := gokTag; ASize := Sz; Exit(True); end;
    6, 7:
      begin
        if ADepth >= GitMaxDeltaDepth then Exit;
        if Typ = 6 then
        begin
          if not TryParseOfsDelta(P, Rel) then Exit;
          BaseOff := AOff - Rel;
          if (BaseOff < 0) or (BaseOff >= AOff) then Exit;
          DeltaStart := P;
        end
        else
        begin
          if P + GitOidRawLen > FDataSize then Exit;
          SpanCopy(TByteSpan.Create(@BaseOid.Bytes[0], GitOidRawLen),
            TByteSpan.Create(FData + P, GitOidRawLen));
          Inc(P, GitOidRawLen);
          DeltaStart := P;
          BaseOff := FindOffset(BaseOid);
        end;
        if TryPeekCacheHit(DeltaStart, TgtSize) then
          ASize := TgtSize
        else if not TryPeekDeltaTargetSize(DeltaStart, TgtSize) then Exit
        else ASize := TgtSize;
        if Typ = 7 then
        begin
          if (BaseOff >= 0) and TryGetObjectSizeAtOffsetDepth(BaseOff, ADepth + 1, BaseKind, BaseSize) then
            AKind := BaseKind
          else if (BaseOff >= 0) and WalkKind(BaseOff, GitMaxDeltaDepth - ADepth - 1, BaseKind) then
            AKind := BaseKind;
        end
        else
        begin
          if WalkKind(BaseOff, GitMaxDeltaDepth - ADepth - 1, BaseKind) then
            AKind := BaseKind;
        end;
        Result := True;
      end;
  else
    Exit;
  end;
end;

end.
