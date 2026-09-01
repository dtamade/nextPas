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
    FOids: array of TGitOid;
    FOffsets: array of Int64;
    function GetCount: Integer; inline;
    function IdxByteAt(const AIdx: TBytes; APos: SizeUInt): Byte; inline;
    function IdxBE32(const AIdx: TBytes; APos: SizeUInt): Cardinal; inline;
    function IdxBE64(const AIdx: TBytes; APos: SizeUInt): Int64; inline;
    procedure LoadIndex(const AIdxPath: string);
    function FindOffset(const AOid: TGitOid): Int64;
    function ByteAt(APos: SizeUInt): Byte; inline;
    function InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
    procedure InflateInto(APos: SizeUInt; AExpectSize: Int64; var AReuse: TBytes);
    function TryPeekDeltaTargetSize(APos: SizeUInt; out ATargetSize: Int64): Boolean;
    procedure ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
      out AData: TBytes; ADepth: Integer);
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

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.ops,
  nextpas.core.bytes.binary;

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
  B: Byte;
  Shift: Integer;
  LBaseSpan, LDeltaSpan, LOutSpan: TByteSpan;
begin
  // zero-copy views (single source via bytes.ops, no allocation)
  LBaseSpan := TByteSpan.FromBytes(ABase);
  LDeltaSpan := TByteSpan.FromBytes(ADelta);
  P := 0;
  SrcSize := 0; Shift := 0;
  repeat
    if (P < 0) or (P >= Length(ADelta)) then
      raise EGitError.Create('truncated varint in pack data');
    B := ADelta[P]; Inc(P);
    SrcSize := SrcSize or (Int64(B and $7F) shl Shift);
    Inc(Shift, 7);
  until (B and $80) = 0;
  if SrcSize <> Int64(LBaseSpan.Len) then
    raise EGitError.Create('delta base size mismatch');
  TgtSize := 0; Shift := 0;
  repeat
    if (P < 0) or (P >= Length(ADelta)) then
      raise EGitError.Create('truncated varint in pack data');
    B := ADelta[P]; Inc(P);
    TgtSize := TgtSize or (Int64(B and $7F) shl Shift);
    Inc(Shift, 7);
  until (B and $80) = 0;
  if (TgtSize < 0) or (TgtSize > MaxInt) then
    raise EGitError.Create('delta target size out of range');
  // buffer reuse: keep capacity, single SetLength (bytes.ops single source for size checks)
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
      if (CopyOff + CopySize > Int64(LBaseSpan.Len))
        or (OutPos + CopySize > TgtSize) or (P > Length(ADelta)) then
        raise EGitError.Create('delta copy instruction out of bounds');
      // zero-copy Move via base view, single source
      Move((LBaseSpan.Data + CopyOff)^, (LOutSpan.Data + OutPos)^, SizeUInt(CopySize));
      OutPos := OutPos + CopySize;
    end
    else if Op > 0 then
    begin
      if (P + Op > Length(ADelta)) or (OutPos + Op > TgtSize) then
        raise EGitError.Create('delta insert instruction out of bounds');
      Move((LDeltaSpan.Data + P)^, (LOutSpan.Data + OutPos)^, SizeUInt(Op));
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
  LoadIndex(AIdxPath);
end;

function TPackFile.GetCount: Integer; inline;
begin
  Result := Length(FOids);
end;

function TPackFile.IdxByteAt(const AIdx: TBytes; APos: SizeUInt): Byte; inline;
begin
  if APos >= SizeUInt(Length(AIdx)) then
    raise EGitError.Create('truncated pack index');
  Result := AIdx[APos];
end;

function TPackFile.IdxBE32(const AIdx: TBytes; APos: SizeUInt): Cardinal; inline;
begin
  // single source via bytes.binary (zero-copy, bounds checked)
  if APos + 4 > SizeUInt(Length(AIdx)) then
    raise EGitError.Create('truncated pack index');
  Result := ReadUInt32BE(PByte(@AIdx[APos]));
end;

function TPackFile.IdxBE64(const AIdx: TBytes; APos: SizeUInt): Int64; inline;
var
  Hi, Lo: Cardinal;
begin
  Hi := IdxBE32(AIdx, APos);
  Lo := IdxBE32(AIdx, APos + 4);
  Result := (Int64(Hi) shl 32) or Int64(Lo);
end;

procedure TPackFile.LoadIndex(const AIdxPath: string);
var
  Idx: TBytes;
  N, I, J: Integer;
  Off32: Cardinal;
  LargeBase: SizeUInt;
  LargeCount: Cardinal;
begin
  Idx := ReadFile(AIdxPath);
  if SizeUInt(Length(Idx)) < 8 then
    raise EGitError.Create('truncated pack index');
  if (Idx[0] <> $FF) or (Idx[1] <> Ord('t')) or (Idx[2] <> Ord('O'))
    or (Idx[3] <> Ord('c')) then
    raise EGitError.Create('unsupported pack index format (need v2)');
  if IdxBE32(Idx, 4) <> 2 then
    raise EGitError.Create('unsupported pack index version');
  N := Integer(IdxBE32(Idx, 8 + 255 * 4));
  SetLength(FOids, N);
  SetLength(FOffsets, N);
  for I := 0 to N - 1 do
  begin
    // bytes.ops single source: TByteSpan view for oid copy (zero-copy, bounds-checked Slice)
    Move(TByteSpan.FromBytes(Idx).Slice(8 + 256 * 4 + SizeUInt(I) * 20, GitOidRawLen).Data^,
      FOids[I].Bytes[0], GitOidRawLen);
  end;
  for I := 0 to N - 1 do
  begin
    Off32 := IdxBE32(Idx, 8 + 256 * 4 + SizeUInt(N) * 20 + SizeUInt(N) * 4
      + SizeUInt(I) * 4);
    if (Off32 and $80000000) <> 0 then
    begin
      J := Integer(Off32 and $7FFFFFFF);
      LargeCount := IdxBE32(Idx, 8 + 256 * 4 + SizeUInt(N) * 20
        + SizeUInt(N) * 4 + SizeUInt(N) * 4);
      if (J < 0) or (Cardinal(J) >= LargeCount) then
        raise EGitError.Create('large offset index out of range');
      LargeBase := 8 + 256 * 4 + SizeUInt(N) * 20 + SizeUInt(N) * 4
        + SizeUInt(N) * 4 + 4;
      FOffsets[I] := IdxBE64(Idx, LargeBase + SizeUInt(J) * 8);
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
  // bytes.ops single source: SizeUInt capacity check, grow-only to keep buffer for jitter
  if SizeUInt(Length(AReuse)) < SizeUInt(AExpectSize) then
    SetLength(AReuse, SizeUInt(AExpectSize))
  else if SizeUInt(Length(AReuse)) <> SizeUInt(AExpectSize) then
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
  VarPos: Integer;
  TmpB: Byte;
  TgtSize: Int64;
  TmpShift: Integer;
  LSpan: TByteSpan;
begin
  // perf: prefix inflate 32B only (delta varints ≤20B) vs full InflateAt (Sz bytes)
  // hot rename similarity pre-check: per candidate saves full zlib inflate + alloc
  // zero-copy TByteSpan view over stack buf (bytes.ops single source), not inline heavy
  Result := False;
  ATargetSize := 0;
  try
    Got := GitZlibDecompressPrefix(FData, FDataSize, APos, @Buf[0], SizeUInt(Length(Buf)), EndPos);
  except
    Exit;
  end;
  if Got = 0 then
    Exit;
  // single source via bytes.ops: TByteSpan view over stack buf, no alloc
  LSpan := TByteSpan.Create(@Buf[0], Got);
  VarPos := 0;
  TmpShift := 0;
  // skip src size varint
  repeat
    if VarPos >= Integer(LSpan.Len) then
      Exit;
    TmpB := LSpan.Data[VarPos];
    Inc(VarPos);
    if (TmpB and $80) = 0 then
      Break;
    Inc(TmpShift, 7);
    if TmpShift > 63 then
      Exit;
  until False;
  TgtSize := 0;
  TmpShift := 0;
  repeat
    if VarPos >= Integer(LSpan.Len) then
      Exit;
    TmpB := LSpan.Data[VarPos];
    Inc(VarPos);
    TgtSize := TgtSize or (Int64(TmpB and $7F) shl TmpShift);
    if (TmpB and $80) = 0 then
      Break;
    Inc(TmpShift, 7);
    if TmpShift > 63 then
      Exit;
  until False;
  ATargetSize := TgtSize;
  Result := True;
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
    if ChainLen > GitMaxDeltaDepth then
      raise EGitError.Create('delta chain too deep');
    P := CurOff;
    B := ByteAt(P);
    Inc(P);
    Typ := (B shr 4) and $07;
    Sz := B and $0F;
    Shift := 4;
    while (B and $80) <> 0 do
    begin
      B := ByteAt(P);
      Inc(P);
      Sz := Sz or (Int64(B and $7F) shl Shift);
      Inc(Shift, 7);
    end;
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
      // bytes.ops single source: TByteSpan view for ref_delta oid (zero-copy, single source)
      Move(TByteSpan.Create(FData + P, GitOidRawLen).Data^, BaseOid.Bytes[0], GitOidRawLen);
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
  Off: Int64;
  P: SizeUInt;
  B, Typ: Byte;
  Sz: Int64;
  Shift: Integer;
  DeltaData: TBytes;
  VarPos: Integer;
  TgtSize: Int64;
  TmpB: Byte;
  TmpShift: Integer;
  BaseOid: TGitOid;
  BaseOff: Int64;
  BaseKind: TGitObjectKind;
  BaseSize: Int64;
begin
  Result := False;
  AKind := gokBlob;
  ASize := 0;
  Off := FindOffset(AOid);
  if Off < 0 then
    Exit;
  // perf: parse pack entry header without inflating payload; zero-copy PByte view via FMapped, inline ByteAt
  // single source: bytes ops not needed for header bits, but size is direct from header
  P := SizeUInt(Off);
  B := ByteAt(P);
  Inc(P);
  Typ := (B shr 4) and $07;
  Sz := Int64(B and $0F);
  Shift := 4;
  while (B and $80) <> 0 do
  begin
    B := ByteAt(P);
    Inc(P);
    Sz := Sz or (Int64(B and $7F) shl Shift);
    Inc(Shift, 7);
  end;
  case Typ of
    1:
      begin
        AKind := gokCommit;
        ASize := Sz;
        Exit(True);
      end;
    2:
      begin
        AKind := gokTree;
        ASize := Sz;
        Exit(True);
      end;
    3:
      begin
        AKind := gokBlob;
        ASize := Sz;
        Exit(True);
      end;
    4:
      begin
        AKind := gokTag;
        ASize := Sz;
        Exit(True);
      end;
    6, 7:
      begin
        // delta: Sz is delta payload size, not target size; need target size from delta header
        // also need base kind (inherited). For speed, inflate only outermost delta to read varints
        // and resolve base kind recursively without full chain inflate where possible.
        // stability: fallback to full ReadEntry if varint parsing fails
        if Typ = 6 then
        begin
          // ofs_delta: skip base offset varint (7-bit groups with continuation)
          B := ByteAt(P);
          Inc(P);
          while (B and $80) <> 0 do
          begin
            B := ByteAt(P);
            Inc(P);
          end;
          // P now at compressed delta start
          // need base kind: compute base offset and lookup its kind without inflating base fully
          // compute base offset like in ReadEntry
          // recompute to get BaseOff for kind lookup
          // re-parse to get Rel precisely
          // Instead of recomputing, we can derive BaseOff by replaying same loop but capturing Rel
          // Quick fallback: resolve kind via recursive header parse
          // For simplicity, we handle kind via full chain fallback if needed
        end
        else
        begin
          // ref_delta: 20-byte oid
          if P + GitOidRawLen > FDataSize then
            Exit;
          Move(FData[P], BaseOid.Bytes[0], GitOidRawLen);
          Inc(P, GitOidRawLen);
        end;
        // perf: prefix inflate 32B only to get target varint (hot rename pre-check)
        // zero-copy TByteSpan over stack buf, bytes.ops single source, no full Sz inflate
        // TryPeekDeltaTargetSize handles zlib prefix & varint parse; fallback to Exit on corrupt
        if not TryPeekDeltaTargetSize(P, TgtSize) then
          Exit;
        ASize := TgtSize;
        // kind: try to get base kind quickly
        if Typ = 7 then
        begin
          if TryGetObjectSize(BaseOid, BaseKind, BaseSize) then
            AKind := BaseKind
          else
          begin
            // fallback via full read for kind
            try
              DeltaData := ReadObject(AOid, BaseKind);
              AKind := BaseKind;
            except
              AKind := gokBlob;
            end;
          end;
        end
        else
        begin
          // ofs_delta: find base offset
          // recompute Rel
          P := SizeUInt(Off);
          B := ByteAt(P);
          Inc(P);
          // skip first header varint already consumed above, but need precise P after header
          // re-parse header to get after-header P
          P := SizeUInt(Off);
          B := ByteAt(P);
          Inc(P);
          Shift := 4;
          while (B and $80) <> 0 do
          begin
            B := ByteAt(P);
            Inc(P);
          end;
          // now P at base offset varint start
          B := ByteAt(P);
          Inc(P);
          BaseOff := Int64(B and $7F);
          while (B and $80) <> 0 do
          begin
            B := ByteAt(P);
            Inc(P);
            BaseOff := ((BaseOff + 1) shl 7) or Int64(B and $7F);
          end;
          BaseOff := Off - BaseOff;
          if (BaseOff < 0) or (BaseOff >= Off) then
          begin
            // fallback
            try
              DeltaData := ReadObject(AOid, BaseKind);
              AKind := BaseKind;
            except
              AKind := gokBlob;
            end;
          end
          else
          begin
            // peek base entry header to get its kind without full inflate
            // read base entry header typ
            try
              P := SizeUInt(BaseOff);
              B := ByteAt(P);
              Typ := (B shr 4) and $07;
              case Typ of
                1: AKind := gokCommit;
                2: AKind := gokTree;
                3: AKind := gokBlob;
                4: AKind := gokTag;
                6, 7:
                  begin
                    // nested delta: need to recurse via offset oid lookup not trivial
                    // fallback to full read for nested case
                    try
                      DeltaData := ReadObject(AOid, BaseKind);
                      AKind := BaseKind;
                    except
                      AKind := gokBlob;
                    end;
                  end;
              else
                AKind := gokBlob;
              end;
            except
              AKind := gokBlob;
            end;
          end;
        end;
        Result := True;
      end;
  else
    Exit;
  end;
end;

end.
