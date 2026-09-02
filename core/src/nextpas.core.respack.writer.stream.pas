unit nextpas.core.respack.writer.stream;

{** @desc respack 流式构造：两遍分段零双驻留，512MB 峰值 ~1×+头(阈值守卫 8MiB)。
  首遍复用 writer.layout 单源计算 Total/槽位/去重（INV-R5 确定性同 ResPackBuild），
  次遍分段经 AWrite 回调：头/index/string 合批(TBytes RAII托管自动释放，超 8MiB 阈值守卫防数百 MB 头对峰值冲击) → 槽间隙零填(WriteZeros 小间隙 inline 快道/4K零页零拷贝 + 大间隙外联 Loop 守 §2 红线2) → data 零拷贝 Move 分段 → digest，
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

const
  { 头块 inline 阈值：8 MiB。12.8M 条目时 HeadSize=40+N*40+StrLen 可达数百 MB，单次 SetLength 会推高峰值至 500MB+失 KB 级承诺；
    阈值守卫显式 EResPackTooLarge 拒绝超限头，保持流式峰值 ~1×+头(≤8MiB) 稳定；超阈需头分段能力，反哺 mem.memory_map/io.mapped owner，不私自引入 FS/mmap。 }
  RESPACK_STREAM_MAX_HEAD: SizeUInt = 8 * 1024 * 1024;

{ 零填充分段写入：复用 bytes.ops 全局零页单源(.bss 4K)，无栈分配/无重复 FillChar，零拷贝分段直写；inline 热路径 + 小间隙单回调快道(≤4K)，大间隙4K切片控单次syscall尺寸；外联守 design-conventions §2 红线2 }
function HasDigestOpt(const AOpts: TResPackBuildOptions): Boolean; inline;
begin
  Result := Assigned(AOpts.DigestFunc);
end;

{ 大间隙零填外联体：含 while 循环，禁 inline 守 §2 红线2，控 I-Cache 复制膨胀；由 inline 快道 delegat }
procedure WriteZerosLoop(const AWrite: TResPackWriteProc; ACount: UInt64);
var
  N: UInt64;
  L: SizeUInt;
begin
  N := ACount;
  while N > 0 do
  begin
    if N >= BYTES_ZERO_PAGE_SIZE then L := BYTES_ZERO_PAGE_SIZE else L := SizeUInt(N);
    AWrite(@BYTES_ZERO_PAGE[0], L);
    Dec(N, L);
  end;
end;

{ 小间隙快道 inline：≤4K 单次 AWrite 零拷贝，热点对齐 16/4 典型≤15 消除调用开销；>4K 外联 Loop 守红线2 }
procedure WriteZeros(const AWrite: TResPackWriteProc; ACount: UInt64); inline;
begin
  if ACount = 0 then Exit;
  { perf: inline消除调用开销 + 零拷贝 BYTES_ZERO_PAGE 单源；小间隙单回调快道避免while开销，大间隙委托外联 Loop 复用同页零拷贝 }
  if ACount <= BYTES_ZERO_PAGE_SIZE then
  begin
    AWrite(@BYTES_ZERO_PAGE[0], SizeUInt(ACount));
    Exit;
  end;
  WriteZerosLoop(AWrite, ACount);
end;

procedure ResPackBuildStream(const AEntries: array of TResPackInputEntry;
  const AOpts: TResPackBuildOptions; const AWrite: TResPackWriteProc);
var
  L: TResPackLayout;
  N, I, J, K: SizeUInt;
  Cur: UInt64;
  HeadBuf: TBytes;
  Head: PByte;
  HeadSize: UInt64;
  Gap: UInt64;
  DigestTmp: TResPackDigest;
begin
  if not Assigned(AWrite) then
    raise EResPackError.Create('respack.stream: Write proc is nil');
  ResPackComputeLayout(AEntries, AOpts, L);
  try
    N := L.N;
    HeadSize := L.DataStart;
    { 头块：header + index + string table（含对齐填充），大小 = DataStart（空包 40），
      峰值仅 ~头（KB 级，阈值守卫 8MiB），不含 Total；头/index/string 单源于 writer.builder（零拷贝 BytesCopy，BytesZero 单源零化）。
      RAII托管：TBytes接口式托管自动释放，异常安全无GetMem/FreeMem手动路径；inline零拷贝证据见bytes.ops/builder。
      阈值守卫：12.8M 上限时头部可达数百 MB，超 8MiB 时拒绝以保峰值稳定，需头分段时反哺 mem.memory_map/io.mapped owner。 }
    if HeadSize > UInt64(RESPACK_STREAM_MAX_HEAD) then
      raise EResPackTooLarge.Create('respack.stream: head too large (>8MiB) – threshold guard for peak stability; head chunking required for extreme scales');
    SetLength(HeadBuf, SizeUInt(HeadSize));
    if HeadSize > 0 then Head := @HeadBuf[0] else Head := nil;
    ResPackWriterFillHead(Head, AEntries, AOpts, L);
    if HeadSize > 0 then AWrite(Head, SizeUInt(HeadSize));

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
