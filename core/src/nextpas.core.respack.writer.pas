unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目列表 → 单个确定性 blob。
  流程见 FORMAT.md「Writer 构造流程」；不变量见 CONTRACT.md INV-R5/R6/R8/R10。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.respack.base;

type
  { 排序后的内部视图，供测试断言布局使用 }
  TResPackLayoutInfo = record
    BlobTotal: UInt64;
    StringTableBase: UInt64;
    FirstDataOffset: UInt64;
  end;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;

implementation

type
  TSlotInfo = record
    Offset: UInt64;
    SrcIdx: SizeUInt;   { 槽位内容来源条目（去重回验基准） }
    Fnv: UInt32;
  end;

{ 字节序路径比较：先比公共前缀逐字节，再比长度 }
function PathByteCompare(const APath: PChar; const AALen: Integer;
  const BOther: string): Integer;
var
  I, MinLen: Integer;
begin
  Result := 0;
  MinLen := AALen;
  if Length(BOther) < MinLen then
    MinLen := Length(BOther);
  for I := 1 to MinLen do
  begin
    if Byte(APath[I - 1]) < Byte(BOther[I]) then
      Exit(-1);
    if Byte(APath[I - 1]) > Byte(BOther[I]) then
      Exit(1);
  end;
  if AALen < Length(BOther) then
    Exit(-1);
  if AALen > Length(BOther) then
    Exit(1);
end;

{ 小区间插入排序：稳定、无递归；quick 在区间 <16 时切换到此。
  注意所有排序下标一律 Int64：Hoare 分区的 R 会越过下界一次，
  无符号类型在此回绕导致越界访问（FPC trunk 实测），有符号则天然安全。 }
procedure InsertionSortPaths(var AOrder: array of SizeUInt;
  const AEntries: array of TResPackInputEntry; ALow, AHigh: Int64);
var
  I, J: Int64;
  Key: SizeUInt;
begin
  I := ALow + 1;
  while I <= AHigh do
  begin
    Key := AOrder[I];
    J := I - 1;
    while (J >= ALow)
      and (PathByteCompare(PChar(AEntries[AOrder[J]].Path),
        Length(AEntries[AOrder[J]].Path), AEntries[Key].Path) > 0) do
    begin
      AOrder[J + 1] := AOrder[J];
      Dec(J);
    end;
    AOrder[J + 1] := Key;
    Inc(I);
  end;
end;

procedure QuickSortPaths(var AOrder: array of SizeUInt;
  const AEntries: array of TResPackInputEntry; ALow, AHigh: Int64);

  function Cmp(I, J: Int64): Integer;
  begin
    Result := PathByteCompare(PChar(AEntries[AOrder[I]].Path),
      Length(AEntries[AOrder[I]].Path), AEntries[AOrder[J]].Path);
  end;

  procedure Swap(I, J: Int64);
  var
    T: SizeUInt;
  begin
    T := AOrder[I];
    AOrder[I] := AOrder[J];
    AOrder[J] := T;
  end;

var
  L, R: Int64;
  Pivot: Int64;
begin
  while ALow < AHigh do
  begin
    if AHigh - ALow < 16 then
    begin
      InsertionSortPaths(AOrder, AEntries, ALow, AHigh);
      Exit;
    end;
    Pivot := (ALow + AHigh) shr 1;
    Swap(Pivot, AHigh);
    L := ALow;
    R := AHigh - 1;
    while L <= R do
    begin
      while (L <= R) and (Cmp(L, AHigh) < 0) do
        Inc(L);
      while (L <= R) and (Cmp(R, AHigh) >= 0) do
        Dec(R);
      if L < R then
      begin
        Swap(L, R);
        Inc(L);
        Dec(R);
      end;
    end;
    Swap(L, AHigh);
    { 尾递归消除：先处理较小侧；Int64 下标使空区间（L-1=-1）被循环条件自然排除 }
    if L - ALow < AHigh - L then
    begin
      QuickSortPaths(AOrder, AEntries, ALow, L - 1);
      ALow := L + 1;
    end
    else
    begin
      QuickSortPaths(AOrder, AEntries, L + 1, AHigh);
      AHigh := L - 1;
    end;
  end;
end;

function AlignUp(const AValue, AAlign: UInt64): UInt64; inline;
begin
  Result := (AValue + (AAlign - 1)) div AAlign * AAlign;
end;

function BytesEqual(const AA, AB: PByte; const ALen: SizeUInt): Boolean;
var
  I: SizeUInt;
begin
  if ALen = 0 then
    Exit(True);   { 规避 SizeUInt 下界回绕 }
  Result := False;
  for I := 0 to ALen - 1 do
    if AA[I] <> AB[I] then
      Exit;
  Result := True;
end;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  N, I, J, K: SizeUInt;
  Order: array of SizeUInt;
  TotalInput: SizeUInt;
  PathLens: array of Word;
  StrLen: UInt64;
  StrTabBase, DataStart, Cur, EndData: UInt64;
  Slots: array of TSlotInfo;
  SlotCount: SizeUInt;
  EntrySlots: array of SizeUInt;
  FnvBuf: array of UInt32;
  NeedFnv: Boolean;
  DigOff: UInt64;
  Total: UInt64;
  Buf: PByte;
  HdrFlags: UInt32;
  EntFlags: Word;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;

  N := SizeUInt(Length(AEntries));

  { ── 校验 + 上限（INV-R8/R10） ── }
  TotalInput := 0;
  SetLength(PathLens, N);
  { 注意：N 为 SizeUInt，所有 "to N-1" 循环必须以 N>0 为前提（0-1 回绕） }
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      if not ResPackValidPath(AEntries[I].Path, True) then
        raise EResPackInvalidPath.Create('respack: invalid pack path "'
          + AEntries[I].Path + '"');
      PathLens[I] := Word(Length(AEntries[I].Path));
      TotalInput := TotalInput + SizeUInt(AEntries[I].DataSize);
    end;
  if TotalInput > AOpts.MaxTotalInputBytes then
    raise EResPackTooLarge.Create('respack: total input exceeds limit');

  { ── 排序 ── }
  SetLength(Order, N);
  if N > 0 then
  begin
    for I := 0 to N - 1 do
      Order[I] := I;
    if N > 1 then
      QuickSortPaths(Order, AEntries, 0, Int64(N) - 1);
    for I := 1 to N - 1 do
    begin
      if PathByteCompare(PChar(AEntries[Order[I]].Path),
        Length(AEntries[Order[I]].Path), AEntries[Order[I - 1]].Path) = 0 then
        raise EResPackDuplicatePath.Create('respack: duplicate path "'
          + AEntries[Order[I]].Path + '"');
    end;
  end;

  { ── fnv 计算（hash 输出或去重候选任一需要时） ── }
  NeedFnv := AOpts.Hashes or AOpts.Deduplicate;
  SetLength(FnvBuf, N);
  if NeedFnv and (N > 0) then
    for I := 0 to N - 1 do
      FnvBuf[I] := ResPackFnv1a32(AEntries[I].Data, AEntries[I].DataSize);

  { ── 布局 ── }
  StrLen := 0;
  if N > 0 then
    for I := 0 to N - 1 do
      StrLen := StrLen + PathLens[I];
  StrTabBase := UInt64(RESPACK_HEADER_SIZE) + UInt64(N) * RESPACK_ENTRY_SIZE;
  if N > 0 then
    DataStart := AlignUp(StrTabBase + StrLen, RESPACK_DATA_ALIGN)
  else
    DataStart := StrTabBase;

  SetLength(EntrySlots, N);
  SetLength(Slots, N);
  SlotCount := 0;
  Cur := DataStart;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := Order[I];
      EntrySlots[J] := SizeUInt(-1);
      if AOpts.Deduplicate and (SlotCount > 0) then
      begin
        for K := 0 to SlotCount - 1 do
        begin
          if (Slots[K].Fnv = FnvBuf[J])
            and (AEntries[J].DataSize = AEntries[Slots[K].SrcIdx].DataSize)
            and ((AEntries[J].DataSize = 0)
              or BytesEqual(AEntries[J].Data,
                AEntries[Slots[K].SrcIdx].Data, AEntries[J].DataSize)) then
          begin
            EntrySlots[J] := K;
            Break;
          end;
        end;
      end;
      if EntrySlots[J] = SizeUInt(-1) then
      begin
        Cur := AlignUp(Cur, RESPACK_DATA_ALIGN);
        Slots[SlotCount].Offset := Cur;
        Slots[SlotCount].SrcIdx := J;
        if NeedFnv then
          Slots[SlotCount].Fnv := FnvBuf[J]
        else
          Slots[SlotCount].Fnv := 0;
        EntrySlots[J] := SlotCount;
        Cur := Cur + UInt64(AEntries[J].DataSize);
        Inc(SlotCount);
      end;
    end;
  EndData := Cur;
  if AOpts.DigestFunc <> nil then
  begin
    DigOff := AlignUp(EndData, 4);
    Total := DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
  end
  else
  begin
    DigOff := 0;
    Total := EndData;
  end;

  { ── 组装 ── }
  GetMem(Buf, Total);
  FillChar(Buf[0], Total, 0);
  Result.Data := Buf;
  Result.Size := SizeUInt(Total);
  Result.Owned := True;

  Buf[0] := Ord('N'); Buf[1] := Ord('P');
  Buf[2] := Ord('R'); Buf[3] := Ord('S');
  WrU32LE(Buf + 4, RESPACK_VERSION);
  HdrFlags := 0;
  if AOpts.Hashes then
    HdrFlags := HdrFlags or RESPACK_FLAG_HASHED;
  if AOpts.DigestFunc <> nil then
    HdrFlags := HdrFlags or RESPACK_FLAG_DIGESTED;
  WrU32LE(Buf + 8, HdrFlags);
  WrU32LE(Buf + 12, UInt32(N));
  { 注意：FPC trunk 对"常量标识符实参 + inline 函数"存在常量传播缺陷，
    会把 u64 参数按 32 位折叠（high:=low）。所有 u64 写入的非常量来源必须已是
    UInt64 表达式；常量一律显式 UInt64() 转换。 }
  WrU64LE(Buf + 16, UInt64(RESPACK_HEADER_SIZE));
  WrU64LE(Buf + 24, DigOff);
  WrU64LE(Buf + 32, Total);

  { index + string table }
  Cur := StrTabBase;
  if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := Order[I];
      EntFlags := 0;
      if AOpts.Hashes then
        EntFlags := RESPACK_EFLAG_HASHED;
      WrU32LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE,
        UInt32(Cur - StrTabBase));
      WrU16LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 4,
        PathLens[J]);
      WrU16LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 6, EntFlags);
      WrU64LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 8,
        Slots[EntrySlots[J]].Offset);
      WrU64LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 16,
        UInt64(AEntries[J].DataSize));
      WrU64LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 24,
        UInt64(AEntries[J].ModTime));
      if AOpts.Hashes then
        WrU32LE(Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 32,
          FnvBuf[J]);
      Buf[RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 36]
        := Byte(RESPACK_CODEC_STORE);
      if PathLens[J] > 0 then
        Move(Pointer(AEntries[J].Path)^,
          (Buf + Cur)[0], PathLens[J]);
      Inc(Cur, PathLens[J]);
    end;

  { data slots }
  if SlotCount > 0 then
    for K := 0 to SlotCount - 1 do
    begin
      J := Slots[K].SrcIdx;
      if AEntries[J].DataSize > 0 then
        Move(AEntries[J].Data[0], (Buf + Slots[K].Offset)[0],
          AEntries[J].DataSize);
    end;

  { digest 区：算法由调用方注入（INV-R9），共享槽位按各自输入计算（字节相等 ⇒ 摘要一致） }
  if (AOpts.DigestFunc <> nil) and (N > 0) then
    for I := 0 to N - 1 do
      AOpts.DigestFunc(AEntries[I].Data, AEntries[I].DataSize,
        Buf + DigOff + I * RESPACK_DIGEST_SIZE);
end;

end.
