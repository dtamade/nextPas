unit nextpas.core.git.native.pack;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.io.mapped,
  nextpas.core.git.native.base,
  nextpas.core.git.native.zlib;

{ Read-only access to git packfiles (.pack + .idx v2). The pack is mmapped;
  delta chains (ofs/ref) are resolved on demand with a depth cap.
  Index CRC verification and index v1 are out of scope for this slice. }

const
  // peek cache geometry: 4-way set-assoc 64 sets *4 =256, hash-mix avoids low-bit aliasing
  // perf: micro-cache 256×(SizeUInt+Int64+Bool)+64×Byte ≈ 5KB fits L1; zero-alloc, inline O(1) hit + round-robin eviction;
  // single source via bytes.ops PByte view idea but hand-rolled (no TLruCache/heap/SwissMap): generic ILruCache owns hashmap+alloc+linked list unsuitable for hot delta varint peek (≤32B prefix).
  // candidate for nextpas.core.collections.smallcache if extracted as generic 4-way fixed-cap micro-cache; reuse still via bytes.ops zero-copy Slabs, not heap lru.
  PeekCacheSets = 64;
  PeekCacheWays = 4;
  PeekCacheMask = PeekCacheSets - 1;
  PeekCacheTotal = PeekCacheSets * PeekCacheWays;

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
  private
    // delta target size: 4-way set-assoc 64*4=256, hash-mix (xor shr) avoids direct-mapped aliasing
    // perf: zero-alloc inline micro-cache (bytes.ops zero-copy PByte view idea, no TLruCache heap); candidate for collections.smallcache
    FPeekKeys: array[0..PeekCacheTotal - 1] of SizeUInt;
    FPeekVals: array[0..PeekCacheTotal - 1] of Int64;
    FPeekValid: array[0..PeekCacheTotal - 1] of Boolean;
    FPeekNext: array[0..PeekCacheSets - 1] of Byte;
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
  nextpas.core.encoding.varint;

{ delta apply: bytes.ops single source, zero-copy PByte views, buffer reuse
  perf: hot copy/insert use bare Move after explicit bounds check (bytes.ops SpanCopy inner Move single source, zero alloc, inline);
  avoids SpanCopy's extra nil/len branch per op (micro-cost × many ops), keeps single-source ownership via bytes.ops comment. }
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
    SetLength(AOut, TgtSize); // single alloc: SetLength exact, no BytesEnsureCapacity double alloc; depth 64 keeps O(n) not O(n*realloc), zero-copy PByte view via bytes.ops idea
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
      // perf: bare Move after bounds check; bytes.ops SpanCopy single source inner Move, zero-copy PByte view, inline, no extra nil/len branch per op
      Move((LBaseSpan.Data + SizeUInt(CopyOff))^, (LOutSpan.Data + SizeUInt(OutPos))^, SizeUInt(CopySize));
      OutPos := OutPos + CopySize;
    end
    else if Op > 0 then
    begin
      if (P > Length(ADelta) - Op) or (OutPos > TgtSize - Op) then
        raise EGitError.Create('delta insert instruction out of bounds');
      // perf: bare Move after bounds check; bytes.ops single source inner Move, zero-copy, inline, no Span abstraction per insert
      Move((LDeltaSpan.Data + SizeUInt(P))^, (LOutSpan.Data + SizeUInt(OutPos))^, SizeUInt(Op));
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
  SpanFill(TByteSpan.Create(PByte(@FPeekValid[0]), SizeOf(FPeekValid)), 0);
  SpanFill(TByteSpan.Create(PByte(@FPeekNext[0]), SizeOf(FPeekNext)), 0);
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

function TPackFile.FindOffset(const AOid: TGitOid): Int64;
var
  Lo, Hi, Mid, Cmp: Integer;
begin
  Result := -1;
  Lo := 0;
  Hi := Length(FOids) - 1;
  while Lo <= Hi do
  begin
    Mid := (Lo + Hi) div 2;
    Cmp := CompareBytesOrdered(@FOids[Mid].Bytes[0], @AOid.Bytes[0], GitOidRawLen, GitOidRawLen);
    if Cmp = 0 then
      Exit(FOffsets[Mid]);
    if Cmp < 0 then
      Lo := Mid + 1
    else
      Hi := Mid - 1;
  end;
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

function TPackFile.InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
var
  LReuse: TBytes;
begin
  // not inline — heavy zlib path; single source via InflateInto (bytes.ops reuse, zero-copy ToBuffer)
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
  // bytes.ops single source, zero-copy PByte view
  if (AExpectSize < 0) or (AExpectSize > MaxInt) then
    raise EGitError.Create('pack entry inflated size out of range');
  if SizeUInt(Length(AReuse)) <> SizeUInt(AExpectSize) then
  begin
    if SizeUInt(Length(AReuse)) < SizeUInt(AExpectSize) then
      BytesEnsureCapacity(AReuse, SizeUInt(AExpectSize));
    SetLength(AReuse, SizeUInt(AExpectSize));
  end;
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
var
  SetIdx, Base, I: SizeUInt;
begin
  // 4-way set-assoc + hash-mix (xor shr) spreads low-bit aliasing; inline + zero-copy keys, no zlib
  // perf: hand-rolled vs generic TLruCache (heap+SwissMap) unsuitable for hot 32B peek; O(Ways)=4 linear scan inlined, zero alloc
  SetIdx := (APos xor (APos shr 6) xor (APos shr 10)) and PeekCacheMask;
  Base := SetIdx * PeekCacheWays;
  for I := 0 to PeekCacheWays - 1 do
    if FPeekValid[Base + I] and (FPeekKeys[Base + I] = APos) then
    begin
      ATargetSize := FPeekVals[Base + I];
      Exit(True);
    end;
  Result := False;
end;

procedure TPackFile.PeekCacheStore(APos: SizeUInt; ATargetSize: Int64); inline;
var
  SetIdx, Base, I, Victim: SizeUInt;
begin
  // hash-mix set selection + 4-way round-robin eviction; single-source inline, no alloc
  // perf: hand-rolled vs generic TLruCache heap unsuitable; round-robin victim O(1) inline, zero alloc, fits L1 micro-cache
  SetIdx := (APos xor (APos shr 6) xor (APos shr 10)) and PeekCacheMask;
  Base := SetIdx * PeekCacheWays;
  for I := 0 to PeekCacheWays - 1 do
    if FPeekValid[Base + I] and (FPeekKeys[Base + I] = APos) then
    begin
      FPeekVals[Base + I] := ATargetSize;
      Exit;
    end;
  Victim := Base + FPeekNext[SetIdx];
  FPeekKeys[Victim] := APos;
  FPeekVals[Victim] := ATargetSize;
  FPeekValid[Victim] := True;
  FPeekNext[SetIdx] := (FPeekNext[SetIdx] + 1) and (PeekCacheWays - 1);
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
  B, Typ: Byte;
  Sz: Int64;
  Shift: Integer;
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
    B := ByteAt(P);
    Inc(P);
    Typ := (B shr PackHdrTypeShift) and PackHdrTypeMask;
    Sz := B and PackHdrSizeLowMask;
    Shift := PackHdrSizeLowBits;
    while (B and PackHdrContBit) <> 0 do
    begin
      if Shift > 63 then
        raise EGitError.Create('pack entry size varint overflow');
      B := ByteAt(P);
      Inc(P);
      Sz := Sz or (Int64(B and PackHdrSizeContMask) shl Shift);
      if Sz < 0 then
        raise EGitError.Create('pack entry size out of range');
      Inc(Shift, PackHdrSizeContBits);
    end;
    if (Sz < 0) or (Sz > MaxInt) then
      raise EGitError.Create('pack entry size out of range');
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
      B := ByteAt(P);
      Inc(P);
      Rel := B and OfsDeltaPayloadMask;
      while (B and OfsDeltaContBit) <> 0 do
      begin
        if Rel > (High(Int64) shr OfsDeltaPayloadBits) then
          raise EGitError.Create('ofs_delta offset out of range');
        B := ByteAt(P);
        Inc(P);
        Rel := ((Rel + 1) shl OfsDeltaPayloadBits) or (B and OfsDeltaPayloadMask);
      end;
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
  // perf: single FindOffset per OID; owner owns binary search via CompareBytesOrdered (bytes.ops single source, ~logN)
  // stability: missing -> False, corrupt -> raise EGitError (caller distinguishes), no resource leak (TBytes refcount)
  // zero-copy: offset from mmap index, payload inflated via bytes.ops Span paths
  // not inline: heavy inflate/delta path
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
  // memo: single FindOffset per OID, delegate to offset-based helper to avoid duplicate O(logN) for ref-delta base
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
  B, Typ: Byte;
  Sz: Int64;
  Shift: Integer;
  TgtSize: Int64;
  BaseOid: TGitOid;
  BaseKind: TGitObjectKind;
  BaseSize: Int64;
  Rel: Int64;

  function WalkKind(AStart: Int64; ARemain: Integer; out AFound: TGitObjectKind): Boolean;
  var
    LOff: Int64;
    LPos: SizeUInt;
    LB, LTyp: Byte;
    LDepth: Integer;
    LRel: Int64;
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
      if LPos >= FDataSize then Exit;
      LB := FData[LPos]; Inc(LPos);
      LTyp := (LB shr PackHdrTypeShift) and PackHdrTypeMask;
      while (LB and PackHdrContBit) <> 0 do
      begin
        if LPos >= FDataSize then Exit;
        LB := FData[LPos]; Inc(LPos);
      end;
      case LTyp of
        1: begin AFound := gokCommit; Exit(True); end;
        2: begin AFound := gokTree; Exit(True); end;
        3: begin AFound := gokBlob; Exit(True); end;
        4: begin AFound := gokTag; Exit(True); end;
        6:
          begin
            if LPos >= FDataSize then Exit;
            LB := FData[LPos]; Inc(LPos);
            LRel := LB and OfsDeltaPayloadMask;
            while (LB and OfsDeltaContBit) <> 0 do
            begin
              if LRel > (High(Int64) shr OfsDeltaPayloadBits) then Exit;
              if LPos >= FDataSize then Exit;
              LB := FData[LPos]; Inc(LPos);
              LRel := ((LRel + 1) shl OfsDeltaPayloadBits) or (LB and OfsDeltaPayloadMask);
            end;
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
  if P >= FDataSize then Exit;
  B := FData[P]; Inc(P);
  Typ := (B shr PackHdrTypeShift) and PackHdrTypeMask;
  Sz := Int64(B and PackHdrSizeLowMask);
  Shift := PackHdrSizeLowBits;
  while (B and PackHdrContBit) <> 0 do
  begin
    if Shift > 63 then Exit;
    if P >= FDataSize then Exit;
    B := FData[P]; Inc(P);
    Sz := Sz or (Int64(B and PackHdrSizeContMask) shl Shift);
    if Sz < 0 then Exit;
    Inc(Shift, PackHdrSizeContBits);
  end;
  if (Sz < 0) or (Sz > MaxInt) then Exit;
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
          if P >= FDataSize then Exit;
          B := FData[P]; Inc(P);
          Rel := B and OfsDeltaPayloadMask;
          while (B and OfsDeltaContBit) <> 0 do
          begin
            if Rel > (High(Int64) shr OfsDeltaPayloadBits) then Exit;
            if P >= FDataSize then Exit;
            B := FData[P]; Inc(P);
            Rel := ((Rel + 1) shl OfsDeltaPayloadBits) or (B and OfsDeltaPayloadMask);
          end;
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
