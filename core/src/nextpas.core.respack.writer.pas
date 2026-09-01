unit nextpas.core.respack.writer;

{** @desc respack 打包器：条目列表 → 单个确定性 blob。
  流程见 FORMAT.md「Writer 构造流程」；不变量见 CONTRACT.md INV-R5/R6/R8/R10。
  布局计算单源于 nextpas.core.respack.writer.layout（首遍排序/去重/对齐），
  本单元仅负责纯内存组装；流式两遍由 writer.stream 复用同布局以达 ~1× 峰值。 }

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
  nextpas.core.bytes.ops,
  nextpas.core.respack.writer.builder,
  nextpas.core.respack.writer.layout;

function ResPackBuild(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions): TResPackBlob;
var
  L: TResPackLayout;
  N, I, J, K: SizeUInt;
  Cur: UInt64;
  Buf: PByte;
begin
  Result.Data := nil;
  Result.Size := 0;
  Result.Owned := False;
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    N := L.N;
    { ── 组装 ── 纯内存一次性 GetMem(Buf,Total) 为 v1 确定性路径；
      流式两遍由 nextpas.core.respack.writer.stream 复用同布局 L 首遍，
      次遍分段 AWrite（头/index/string 合批 → 槽间隙零填 → data 零拷贝 BytesCopy 分段 → digest），
      峰值 ~1×+头，零双驻留；本单元保留纯内存路径以保零依赖与 golden 确定性。
      头/index/string 单源于 writer.builder.ResPackWriterFillHead（零拷贝 bytes.ops 单源）；
      零化统一：Head 段由 builder 内 SpanZero 全量零化 + 槽/ digest 间隙定向 BytesZero，
      去除 64MiB 双路径分支，杜绝漂移残留未清零字节。 }
    GetMem(Buf, L.Total);
    Result.Data := Buf;
    Result.Size := SizeUInt(L.Total);
    Result.Owned := True;
    try
      ResPackWriterFillHead(Buf, AEntries, AOpts, L);
      Cur := L.DataStart;
      if L.SlotCount > 0 then
        for K := 0 to L.SlotCount - 1 do
        begin
          if L.Slots[K].Offset > Cur then
            BytesZero(Buf + Cur, SizeUInt(L.Slots[K].Offset - Cur));
          J := L.Slots[K].SrcIdx;
          if AEntries[J].DataSize > 0 then
            BytesCopy(Buf + L.Slots[K].Offset, AEntries[J].Data,
              AEntries[J].DataSize);
          Cur := L.Slots[K].Offset + UInt64(AEntries[J].DataSize);
        end;
      if (AOpts.DigestFunc <> nil) and (L.DigOff > Cur) then
        BytesZero(Buf + Cur, SizeUInt(L.DigOff - Cur));

      if (AOpts.DigestFunc <> nil) and (N > 0) then
        for I := 0 to N - 1 do
          AOpts.DigestFunc(AEntries[I].Data, AEntries[I].DataSize,
            Buf + L.DigOff + I * RESPACK_DIGEST_SIZE);
    except
      FreeMem(Buf);
      Result.Data := nil;
      Result.Size := 0;
      Result.Owned := False;
      raise;
    end;
  finally
    ResPackLayoutClear(L);
  end;
end;

end.
