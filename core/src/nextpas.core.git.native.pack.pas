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
    // delta peek cache helpers (O(1) hash, zero alloc, inline, zero-copy via stack buf)
    function TryPeekCacheHit(APos: SizeUInt; out ATargetSize: Int64): Boolean; inline;
    procedure PeekCacheStore(APos: SizeUInt; ATargetSize: Int64); inline;
    procedure ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
      out AData: TBytes; ADepth: Integer);
  private
    // hot rename pre-check cache: 32-entry direct-mapped hash (APos -> targetSize), O(1) single probe avoids per-candidate 32B inflate
    FPeekKeys: array[0..31] of SizeUInt;
    FPeekVals: array[0..31] of Int64;
    FPeekValid: array[0..31] of Boolean;
  public
    constructor Create(const AIdxPath, APackPath: string);
    function Contains(const AOid: TGitOid): Boolean;
    function ReadObject(const AOid: TGitOid; out AKind: TGitObjectKind): TBytes;
    function TryGetObjectSize(const AOid: TGitOid; out AKind: TGitObjectKind;
      out ASize: Int64): Boolean;
    property Count: Integer read GetCount;
    property PackPath: string read FPackPath;
  end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;
function GitApplyDeltaReuse(const ABase, ADelta: TBytes; var AReuse: TBytes): TBytes;

const
  GitMaxDeltaDepth = 64;
  // streaming cap: 256 MB (single source with DEFLATE MAX_DECOMPRESS_SIZE), prevents heap amplification via single huge SetLength
  GitMaxDeltaTargetSize = 256 * 1024 * 1024;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary,
  nextpas.core.encoding.varint;

{ GitApplyDeltaReuse: zero-copy span view + buffer reuse via bytes.ops single source.
  Core decode is single-source with GitApplyDelta; this wrapper reuses AReuse
  capacity (ping-pong) to avoid O(depth) allocations.
  Perf: heavy decode loop NOT inline — I-Cache redline; thin wrapper also not inline. }
procedure GitApplyDeltaInto(const ABase, ADelta: TBytes; var AOut: TBytes);
var
  P: SizeInt;
  SrcSize, TgtSize, OutPos, CopyOff, CopySize: Int64;
  Op: Byte;
  I: Integer;
  LBaseSpan, LDeltaSpan, LOutSpan: TByteSpan;
  USrc, UTgt: UInt64;
begin
  // zero-copy views (single source via bytes.ops, no allocation)
  LBaseSpan := TByteSpan.FromBytes(ABase);
  LDeltaSpan := TByteSpan.FromBytes(ADelta);
  P := 0;
  // single source varint via encoding.varint (inline zero-copy, no manual shift loop)
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
  // streaming cap + buffer reuse: bounded by GitMaxDeltaTargetSize (256 MB, same source as DEFLATE max), single SetLength, prevents heap amplification
  if Int64(Length(AOut)) <> TgtSize then
    SetLength(AOut, TgtSize);
  if TgtSize = 0 then
    Exit;
  LOutSpan := TByteSpan.FromBytes(AOut);
  OutPos := 0;
  while P < Length(ADelta) do
  begin
    Op := ADelta[P];
    Inc(P);
    if (Op and $80) <> 0 then
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
        if (Op and ($10 shl I)) <> 0 then
        begin
          CopySize := CopySize or (Int64(ADelta[P]) shl (8 * I));
          Inc(P);
        end;
      if CopySize = 0 then
        CopySize := $10000;
      // streaming chunk guard: overflow-safe via subtraction (bytes.ops single source for SpanCopy, inline, zero-copy Move)
      if (CopyOff < 0) or (CopySize <= 0) or (CopyOff > Int64(LBaseSpan.Len) - CopySize)
        or (OutPos > TgtSize - CopySize) or (P > Length(ADelta)) then
        raise EGitError.Create('delta copy instruction out of bounds');
      // bytes.ops single source: SpanCopy via TByteSpan (zero-copy, inline, single Move)
      SpanCopy(TByteSpan.Create(LOutSpan.Data + SizeUInt(OutPos), SizeUInt(CopySize)),
        TByteSpan.Create(LBaseSpan.Data + SizeUInt(CopyOff), SizeUInt(CopySize)));
      OutPos := OutPos + CopySize;
    end
    else if Op > 0 then
    begin
      // streaming chunk guard: overflow-safe via subtraction (zero-copy SpanCopy, bytes.ops single source)
      if (P > Length(ADelta) - Op) or (OutPos > TgtSize - Op) then
        raise EGitError.Create('delta insert instruction out of bounds');
      // bytes.ops single source: SpanCopy via TByteSpan (zero-copy, inline, single Move)
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
  // not inline: heavy loop stays out-of-line, I-Cache friendly; single source via GitApplyDeltaInto
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
  // cache zero-init: FPeekValid false via class zero-fill; direct-mapped hash, no round-robin state
  FillChar(FPeekValid, SizeOf(FPeekValid), 0);
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
  // single source via bytes.binary (zero-copy mmap view, bounds checked)
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
  // not inline — heavy zlib path; capacity reuse via bytes.ops single source
  // inflate directly into caller buffer to avoid O(depth) alloc/copy jitter on delta depth 64
  if (AExpectSize < 0) or (AExpectSize > MaxInt) then
    raise EGitError.Create('pack entry inflated size out of range');
  // bytes.ops single source: grow-only capacity reuse, no shrink realloc — keeps max capacity for delta depth 64 ping-pong, zero-copy via PByte view
  // inline header-poke shrink (no heap) keeps logical Length = Expect while retaining capacity; stability via refcount check
  if SizeUInt(Length(AReuse)) < SizeUInt(AExpectSize) then
    SetLength(AReuse, SizeUInt(AExpectSize))
  else if SizeUInt(Length(AReuse)) > SizeUInt(AExpectSize) then
  begin
    if AExpectSize = 0 then
      SetLength(AReuse, 0)
    else if (Pointer(AReuse) <> nil) and (PSizeInt(PByte(Pointer(AReuse)) - 2*SizeOf(SizeInt))^ = 1) then
      PSizeInt(PByte(Pointer(AReuse)) - SizeOf(SizeInt))^ := SizeInt(AExpectSize) - 1
    else
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
  // perf: prefix inflate 32B only (delta varints ≤20B) vs full InflateAt (Sz bytes)
  // hot rename similarity pre-check: per candidate saves full zlib inflate + alloc
  // zero-copy TByteSpan view over stack buf (bytes.ops single source), not inline heavy
  // single source varint via encoding.varint (inline, zero-copy TByteSpan advance)
  Result := False;
  ATargetSize := 0;
  if APos >= FDataSize then
    Exit;
  // fast cache: hot rename O(n*m) loop hits same delta offsets; O(1) hashed single probe avoids 32B inflate per candidate
  if TryPeekCacheHit(APos, ATargetSize) then
    Exit(True);
  try
    Got := GitZlibDecompressPrefix(FData, FDataSize, APos, @Buf[0], SizeUInt(Length(Buf)), EndPos);
  except
    on E: EGitError do Exit;
    on E: Exception do Exit;
  end;
  if Got = 0 then
    Exit;
  LSpan := TByteSpan.Create(@Buf[0], Got);
  // single source: two varints (src + target) via encoding.varint TryVarintDecode inline
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
  Idx: SizeUInt;
begin
  // O(1) hashed single-probe (mix low bits, zero alloc, inline), replaces O(32) linear scan; hot rename O(n*m) saves ~250k*32 compares
  Idx := (APos xor (APos shr 5) xor (APos shr 10) xor (APos shr 15)) and 31;
  if FPeekValid[Idx] and (FPeekKeys[Idx] = APos) then
  begin
    ATargetSize := FPeekVals[Idx];
    Exit(True);
  end;
  Result := False;
end;

procedure TPackFile.PeekCacheStore(APos: SizeUInt; ATargetSize: Int64); inline;
var
  Idx: SizeUInt;
begin
  // O(1) hashed store, single probe overwrite, zero alloc, inline; xor-shift mix spreads sequential pack offsets across 32 slots
  Idx := (APos xor (APos shr 5) xor (APos shr 10) xor (APos shr 15)) and 31;
  FPeekKeys[Idx] := APos;
  FPeekVals[Idx] := ATargetSize;
  FPeekValid[Idx] := True;
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
  // iteratively collect delta chain, avoid recursion and per-level stack allocs
  ChainLen := 0;
  CurOff := AOffset;
  while True do
  begin
    if ChainLen > GitMaxDeltaDepth - ADepth then
      raise EGitError.Create('delta chain too deep');
    P := CurOff;
    B := ByteAt(P);
    Inc(P);
    Typ := (B shr 4) and $07;
    Sz := B and $0F;
    Shift := 4;
    while (B and $80) <> 0 do
    begin
      if Shift > 63 then
        raise EGitError.Create('pack entry size varint overflow');
      B := ByteAt(P);
      Inc(P);
      Sz := Sz or (Int64(B and $7F) shl Shift);
      if Sz < 0 then
        raise EGitError.Create('pack entry size out of range');
      Inc(Shift, 7);
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
      Rel := B and $7F;
      while (B and $80) <> 0 do
      begin
        if Rel > (High(Int64) shr 7) then
          raise EGitError.Create('ofs_delta offset out of range');
        B := ByteAt(P);
        Inc(P);
        Rel := ((Rel + 1) shl 7) or (B and $7F);
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
  // unwind deltas in reverse: base-1 .. 0, reusing buffers ping-pong + DeltaBuf reuse
  // perf: not inline heavy paths; zero-copy TByteSpan.Move; single SetLength per layer
  for I := ChainLen - 2 downto 0 do
  begin
    InflateInto(Chain[I].P, Chain[I].Sz, DeltaBuf);
    // buffer reuse: GitApplyDeltaInto writes into ReuseBuf with single allocation, zero-copy spans via bytes.ops
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

function TPackFile.TryGetObjectSize(const AOid: TGitOid; out AKind: TGitObjectKind;
  out ASize: Int64): Boolean;
var
  Off, BaseOff: Int64;
  P, DeltaStart: SizeUInt;
  B, Typ: Byte;
  Sz: Int64;
  Shift: Integer;
  TgtSize: Int64;
  BaseOid: TGitOid;
  BaseKind: TGitObjectKind;
  BaseSize: Int64;
  Rel: Int64;

  // single source walk via direct FData view, inline zero-copy, no try/except
  function WalkKind(AStart: Int64; out AFound: TGitObjectKind): Boolean;
  var
    LOff: Int64;
    LPos: SizeUInt;
    LB, LTyp: Byte;
    LDepth: Integer;
    LRel: Int64;
    LTmpOid: TGitOid;
  begin
    Result := False;
    LOff := AStart;
    LDepth := 0;
    while LDepth <= GitMaxDeltaDepth do
    begin
      if (LOff < 0) or (LOff >= Int64(FDataSize)) then Exit;
      LPos := SizeUInt(LOff);
      if LPos >= FDataSize then Exit;
      LB := FData[LPos]; Inc(LPos);
      LTyp := (LB shr 4) and $07;
      while (LB and $80) <> 0 do
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
            LRel := LB and $7F;
            while (LB and $80) <> 0 do
            begin
              if LRel > (High(Int64) shr 7) then Exit;
              if LPos >= FDataSize then Exit;
              LB := FData[LPos]; Inc(LPos);
              LRel := ((LRel + 1) shl 7) or (LB and $7F);
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
  Off := FindOffset(AOid);
  if Off < 0 then
    Exit;
  // perf: header parse without inflate; zero-copy via FData direct view, inline bounds check (no exception)
  P := SizeUInt(Off);
  if P >= FDataSize then Exit;
  B := FData[P]; Inc(P);
  Typ := (B shr 4) and $07;
  Sz := Int64(B and $0F);
  Shift := 4;
  while (B and $80) <> 0 do
  begin
    if Shift > 63 then Exit;
    if P >= FDataSize then Exit;
    B := FData[P]; Inc(P);
    Sz := Sz or (Int64(B and $7F) shl Shift);
    if Sz < 0 then Exit;
    Inc(Shift, 7);
  end;
  if (Sz < 0) or (Sz > MaxInt) then Exit;
  case Typ of
    1: begin AKind := gokCommit; ASize := Sz; Exit(True); end;
    2: begin AKind := gokTree; ASize := Sz; Exit(True); end;
    3: begin AKind := gokBlob; ASize := Sz; Exit(True); end;
    4: begin AKind := gokTag; ASize := Sz; Exit(True); end;
    6, 7:
      begin
        // perf: single-pass capture of base id + delta start; no double header re-parse
        // 32B prefix inflate via TryPeekDeltaTargetSize (zero alloc, hot rename pre-check)
        if Typ = 6 then
        begin
          if P >= FDataSize then Exit;
          B := FData[P]; Inc(P);
          Rel := B and $7F;
          while (B and $80) <> 0 do
          begin
            if Rel > (High(Int64) shr 7) then Exit;
            if P >= FDataSize then Exit;
            B := FData[P]; Inc(P);
            Rel := ((Rel + 1) shl 7) or (B and $7F);
          end;
          BaseOff := Off - Rel;
          if (BaseOff < 0) or (BaseOff >= Off) then Exit;
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
        if not TryPeekDeltaTargetSize(DeltaStart, TgtSize) then Exit;
        ASize := TgtSize;
        // kind: header-only walk, no full inflate fallback, no try/except (explicit bounds, WalkKind single source)
        if Typ = 7 then
        begin
          if (BaseOff >= 0) and TryGetObjectSize(BaseOid, BaseKind, BaseSize) then
            AKind := BaseKind
          else if (BaseOff >= 0) and WalkKind(BaseOff, BaseKind) then
            AKind := BaseKind;
        end
        else
        begin
          if WalkKind(BaseOff, BaseKind) then
            AKind := BaseKind;
        end;
        Result := True;
      end;
  else
    Exit;
  end;
end;

end.
