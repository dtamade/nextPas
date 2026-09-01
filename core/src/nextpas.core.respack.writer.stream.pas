unit nextpas.core.respack.writer.stream;

{** @desc respack 流式构造：两遍分段零双驻留，512MB 峰值 ~1×+头。
  首遍复用 writer.layout 单源计算 Total/槽位/去重（INV-R5 确定性同 ResPackBuild），
  次遍分段经 AWrite 回调：头/index/string 合批 → 槽间隙零填 → data 零拷贝 Move 分段 → digest，
  零额外 Total 缓冲；ResPackBuildStreamSize 仅首遍取 Total 零分配。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.respack.base;

type
  TResPackWriteProc = reference to procedure(const AData: PByte; const ASize: SizeUInt);

{ 流式两遍构造：与 ResPackBuild 同确定性（INV-R5），分段经 AWrite 回调输出，
  不一次性持有 Total 输出缓冲；调用方提供流/文件句柄的写入闭包即可。 }
procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;

implementation

uses
  nextpas.core.bytes.ops,
  nextpas.core.respack.writer.builder,
  nextpas.core.respack.writer.layout;

{ 零填充分段写入：复用 bytes.ops 全局零页单源，无栈分配/无重复 FillChar，零拷贝分段直写；外联守 design-conventions §2 红线2 }
function HasDigestOpt(const AOpts: TResPackBuildOptions): Boolean; inline;
begin
  Result := Assigned(AOpts.DigestFunc);
end;

procedure WriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64);
var
  N: UInt64;
  L: SizeUInt;
begin
  if ACount = 0 then Exit;
  N := ACount;
  while N > 0 do
  begin
    if N >= BYTES_ZERO_PAGE_SIZE then L := BYTES_ZERO_PAGE_SIZE else L := SizeUInt(N);
    AWrite(@BYTES_ZERO_PAGE[0], L);
    Dec(N, L);
  end;
end;

procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
var
  L: TResPackLayout;
  N, I, J, K: SizeUInt;
  Cur: UInt64;
  Head: PByte;
  HeadSize: UInt64;
  Gap: UInt64;
  DigestTmp: TResPackDigest;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  ResPackComputeLayout(AEntries, AOpts, L);
  Head := nil;
  try
    N := L.N;
    HeadSize := L.DataStart;
    { 头块：header + index + string table（含对齐填充），大小 = DataStart（空包 40），
      峰值仅 ~头（KB 级），不含 Total；头/index/string 单源于 writer.builder（零拷贝 BytesCopy，BytesZero 单源零化）。 }
    GetMem(Head, HeadSize);
    try
      ResPackWriterFillHead(Head, AEntries, AOpts, L);
      AWrite(Head, SizeUInt(HeadSize));
    finally
      FreeMem(Head);
      Head := nil;
    end;

    { data 槽位：按 Offset 顺序分段零拷贝直写，槽间隙零填；峰值 1×+头，无 Total 双驻留。 }
    Cur := HeadSize;
    if L.SlotCount > 0 then
      for K := 0 to L.SlotCount - 1 do
      begin
        Gap := L.Slots[K].Offset - Cur;
        if Gap > 0 then
          WriteZeros(AWrite, Gap);
        J := L.Slots[K].SrcIdx;
        if AEntries[J].DataSize > 0 then
          AWrite(AEntries[J].Data, AEntries[J].DataSize);
        Cur := L.Slots[K].Offset + UInt64(AEntries[J].DataSize);
      end;

    { digest 对齐间隙 }
    if AOpts.DigestFunc <> nil then
    begin
      if L.DigOff > Cur then
        WriteZeros(AWrite, L.DigOff - Cur);
      if N > 0 then
        for I := 0 to N - 1 do
        begin
          BytesZero(@DigestTmp[0], RESPACK_DIGEST_SIZE);
          AOpts.DigestFunc(AEntries[I].Data, AEntries[I].DataSize, @DigestTmp[0]);
          AWrite(@DigestTmp[0], RESPACK_DIGEST_SIZE);
        end;
    end;
  finally
    ResPackLayoutClear(L);
  end;
end;

function ResPackBuildStreamSize(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): UInt64;
var
  L: TResPackLayout;
begin
  { 预计算 Total 零分配：复用布局单源首遍，不 GetMem 全量 blob。 }
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    Result := L.Total;
  finally
    ResPackLayoutClear(L);
  end;
end;

end.
