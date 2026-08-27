unit nextpas.core.respack.reader;

{** @desc respack 解析器：八步校验清单 + 索引二分查找。
  校验步骤号对应 FORMAT.md「Reader 校验清单」；不变量见 CONTRACT INV-R2/R3/R4/R7。
  string table 边界为推导值：基址 = IndexOffset+Count×40，上界 = min(DataOffset)。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base;

type
  TResPack = record
  private
    FData: PByte;
    FSize: SizeUInt;
    FOpen: Boolean;
    FHdr: TResPackHeader;
    FStrTabBase: UInt64;
    FDigests: PByte;

    function GetCount: SizeUInt; inline;
    { 40 字节 index 项 → host-order TResPackEntry。
      不用无类型参数 + absolute 叠加：FPC trunk 对该组合生成错误代码（实测）。 }
    procedure DecodeWire(const AIdx: SizeUInt; out ADest: TResPackEntry);
    function StoredPathRange(const AIdx: SizeUInt; out AP: PByte)
      : SizeUInt; inline;
    function CompareStoredToBuf(const AIdx: SizeUInt;
      const ABuf: PByte; const ALen: SizeUInt): Integer;
    function CompareStoredToStored(const AA, AB: SizeUInt): Integer;
    function CompareCachedEntries(const AA, AB: TResPackEntry): Integer;
    function Search(const APath: string; out AIdx: SizeUInt): Boolean;

  public
    { 八步校验后可用；任一失败 raise EResPackCorrupted }
    class function Open(const AData: PByte; const ASize: SizeUInt): TResPack; static;
    procedure Close;

    { 探测式查找：未命中 False；命中时 Result.Path 构造一次 }
    function Find(const APath: string; out AEntry: TResPackEntry): Boolean;
    { 断言式查找：未命中 raise EResPackNotFound }
    function Stat(const APath: string): TResPackEntry;

    function EntryAt(const AIdx: SizeUInt): TResPackEntry;
    function PathOf(const AEntry: TResPackEntry): string;
    function StoredPathRangeOf(const AEntry: TResPackEntry;
      out AP: PByte): SizeUInt;

    property Count: SizeUInt read GetCount;
    property Header: TResPackHeader read FHdr;
    property Data: PByte read FData;
    function ContentPtr(const AEntry: TResPackEntry): PByte; inline;
    function DigestPtr(const AIdx: SizeUInt): PByte;
    function HasDigests: Boolean; inline;
  end;

implementation

function TResPack.GetCount: SizeUInt;
begin
  Result := SizeUInt(FHdr.EntryCount);
end;

function TResPack.HasDigests: Boolean;
begin
  Result := FDigests <> nil;
end;

function TResPack.ContentPtr(const AEntry: TResPackEntry): PByte;
begin
  Result := FData + SizeUInt(AEntry.DataOffset);
end;

function TResPack.DigestPtr(const AIdx: SizeUInt): PByte;
begin
  if FDigests = nil then
    raise EResPackCorrupted.Create('respack: pack has no digest section');
  Result := FDigests + AIdx * RESPACK_DIGEST_SIZE;
end;

procedure TResPack.DecodeWire(const AIdx: SizeUInt; out ADest: TResPackEntry);
var
  P: PByte;
begin
  P := FData + SizeUInt(FHdr.IndexOffset) + AIdx * RESPACK_ENTRY_SIZE;
  ADest.PathOffset := RdU32LE(P);
  ADest.PathLen := RdU16LE(P + 4);
  ADest.Flags := RdU16LE(P + 6);
  ADest.DataOffset := RdU64LE(P + 8);
  ADest.Size := RdU64LE(P + 16);
  ADest.ModTime := Int64(RdU64LE(P + 24));
  ADest.Hash := RdU32LE(P + 32);
  ADest.CodecId := P[36];
end;

function TResPack.StoredPathRange(const AIdx: SizeUInt; out AP: PByte)
  : SizeUInt;
var
  Base: PByte;
begin
  Base := FData + SizeUInt(FHdr.IndexOffset) + AIdx * RESPACK_ENTRY_SIZE;
  AP := FData + SizeUInt(FStrTabBase) + SizeUInt(RdU32LE(Base));
  Result := SizeUInt(RdU16LE(Base + 4));
end;

function TResPack.CompareStoredToBuf(const AIdx: SizeUInt;
  const ABuf: PByte; const ALen: SizeUInt): Integer;
var
  P: PByte;
  L, N, I: SizeUInt;
begin
  L := StoredPathRange(AIdx, P);
  N := L;
  if ALen < N then
    N := ALen;
  I := 0;
  while I < N do
  begin
    if P[I] < ABuf[I] then
      Exit(-1);
    if P[I] > ABuf[I] then
      Exit(1);
    Inc(I);
  end;
  if L < ALen then
    Exit(-1);
  if L > ALen then
    Exit(1);
  Result := 0;
end;

function TResPack.CompareStoredToStored(const AA, AB: SizeUInt): Integer;
var
  PA, PB: PByte;
  LA, LB, N, I: SizeUInt;
begin
  LA := StoredPathRange(AA, PA);
  LB := StoredPathRange(AB, PB);
  N := LA;
  if LB < N then
    N := LB;
  I := 0;
  while I < N do
  begin
    if PA[I] < PB[I] then
      Exit(-1);
    if PA[I] > PB[I] then
      Exit(1);
    Inc(I);
  end;
  if LA < LB then
    Exit(-1);
  if LA > LB then
    Exit(1);
  Result := 0;
end;

function TResPack.CompareCachedEntries(const AA, AB: TResPackEntry): Integer;
var
  PA, PB: PByte;
  LA, LB, N, I: SizeUInt;
begin
  PA := FData + SizeUInt(FStrTabBase) + AA.PathOffset;
  PB := FData + SizeUInt(FStrTabBase) + AB.PathOffset;
  LA := AA.PathLen;
  LB := AB.PathLen;
  N := LA;
  if LB < N then N := LB;
  I := 0;
  while I < N do
  begin
    if PA[I] < PB[I] then Exit(-1);
    if PA[I] > PB[I] then Exit(1);
    Inc(I);
  end;
  if LA < LB then Exit(-1);
  if LA > LB then Exit(1);
  Result := 0;
end;

class function TResPack.Open(const AData: PByte; const ASize: SizeUInt): TResPack;
var
  I: SizeUInt;
  E: TResPackEntry;
  MinData, DigEnd: UInt64;
  HdrFlags: UInt32;
  IdxBase: PByte;
  Cached: array of TResPackEntry;
begin
  Result.Close;

  { 步骤 1：长度与 magic }
  if (AData = nil) or (ASize < RESPACK_HEADER_SIZE) then
    raise EResPackCorrupted.CreateStep(1, 'buffer smaller than header');
  if (AData[0] <> Byte(AnsiChar('N'))) or (AData[1] <> Byte(AnsiChar('P')))
    or (AData[2] <> Byte(AnsiChar('R'))) or (AData[3] <> Byte(AnsiChar('S'))) then
    raise EResPackCorrupted.CreateStep(1, 'bad magic');

  { 步骤 2：版本与 header flags }
  Result.FHdr.Version := RdU32LE(AData + 4);
  if Result.FHdr.Version <> RESPACK_VERSION then
    raise EResPackCorrupted.CreateStep(2, 'unsupported version');
  HdrFlags := RdU32LE(AData + 8);
  if (HdrFlags and not UInt32(RESPACK_FLAG_KNOWN)) <> 0 then
    raise EResPackCorrupted.CreateStep(2, 'unknown header flags');
  Result.FHdr.Flags := HdrFlags;
  Result.FHdr.EntryCount := RdU32LE(AData + 12);
  Result.FHdr.IndexOffset := RdU64LE(AData + 16);
  Result.FHdr.DigestOffset := RdU64LE(AData + 24);
  Result.FHdr.BlobTotal := RdU64LE(AData + 32);
  if ((HdrFlags and RESPACK_FLAG_DIGESTED) <> 0)
    and (Result.FHdr.DigestOffset = 0) then
    raise EResPackCorrupted.CreateStep(2, 'digest flag set but offset zero');

  { 步骤 3：index 范围（u32×40 在 u64 内无溢出） }
  if (Result.FHdr.IndexOffset < RESPACK_HEADER_SIZE)
    or (Result.FHdr.IndexOffset
      + UInt64(Result.FHdr.EntryCount) * RESPACK_ENTRY_SIZE
      > Result.FHdr.BlobTotal) then
    raise EResPackCorrupted.CreateStep(3, 'index out of range');

  { 步骤 4：缓冲覆盖 blobTotal（允许尾部多余字节） }
  if ASize < Result.FHdr.BlobTotal then
    raise EResPackCorrupted.CreateStep(4, 'buffer truncated versus blobTotal');

  { FData 必须在步骤 5 前就位：后续 DecodeWire/StoredPathRange 全部经由 Self.FData 寻址 }
  Result.FData := AData;
  Result.FSize := ASize;

  Result.FStrTabBase := Result.FHdr.IndexOffset
    + UInt64(Result.FHdr.EntryCount) * RESPACK_ENTRY_SIZE;
  IdxBase := AData + SizeUInt(Result.FHdr.IndexOffset);

  { 步骤 5：entry 结构、codec、data 对齐与范围；同时推导 strtab 上界
    （Count 为 SizeUInt，0-1 回绕 ⇒ 每个循环都必须以 Count>0 为前提）
    单次 DecodeWire + 缓存：第二遍校验复用缓存零 Decode，10k 规模省 50% 解析 }
  MinData := Result.FHdr.BlobTotal;
  if Result.Count > 0 then
  begin
    // 缓存条目避免第二遍二次 DecodeWire
    // Count 受 BlobTotal/40 限制，10k 级分配 < 400KB，可控
    SetLength(Cached, Result.Count);
    for I := 0 to Result.Count - 1 do
    begin
      Result.DecodeWire(I, E);
      if (E.Flags and not Word(RESPACK_EFLAG_KNOWN)) <> 0 then
        raise EResPackCorrupted.CreateStep(5, 'unknown entry flags');
      if (IdxBase[I * RESPACK_ENTRY_SIZE + 37] <> 0)
        or (IdxBase[I * RESPACK_ENTRY_SIZE + 38] <> 0)
        or (IdxBase[I * RESPACK_ENTRY_SIZE + 39] <> 0) then
        raise EResPackCorrupted.CreateStep(5, 'reserved bytes nonzero');
      if E.CodecId <> RESPACK_CODEC_STORE then
        raise EResPackCorrupted.CreateStep(5, 'unknown codecId');
      if E.PathLen = 0 then
        raise EResPackCorrupted.CreateStep(5, 'empty path');
      if (E.DataOffset mod RESPACK_DATA_ALIGN) <> 0 then
        raise EResPackCorrupted.CreateStep(5, 'data slot not aligned');
      if E.DataOffset + E.Size > Result.FHdr.BlobTotal then
        raise EResPackCorrupted.CreateStep(5, 'data range beyond blobTotal');
      if E.DataOffset < MinData then
        MinData := E.DataOffset;
      Cached[I] := E;
    end;
  end;

  { 步骤 6+7：路径范围 + 有序性 + 规范语法 — 复用缓存零 Decode
    （MinData 已在步骤 5 推导完成；步骤 6 优先于 7，错误码保持与分步一致） }
  if Result.Count > 0 then
    for I := 0 to Result.Count - 1 do
    begin
      E := Cached[I];
      if UInt64(E.PathOffset) + UInt64(E.PathLen)
        > MinData - Result.FStrTabBase then
        raise EResPackCorrupted.CreateStep(6, 'path beyond string table bound');
      if I > 0 then
        if Result.CompareCachedEntries(Cached[I - 1], Cached[I]) >= 0 then
          raise EResPackCorrupted.CreateStep(7,
            'index not strictly sorted or duplicate path');
      if not ResPackValidPath(Result.PathOf(E), True) then
        raise EResPackCorrupted.CreateStep(7, 'non-canonical path stored');
    end;
  SetLength(Cached, 0);

  { 步骤 8：digest 区范围 }
  if (Result.FHdr.Flags and RESPACK_FLAG_DIGESTED) <> 0 then
  begin
    if Result.FHdr.DigestOffset < MinData then
      raise EResPackCorrupted.CreateStep(8, 'digest overlaps data section');
    DigEnd := Result.FHdr.DigestOffset
      + UInt64(Result.FHdr.EntryCount) * RESPACK_DIGEST_SIZE;
    if DigEnd > Result.FHdr.BlobTotal then
      raise EResPackCorrupted.CreateStep(8, 'digest out of range');
    Result.FDigests := AData + SizeUInt(Result.FHdr.DigestOffset);
  end;

  Result.FOpen := True;
end;

procedure TResPack.Close;
begin
  FData := nil;
  FSize := 0;
  FDigests := nil;
  FOpen := False;
  FHdr.EntryCount := 0;
  FHdr.IndexOffset := 0;
  FHdr.DigestOffset := 0;
  FHdr.BlobTotal := 0;
  FHdr.Flags := 0;
  FHdr.Version := 0;
  FStrTabBase := 0;
end;

function TResPack.Search(const APath: string; out AIdx: SizeUInt): Boolean;
var
  Lo, Hi, Mid: SizeUInt;
  C: Integer;
begin
  Result := False;
  Lo := 0;
  Hi := Count;
  while Lo < Hi do
  begin
    Mid := Lo + (Hi - Lo) div 2;
    C := CompareStoredToBuf(Mid, Pointer(APath), SizeUInt(Length(APath)));
    if C = 0 then
    begin
      AIdx := Mid;
      Exit(True);
    end;
    if C < 0 then
      Lo := Mid + 1
    else
      Hi := Mid;
  end;
end;

function TResPack.Find(const APath: string; out AEntry: TResPackEntry): Boolean;
var
  Idx: SizeUInt;
begin
  if (not FOpen) or (not ResPackValidPath(APath, True)) then
    Exit(False);
  if not Search(APath, Idx) then
    Exit(False);
  DecodeWire(Idx, AEntry);
  Result := True;
end;

function TResPack.Stat(const APath: string): TResPackEntry;
begin
  if not ResPackValidPath(APath, True) then
    raise EResPackInvalidPath.Create('respack: invalid path "' + APath + '"');
  if not Find(APath, Result) then
    raise EResPackNotFound.Create('respack: path not found "' + APath + '"');
end;

function TResPack.EntryAt(const AIdx: SizeUInt): TResPackEntry;
begin
  if (not FOpen) or (AIdx >= Count) then
    raise EResPackError.Create('respack: entry index out of range');
  DecodeWire(AIdx, Result);
end;

function TResPack.PathOf(const AEntry: TResPackEntry): string;
var
  P: PByte;
  L: SizeUInt;
begin
  L := StoredPathRangeOf(AEntry, P);
  if L = 0 then
    Exit('');
  SetLength(Result, L);
  Move(P^, Result[1], L);
end;

function TResPack.StoredPathRangeOf(const AEntry: TResPackEntry;
  out AP: PByte): SizeUInt;
begin
  AP := FData + SizeUInt(FStrTabBase) + AEntry.PathOffset;
  Result := AEntry.PathLen;
end;

end.
