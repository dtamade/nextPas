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

uses
  nextpas.core.base,
  nextpas.core.base.utils,
  nextpas.core.exception;

type
  TSlotInfo = record
    Offset: UInt64;
    SrcIdx: SizeUInt;   { 槽位内容来源条目（去重回验基准） }
    Fnv: UInt32;
  end;

const
  BUCKET_MIN = 256;
  BUCKET_MAX = 65536;

{ 路径字节序比较单源：Writer 内三处排序/去重比较（插入、快排双探针、重复检测）
  原各以 CompareBytesOrdered+Pointer(@Path[1])+PathLens 重复 4 行，现收敛为
  单一 inline 纯函数，零额外分配，复用 L0 有序原语，高级感与可维护性封口。 }
function CmpPath(const AEntries: array of TResPackInputEntry;
  const ALens: array of Word; AI, AJ: SizeUInt): Integer; inline;
begin
  Result := nextpas.core.base.utils.CompareBytesOrdered(
    Pointer(@AEntries[AI].Path[1]), Pointer(@AEntries[AJ].Path[1]),
    SizeUInt(ALens[AI]), SizeUInt(ALens[AJ]));
end;

{ 小区间插入排序：稳定、无递归；quick 在区间 <16 时切换到此。
  注意所有排序下标一律 Int64：Hoare 分区的 R 会越过下界一次，
  无符号类型在此回绕导致越界访问（FPC trunk 实测），有符号则天然安全。
  PathLens 为预计算 Length 缓存，消热点 Length() 重复取址。 }
procedure InsertionSortPaths(var AOrder: array of SizeUInt;
  const AEntries: array of TResPackInputEntry;
  const APathLens: array of Word; ALow, AHigh: Int64);
var
  I, J: Int64;
  Key: SizeUInt;
begin
  I := ALow + 1;
  while I <= AHigh do
  begin
    Key := AOrder[I];
    J := I - 1;
    while (J >= ALow) and (CmpPath(AEntries, APathLens, AOrder[J], Key) > 0) do
    begin
      AOrder[J + 1] := AOrder[J];
      Dec(J);
    end;
    AOrder[J + 1] := Key;
    Inc(I);
  end;
end;

procedure QuickSortPaths(var AOrder: array of SizeUInt;
  const AEntries: array of TResPackInputEntry;
  const APathLens: array of Word; ALow, AHigh: Int64);

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
      InsertionSortPaths(AOrder, AEntries, APathLens, ALow, AHigh);
      Exit;
    end;
    Pivot := (ALow + AHigh) shr 1;
    Swap(Pivot, AHigh);
    L := ALow;
    R := AHigh - 1;
    while L <= R do
    begin
      while (L <= R) and (CmpPath(AEntries, APathLens, AOrder[L], AOrder[AHigh]) < 0) do
        Inc(L);
      while (L <= R) and (CmpPath(AEntries, APathLens, AOrder[R], AOrder[AHigh]) >= 0) do
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
      QuickSortPaths(AOrder, AEntries, APathLens, ALow, L - 1);
      ALow := L + 1;
    end
    else
    begin
      QuickSortPaths(AOrder, AEntries, APathLens, L + 1, AHigh);
      AHigh := L - 1;
    end;
  end;
end;

function AlignUp(const AValue, AAlign: UInt64): UInt64; inline;
begin
  Result := (AValue + (AAlign - 1)) div AAlign * AAlign;
end;

function BytesEqual(const AA, AB: PByte; const ALen: SizeUInt): Boolean; inline;
begin
  // 为什么改：直通 base.utils.CompareMem 单源，消 bytes.ops.TByteSpan 包装分支，保持与 reader CompareBytesOrdered 同单源
  Result := nextpas.core.base.utils.CompareMem(AA, AB, ALen);
end;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  N, I, J, K: SizeUInt;
  BucketIdx, BucketCount: SizeUInt;
  Buckets: array of array of SizeUInt;
  BucketCounts: array of SizeUInt;
  NewCap: SizeUInt;
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
  Target: SizeUInt;
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
        raise EResPackInvalidPath.CreateCtx('build', AEntries[I].Path, 'invalid pack path');
      if Length(AEntries[I].Path) > High(Word) then
        raise EResPackInvalidPath.CreateCtx('build', AEntries[I].Path, 'path too long');
      PathLens[I] := Word(Length(AEntries[I].Path));
      // 为什么改：32位 SizeUInt 回绕会绕过 MaxTotalInputBytes 限额，用 TryAddSizeUInt 溢出即判 TooLarge（S-2）
      if not TryAddSizeUInt(TotalInput, SizeUInt(AEntries[I].DataSize), TotalInput) then
        raise EResPackTooLarge.CreateCtx('build', AEntries[I].Path, 'total input exceeds limit');
    end;
  if TotalInput > AOpts.MaxTotalInputBytes then
    raise EResPackTooLarge.CreateCtx('build', '', 'total input exceeds limit');
  if AOpts.CodecId <> RESPACK_CODEC_STORE then
    raise EResPackError.Create('respack: unsupported CodecId, v1 only store(0)');

  { ── 排序 ── }
  SetLength(Order, N);
  if N > 0 then
  begin
    for I := 0 to N - 1 do
      Order[I] := I;
    if N > 1 then
      QuickSortPaths(Order, AEntries, PathLens, 0, Int64(N) - 1);
    for I := 1 to N - 1 do
    begin
      if CmpPath(AEntries, PathLens, Order[I], Order[I - 1]) = 0 then
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
  { Deduplicate: FNV 哈希分桶将 O(n²) 扫描降为期望 O(n)，仅哈希碰撞时回验字节 }
  if AOpts.Deduplicate then
  begin
    // 桶数取 2 的幂且 ≥ 2×N，平均 0.5 槽/桶，碰撞探测近常数；N*2 溢出安全
    BucketCount := BUCKET_MIN;
    Target := 0;
    if not TryMulSizeUInt(N, 2, Target) then
      Target := High(SizeUInt);
    while (BucketCount < Target) and (BucketCount < BUCKET_MAX) do
      BucketCount := BucketCount shl 1;
    SetLength(Buckets, BucketCount);
    SetLength(BucketCounts, BucketCount);
    for I := 0 to BucketCount - 1 do BucketCounts[I] := 0;
    // Buckets 初始化为空动态数组，无需显式清零
    if N > 0 then
      for I := 0 to N - 1 do
      begin
        J := Order[I];
        EntrySlots[J] := SizeUInt(-1);
        BucketIdx := SizeUInt(FnvBuf[J]) and (BucketCount - 1);
        if (SlotCount > 0) and (BucketCounts[BucketIdx] > 0) then
        begin
          for K := 0 to BucketCounts[BucketIdx] - 1 do
          begin
            // Buckets[BucketIdx][K] 存槽位索引
            if (Slots[Buckets[BucketIdx][K]].Fnv = FnvBuf[J])
              and (AEntries[J].DataSize = AEntries[Slots[Buckets[BucketIdx][K]].SrcIdx].DataSize)
              and ((AEntries[J].DataSize = 0)
                or BytesEqual(AEntries[J].Data,
                  AEntries[Slots[Buckets[BucketIdx][K]].SrcIdx].Data, AEntries[J].DataSize)) then
            begin
              EntrySlots[J] := Buckets[BucketIdx][K];
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
          // 加入桶：2× 预分配，消逐一重分配（4 起步，碰撞桶近常数）
          if BucketCounts[BucketIdx] >= SizeUInt(Length(Buckets[BucketIdx])) then
          begin
            NewCap := SizeUInt(Length(Buckets[BucketIdx])) * 2;
            if NewCap < 4 then NewCap := 4;
            SetLength(Buckets[BucketIdx], NewCap);
          end;
          Buckets[BucketIdx][BucketCounts[BucketIdx]] := SlotCount;
          Inc(BucketCounts[BucketIdx]);
          EntrySlots[J] := SlotCount;
          Cur := Cur + UInt64(AEntries[J].DataSize);
          Inc(SlotCount);
        end;
      end;
  end
  else if N > 0 then
    for I := 0 to N - 1 do
    begin
      J := Order[I];
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
  EndData := Cur;
  if AOpts.DigestFunc <> nil then
  begin
    DigOff := AlignUp(EndData, 4);
    // 为什么改：DigOff + N*32 在 N 极大时可能 UInt64 回绕，对齐 reader 的 step8 溢出守卫（S-3）
    if N > High(UInt64) div RESPACK_DIGEST_SIZE then
      raise EResPackTooLarge.CreateCtx('build', '', 'digest area overflow');
    Total := DigOff + UInt64(N) * RESPACK_DIGEST_SIZE;
    if Total < DigOff then
      raise EResPackTooLarge.CreateCtx('build', '', 'digest area overflow');
  end
  else
  begin
    DigOff := 0;
    Total := EndData;
  end;

  { ── 组装 ── P1-1 gap 清零：512MB 全量 0.5ms→大包仅空隙<1KB，峰值 2.03×→1.15×
    ≥64MB 走逐段 gap 清零（header/index 全覆写无需清零，string 尾/槽间隙/ digest 对齐/保留字节 定向清零） }
  GetMem(Buf, Total);
  Result.Data := Buf;
  Result.Size := SizeUInt(Total);
  Result.Owned := True;
  // 为什么改：DigestFunc 回调可能抛异常，需保证 Buf 在异常路径释放，避免泄漏（S-1）
  try
  if Total < 64 * 1024 * 1024 then
  begin
    // <64MB 全量清零成本可忽略，确定性最高
    FillChar(Buf[0], Total, 0);
  end
  else
  begin
    // ≥64MB 定向清零：仅 string 尾对齐、槽间隙、digest 对齐预留；index 保留字节在写入循环中逐项清零
    // 此处先不全量清零，后续按 gap 逐段 FillChar
  end;

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

  { index + string table — index 全覆写，hash 缺省与保留字节在大包定向清零 }
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
          FnvBuf[J])
      else if Total >= 64 * 1024 * 1024 then
        FillChar((Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 32)^, 4, 0);
      Buf[RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 36]
        := Byte(RESPACK_CODEC_STORE);
      if Total >= 64 * 1024 * 1024 then
        FillChar((Buf + RESPACK_HEADER_SIZE + I * RESPACK_ENTRY_SIZE + 37)^, 3, 0);
      if PathLens[J] > 0 then
        Move(Pointer(AEntries[J].Path)^,
          (Buf + Cur)[0], PathLens[J]);
      Inc(Cur, PathLens[J]);
    end;
  if (Total >= 64 * 1024 * 1024) and (Cur < DataStart) then
    FillChar((Buf + Cur)^, SizeUInt(DataStart - Cur), 0);

  { data slots — 定向清零槽间隙（≥64MB 时逐段 FillChar，避免全量带宽） }
  if SlotCount > 0 then
    for K := 0 to SlotCount - 1 do
    begin
      if (Total >= 64 * 1024 * 1024) and (K > 0) then
      begin
        J := Slots[K - 1].SrcIdx;
        Cur := Slots[K - 1].Offset + UInt64(AEntries[J].DataSize);
        if Cur < Slots[K].Offset then
          FillChar((Buf + Cur)^, SizeUInt(Slots[K].Offset - Cur), 0);
      end;
      J := Slots[K].SrcIdx;
      if AEntries[J].DataSize > 0 then
        Move(AEntries[J].Data[0], (Buf + Slots[K].Offset)[0],
          AEntries[J].DataSize);
    end;
  if (Total >= 64 * 1024 * 1024) and (AOpts.DigestFunc <> nil) and (SlotCount > 0) then
  begin
    J := Slots[SlotCount - 1].SrcIdx;
    Cur := Slots[SlotCount - 1].Offset + UInt64(AEntries[J].DataSize);
    if Cur < DigOff then
      FillChar((Buf + Cur)^, SizeUInt(DigOff - Cur), 0);
  end
  else if (Total >= 64 * 1024 * 1024) and (AOpts.DigestFunc <> nil) and (SlotCount = 0) and (DigOff > DataStart) then
    FillChar((Buf + DataStart)^, SizeUInt(DigOff - DataStart), 0);

  { digest 区：算法由调用方注入（INV-R9），共享槽位按各自输入计算（字节相等 ⇒ 摘要一致） }
  if (AOpts.DigestFunc <> nil) and (N > 0) then
    for I := 0 to N - 1 do
      AOpts.DigestFunc(AEntries[I].Data, AEntries[I].DataSize,
        Buf + DigOff + I * RESPACK_DIGEST_SIZE);
  except
    on E: Exception do
    begin
      FreeMem(Buf);
      Result.Data := nil;
      Result.Size := 0;
      Result.Owned := False;
      raise;
    end;
  end;
end;

end.
