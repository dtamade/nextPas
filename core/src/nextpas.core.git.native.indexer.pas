unit nextpas.core.git.native.indexer;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.exception,
  nextpas.core.base,
  nextpas.core.fs,
  nextpas.core.git.native.base;

{ Pack indexer — builds .idx v2 from a .pack file.

  Pure-Pascal counterpart of libgit2 `indexer.c` + `pack.c` index writing
  (`git index-pack` / `git verify-pack` semantics).

  Input is a complete pack file including its 20-byte SHA-1 trailer.
  The builder:

  - validates the PACK header (`PACK` + version 2 + object count)
  - sequentially scans pack entries:
      header varint (type + size), OFS_DELTA negative offset or
      REF_DELTA 20-byte base oid, then zlib payload
    CRC-32 is computed over the raw pack bytes of each entry
    (header + base descriptor + compressed payload) exactly as
    `crc32(crc, ptr, len)` in libgit2
  - resolves deltas (OFS always points backwards, REF by oid) using
    the already-resolved prefix of the pack; thin packs referencing
    external objects are rejected
  - hashes each resolved object (`<kind> <size>\0<payload>`) to obtain
    its oid (via `GitHashObject`)
  - sorts entries by oid, builds the 256-entry fanout table, and
    serializes the idx v2 layout:
      magic `FF 't' 'O' 'c'` + version 2 + fanout + oid table (sorted)
      + CRC table (BE) + offset table (BE, 0x80000000 → large table)
      + large-offset table (BE64) + pack checksum + idx checksum (SHA-1)

  Large offsets (>= $80000000) spill into the 64-bit table; test packs
  are tiny so this path is implemented but not exercised by the current
  golden fixtures. Thin packs are rejected with `EGitError`.

  Golden oracle: byte-exact comparison against `git index-pack` output
  and `git verify-pack -v` must read the index via `TPackFile`. }

function GitBuildPackIndex(const APackData: TBytes): TBytes;
function GitBuildPackIndexFile(const APackPath: string): string;
function GitPackIndexPath(const APackPath: string): string; inline;

implementation

uses
  nextpas.core.hash.sha1,
  nextpas.core.hash.intf,
  nextpas.core.checksum.crc32,
  nextpas.core.git.native.zlib,
  nextpas.core.git.native.loose,
  nextpas.core.git.native.pack;

type
  TIdxRaw = record
    Oid: TGitOid;
    Crc: LongWord;
    Offset: Int64;
    Kind: TGitObjectKind;
    Data: TBytes;
  end;
  TIdxRawArray = array of TIdxRaw;

function BE32(const B: TBytes; APos: SizeInt): Cardinal; inline;
begin
  Result := (Cardinal(B[APos]) shl 24) or (Cardinal(B[APos+1]) shl 16)
    or (Cardinal(B[APos+2]) shl 8) or Cardinal(B[APos+3]);
end;

procedure WriteBE32(var ADst: TBytes; var APos: SizeInt; AVal: Cardinal); inline;
begin
  ADst[APos] := Byte(AVal shr 24);
  ADst[APos+1] := Byte(AVal shr 16);
  ADst[APos+2] := Byte(AVal shr 8);
  ADst[APos+3] := Byte(AVal);
  Inc(APos, 4);
end;

procedure WriteBE64(var ADst: TBytes; var APos: SizeInt; AVal: Int64); inline;
begin
  WriteBE32(ADst, APos, Cardinal((AVal shr 32) and $FFFFFFFF));
  WriteBE32(ADst, APos, Cardinal(AVal and $FFFFFFFF));
end;

function OidCompare(const AA, AB: TGitOid): Integer;
var
  I: Integer;
begin
  for I := 0 to GitOidRawLen - 1 do
  begin
    if AA.Bytes[I] < AB.Bytes[I] then Exit(-1);
    if AA.Bytes[I] > AB.Bytes[I] then Exit(1);
  end;
  Result := 0;
end;

procedure SortIdx(var A: TIdxRawArray);
  procedure QuickSort(L, R: Integer);
  var
    I, J: Integer;
    Pivot, Tmp: TIdxRaw;
  begin
    I := L; J := R;
    Pivot := A[(L+R) div 2];
    repeat
      while OidCompare(A[I].Oid, Pivot.Oid) < 0 do Inc(I);
      while OidCompare(A[J].Oid, Pivot.Oid) > 0 do Dec(J);
      if I <= J then
      begin
        Tmp := A[I]; A[I] := A[J]; A[J] := Tmp;
        Inc(I); Dec(J);
      end;
    until I > J;
    if L < J then QuickSort(L, J);
    if I < R then QuickSort(I, R);
  end;
begin
  if Length(A) > 1 then QuickSort(0, High(A));
end;

function FindByOffset(const A: TIdxRawArray; AOff: Int64): Integer;
var
  I: Integer;
begin
  for I := 0 to High(A) do
    if A[I].Offset = AOff then Exit(I);
  Result := -1;
end;

function FindByOid(const A: TIdxRawArray; const AOid: TGitOid): Integer;
var
  I: Integer;
begin
  for I := 0 to High(A) do
    if GitOidSame(A[I].Oid, AOid) then Exit(I);
  Result := -1;
end;

function KindFromPackType(ATyp: Byte): TGitObjectKind;
begin
  case ATyp of
    1: Result := gokCommit;
    2: Result := gokTree;
    3: Result := gokBlob;
    4: Result := gokTag;
  else
    raise EGitError.CreateFmt('unknown pack type %d', [ATyp]);
  end;
end;

function GitBuildPackIndex(const APackData: TBytes): TBytes;
var
  N: Cardinal;
  Pos: SizeInt;
  I: Integer;
  Raw: TIdxRawArray;
  B: Byte;
  Typ: Byte;
  Sz: Int64;
  Shift: Integer;
  BaseOff: Int64;
  BaseOid: TGitOid;
  BaseOidValid: Boolean;
  Rel: Int64;
  ZStart, ZEnd: SizeUInt;
  Decompressed, BaseData, ResolvedData, Delta: TBytes;
  Kind: TGitObjectKind;
  Oid: TGitOid;
  Crc: LongWord;
  EntryStart: SizeInt;
  Idx: Integer;
  Fanout: array[0..255] of Cardinal;
  Counts: array[0..255] of Cardinal;
  LargeCount: Integer;
  TotalSize: SizeInt;
  OutPos: SizeInt;
  PackHash: TBytes;
  H: IHasher;
  Sum: TBytes;
begin
  Result := nil;
  if Length(APackData) < 12 + GitOidRawLen then
    raise EGitError.Create('truncated pack file');
  if (APackData[0] <> Ord('P')) or (APackData[1] <> Ord('A'))
    or (APackData[2] <> Ord('C')) or (APackData[3] <> Ord('K')) then
    raise EGitError.Create('wrong pack signature');
  if BE32(APackData, 4) <> 2 then
    raise EGitError.Create('unsupported pack version (need v2)');
  N := BE32(APackData, 8);
  SetLength(Raw, 0);
  Pos := 12;
  for I := 0 to Integer(N) - 1 do
  begin
    if Pos >= Length(APackData) - GitOidRawLen then
      raise EGitError.Create('truncated pack entry header');
    EntryStart := Pos;
    B := APackData[Pos]; Inc(Pos);
    Typ := (B shr 4) and $07;
    Sz := B and $0F;
    Shift := 4;
    while (B and $80) <> 0 do
    begin
      if Pos >= Length(APackData) then
        raise EGitError.Create('truncated pack entry size');
      B := APackData[Pos]; Inc(Pos);
      Sz := Sz or (Int64(B and $7F) shl Shift);
      Inc(Shift, 7);
      if Shift > 60 then
        raise EGitError.Create('pack entry size overflow');
    end;
    BaseOff := -1;
    BaseOidValid := False;
    if Typ = 6 then
    begin
      if Pos >= Length(APackData) then
        raise EGitError.Create('truncated ofs_delta base');
      B := APackData[Pos]; Inc(Pos);
      Rel := B and $7F;
      while (B and $80) <> 0 do
      begin
        if Pos >= Length(APackData) then
          raise EGitError.Create('truncated ofs_delta base');
        B := APackData[Pos]; Inc(Pos);
        Rel := ((Rel + 1) shl 7) or (B and $7F);
      end;
      BaseOff := Int64(EntryStart) - Rel;
      if (BaseOff < 0) or (BaseOff >= EntryStart) then
        raise EGitError.Create('corrupt ofs_delta base offset');
    end
    else if Typ = 7 then
    begin
      if Pos + GitOidRawLen > Length(APackData) then
        raise EGitError.Create('truncated ref_delta base');
      Move(APackData[Pos], BaseOid.Bytes[0], GitOidRawLen);
      Inc(Pos, GitOidRawLen);
      BaseOidValid := True;
    end
    else if not (Typ in [1..4]) then
      raise EGitError.CreateFmt('unknown pack entry type %d', [Typ]);

    ZStart := SizeUInt(Pos);
    // decompress one zlib stream
    try
      Decompressed := GitZlibDecompress(APackData, ZStart, ZEnd);
    except
      on E: Exception do
        raise EGitError.Create('corrupt pack zlib stream: ' + E.Message);
    end;
    if Int64(Length(Decompressed)) <> Sz then
      raise EGitError.Create('pack entry inflated size mismatch');
    if ZEnd <= ZStart then
      raise EGitError.Create('pack entry zlib produced no bytes');
    Pos := SizeInt(ZEnd);
    // CRC over raw pack bytes [EntryStart, Pos)
    Crc := Crc32Update(0, @APackData[EntryStart], SizeUInt(Pos - EntryStart));
    // resolve oid
    if Typ in [1..4] then
    begin
      Kind := KindFromPackType(Typ);
      Oid := GitHashObject(Kind, Decompressed);
    end
    else if Typ = 6 then
    begin
      Idx := FindByOffset(Raw, BaseOff);
      if Idx < 0 then
        raise EGitError.CreateFmt('ofs_delta base %d not found', [BaseOff]);
      BaseData := Raw[Idx].Data;
      Kind := Raw[Idx].Kind;
      Delta := Decompressed;
      ResolvedData := GitApplyDelta(BaseData, Delta);
      Oid := GitHashObject(Kind, ResolvedData);
      Decompressed := ResolvedData;
    end
    else // Typ=7
    begin
      Idx := FindByOid(Raw, BaseOid);
      if Idx < 0 then
        raise EGitError.CreateFmt('ref_delta base %s not found', [GitOidToHex(BaseOid)]);
      BaseData := Raw[Idx].Data;
      Kind := Raw[Idx].Kind;
      Delta := Decompressed;
      ResolvedData := GitApplyDelta(BaseData, Delta);
      Oid := GitHashObject(Kind, ResolvedData);
      Decompressed := ResolvedData;
      BaseOidValid := BaseOidValid; // suppress hint
    end;
    SetLength(Raw, Length(Raw)+1);
    Raw[High(Raw)].Oid := Oid;
    Raw[High(Raw)].Crc := Crc;
    Raw[High(Raw)].Offset := EntryStart;
    Raw[High(Raw)].Kind := Kind;
    Raw[High(Raw)].Data := Decompressed;
  end;
  if Pos <> Length(APackData) - GitOidRawLen then
    raise EGitError.CreateFmt('pack has %d trailing bytes before trailer', [Length(APackData) - GitOidRawLen - Pos]);
  // verify pack trailer
  SetLength(PackHash, GitOidRawLen);
  Move(APackData[Length(APackData)-GitOidRawLen], PackHash[0], GitOidRawLen);
  H := NewSHA1;
  H.Write(APackData[0], SizeUInt(Length(APackData)-GitOidRawLen));
  Sum := H.SumBytes;
  for I := 0 to GitOidRawLen - 1 do
    if Sum[I] <> PackHash[I] then
      raise EGitError.Create('pack trailer mismatch (SHA-1)');
  if Length(Raw) <> Integer(N) then
    raise EGitError.Create('pack object count mismatch');
  // sort by oid
  SortIdx(Raw);
  // fanout
  for I := 0 to 255 do Counts[I] := 0;
  for I := 0 to High(Raw) do Inc(Counts[Raw[I].Oid.Bytes[0]]);
  Fanout[0] := Counts[0];
  for I := 1 to 255 do Fanout[I] := Fanout[I-1] + Counts[I];
  if Fanout[255] <> N then
    raise EGitError.Create('fanout count mismatch');
  // count large offsets
  LargeCount := 0;
  for I := 0 to High(Raw) do
    if Raw[I].Offset >= $80000000 then Inc(LargeCount);
  TotalSize := 8 + 256*4 + Integer(N)*20 + Integer(N)*4 + Integer(N)*4 + LargeCount*8 + GitOidRawLen + GitOidRawLen;
  SetLength(Result, TotalSize);
  OutPos := 0;
  // magic
  Result[OutPos] := $FF; Inc(OutPos);
  Result[OutPos] := Ord('t'); Inc(OutPos);
  Result[OutPos] := Ord('O'); Inc(OutPos);
  Result[OutPos] := Ord('c'); Inc(OutPos);
  WriteBE32(Result, OutPos, 2);
  for I := 0 to 255 do WriteBE32(Result, OutPos, Fanout[I]);
  for I := 0 to High(Raw) do
  begin
    Move(Raw[I].Oid.Bytes[0], Result[OutPos], GitOidRawLen);
    Inc(OutPos, GitOidRawLen);
  end;
  for I := 0 to High(Raw) do WriteBE32(Result, OutPos, Raw[I].Crc);
  // offset table
  LargeCount := 0;
  for I := 0 to High(Raw) do
  begin
    if Raw[I].Offset >= $80000000 then
    begin
      WriteBE32(Result, OutPos, Cardinal($80000000 or LargeCount));
      Inc(LargeCount);
    end
    else
      WriteBE32(Result, OutPos, Cardinal(Raw[I].Offset));
  end;
  // large offsets
  for I := 0 to High(Raw) do
    if Raw[I].Offset >= $80000000 then WriteBE64(Result, OutPos, Raw[I].Offset);
  // pack checksum
  Move(PackHash[0], Result[OutPos], GitOidRawLen);
  Inc(OutPos, GitOidRawLen);
  // idx checksum
  H := NewSHA1;
  H.Write(Result[0], SizeUInt(TotalSize - GitOidRawLen));
  Sum := H.SumBytes;
  Move(Sum[0], Result[OutPos], GitOidRawLen);
  // OutPos should be TotalSize
end;

function GitPackIndexPath(const APackPath: string): string;
var
  L: Integer;
begin
  L := Length(APackPath);
  if (L >= 5) and (APackPath[L-4] = '.') then
  begin
    // case-insensitive ".pack"
    if ((APackPath[L-3] = 'p') or (APackPath[L-3] = 'P'))
      and ((APackPath[L-2] = 'a') or (APackPath[L-2] = 'A'))
      and ((APackPath[L-1] = 'c') or (APackPath[L-1] = 'C'))
      and ((APackPath[L] = 'k') or (APackPath[L] = 'K')) then
      Exit(Copy(APackPath, 1, L-5) + '.idx');
  end;
  Result := APackPath + '.idx';
end;

function GitBuildPackIndexFile(const APackPath: string): string;
var
  PackData, IdxData: TBytes;
begin
  PackData := ReadFile(APackPath);
  IdxData := GitBuildPackIndex(PackData);
  Result := GitPackIndexPath(APackPath);
  WriteAtomic(Result, IdxData);
end;

end.
