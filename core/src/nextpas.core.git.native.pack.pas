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
    function GetCount: Integer;
    function IdxByteAt(const AIdx: TBytes; APos: SizeUInt): Byte;
    function IdxBE32(const AIdx: TBytes; APos: SizeUInt): Cardinal;
    function IdxBE64(const AIdx: TBytes; APos: SizeUInt): Int64;
    procedure LoadIndex(const AIdxPath: string);
    function FindOffset(const AOid: TGitOid): Int64;
    function ByteAt(APos: SizeUInt): Byte;
    function InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
    procedure ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
      out AData: TBytes; ADepth: Integer);
  public
    constructor Create(const AIdxPath, APackPath: string);
    function Contains(const AOid: TGitOid): Boolean;
    function ReadObject(const AOid: TGitOid; out AKind: TGitObjectKind): TBytes;
    property Count: Integer read GetCount;
    property PackPath: string read FPackPath;
  end;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;

const
  GitMaxDeltaDepth = 64;

implementation

uses
  nextpas.core.base.utils,
  nextpas.core.bytes.binary;

function GitApplyDelta(const ABase, ADelta: TBytes): TBytes;
var
  P: SizeInt;
  SrcSize, TgtSize, OutPos, CopyOff, CopySize: Int64;
  Op: Byte;
  I: Integer;
  B: Byte;
  Shift: Integer;
begin
  P := 0;
  // inline LE7 varint decode (single source loop, no separate helper)
  SrcSize := 0; Shift := 0;
  repeat
    if (P < 0) or (P >= Length(ADelta)) then
      raise EGitError.Create('truncated varint in pack data');
    B := ADelta[P]; Inc(P);
    SrcSize := SrcSize or (Int64(B and $7F) shl Shift);
    Inc(Shift, 7);
  until (B and $80) = 0;
  if SrcSize <> Length(ABase) then
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
  Result := nil;
  SetLength(Result, TgtSize);
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
      if (CopyOff + CopySize > Length(ABase))
        or (OutPos + CopySize > TgtSize) or (P > Length(ADelta)) then
        raise EGitError.Create('delta copy instruction out of bounds');
      Move(ABase[CopyOff], Result[OutPos], CopySize);
      OutPos := OutPos + CopySize;
    end
    else if Op > 0 then
    begin
      if (P + Op > Length(ADelta)) or (OutPos + Op > TgtSize) then
        raise EGitError.Create('delta insert instruction out of bounds');
      Move(ADelta[P], Result[OutPos], Op);
      OutPos := OutPos + Op;
      Inc(P, Op);
    end
    else
      raise EGitError.Create('invalid delta opcode 0');
  end;
  if OutPos <> TgtSize then
    raise EGitError.Create('delta produced wrong output size');
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

function TPackFile.GetCount: Integer;
begin
  Result := Length(FOids);
end;

function TPackFile.IdxByteAt(const AIdx: TBytes; APos: SizeUInt): Byte;
begin
  if APos >= SizeUInt(Length(AIdx)) then
    raise EGitError.Create('truncated pack index');
  Result := AIdx[APos];
end;

function TPackFile.IdxBE32(const AIdx: TBytes; APos: SizeUInt): Cardinal;
begin
  // single source via bytes.binary (zero-copy, bounds checked)
  if APos + 4 > SizeUInt(Length(AIdx)) then
    raise EGitError.Create('truncated pack index');
  Result := ReadUInt32BE(PByte(@AIdx[APos]));
end;

function TPackFile.IdxBE64(const AIdx: TBytes; APos: SizeUInt): Int64;
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
    Move(Idx[8 + 256 * 4 + SizeUInt(I) * 20], FOids[I].Bytes[0], GitOidRawLen);
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

function TPackFile.ByteAt(APos: SizeUInt): Byte;
begin
  if APos >= FDataSize then
    raise EGitError.Create('truncated packfile');
  Result := FData[APos];
end;

function TPackFile.InflateAt(APos: SizeUInt; AExpectSize: Int64): TBytes;
var
  EndPos: SizeUInt;
begin
  Result := GitZlibDecompressPtr(FData, FDataSize, APos, EndPos);
  if Int64(Length(Result)) <> AExpectSize then
    raise EGitError.Create('pack entry inflated size mismatch');
end;

procedure TPackFile.ReadEntry(AOffset: SizeUInt; out AKind: TGitObjectKind;
  out AData: TBytes; ADepth: Integer);
var
  B: Byte;
  Typ: Byte;
  Sz: Int64;
  Shift: Integer;
  P: SizeUInt;
  Rel: Int64;
  BaseOff: SizeUInt;
  BaseKind: TGitObjectKind;
  BaseData, Delta: TBytes;
  BaseOid: TGitOid;
  BaseOffSigned: Int64;
begin
  if ADepth > GitMaxDeltaDepth then
    raise EGitError.Create('delta chain too deep');
  P := AOffset;
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
  case Typ of
    1..4:
    begin
      case Typ of
        1: AKind := gokCommit;
        2: AKind := gokTree;
        3: AKind := gokBlob;
        4: AKind := gokTag;
      end;
      AData := InflateAt(P, Sz);
    end;
    6:
    begin
      // OFS_DELTA: base located at a negative-encoded relative offset
      B := ByteAt(P);
      Inc(P);
      Rel := B and $7F;
      while (B and $80) <> 0 do
      begin
        B := ByteAt(P);
        Inc(P);
        Rel := ((Rel + 1) shl 7) or (B and $7F);
      end;
      BaseOffSigned := Int64(AOffset) - Rel;
      if (BaseOffSigned < 0) or (BaseOffSigned >= Int64(AOffset)) then
        raise EGitError.Create('corrupt ofs_delta base offset');
      BaseOff := SizeUInt(BaseOffSigned);
      ReadEntry(BaseOff, BaseKind, BaseData, ADepth + 1);
      Delta := InflateAt(P, Sz);
      AData := GitApplyDelta(BaseData, Delta);
      if Int64(Length(AData)) <> Sz then
        raise EGitError.Create('ofs_delta target size mismatch');
      AKind := BaseKind;
    end;
    7:
    begin
      // REF_DELTA: base identified by raw oid stored inline
      if P + GitOidRawLen > FDataSize then
        raise EGitError.Create('truncated ref_delta header');
      Move(FData[P], BaseOid.Bytes[0], GitOidRawLen);
      Inc(P, GitOidRawLen);
      if FindOffset(BaseOid) < 0 then
        raise EGitError.CreateFmt('ref_delta base %s not in same pack',
          [GitOidToHex(BaseOid)]);
      ReadEntry(SizeUInt(FindOffset(BaseOid)), BaseKind, BaseData,
        ADepth + 1);
      Delta := InflateAt(P, Sz);
      AData := GitApplyDelta(BaseData, Delta);
      if Int64(Length(AData)) <> Sz then
        raise EGitError.Create('ref_delta target size mismatch');
      AKind := BaseKind;
    end
  else
    raise EGitError.CreateFmt('unknown pack entry type %d', [Typ]);
  end;
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

end.
