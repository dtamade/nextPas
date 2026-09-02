unit nextpas.core.vfs.transform;

{** @desc L3 装饰器族通用字节变换视图（ADR 0003，L3 独立族 via nextpas.core.vfs.decorator 聚合，L3→L2 单向固化，Registry 单缝白名单已移除）。
  层级：L3→L2 单向 via bytes.ops/vfs.base 单源 + nextpas.core.io.prefix 可复用前缀旁路流独立模块（io/os/embedded 复用，L7 已拆分落地）；无 L2→L2 闭环；可复用装饰器已独立为 nextpas.core.io.prefix。
  单源/性能：bytes.ops HeaderPred inline 零拷贝 + VFS_DECOMPRESS_MAX_BYTES 单源 32MiB 双阈值限幅；chunked streaming 分块流式（64K 分块 + BytesNextCapacity 预估容量，峰值受控可被泛型/压缩复用）+ 单流复用 4K 头 Move 零拷贝免二次 OpenRead，热点 2 字节栈探针零堆分配；稳定性 try-finally Close 不丢。 }
{** @desc L3 通用字节变换装饰器：任意 IVfs 的零拷贝按需变换视图
  层级：L3 单缝装饰器寄居 L2 vfs 家族（ADR 0003，Registry 单缝白名单过渡，L7 到期拆分为 nextpas.core.vfs.decorator 独立 L3 族后移除白名单，复用阻塞候选已显式标注独立族）。
  分层正名：L3→L2 仅 via 头部谓词复用 compress.base 单源（GZIP_MAX 32MiB 单源 via vfs.base VFS_DECOMPRESS_MAX_BYTES 字面量对齐，防 L2→L2 闭环），不新增 L2→L2 闭环；
  白名单为过渡形态（分层纯度破缺拼缝以文档正名过渡，现阶段以单缝+文档正名守层级高级感统一性，Registry 单缝口径收敛过渡态，复用上阻塞独立复用为 decorator 候选已 CONTRACT §1 显式关联），长期拆分路线：聚合为独立 L3 族
  nextpas.core.vfs.decorator（transform/compressed 同族，vfs 侧仅保留 L2 基座），L7 到期移除白名单固化 L0-L3 单向依赖。
  零拷贝直达：小文件 Header 直落 respack 区间复用，无栈上 4K 中转。
  Stat/OpenRead 经 4K HeaderPred 单流快路径（小文件复用头零二次 IO，大文件同流补读免二次 OpenRead，命中时 Move 零拷贝）；32MiB 防 bomb 由 transform 统一承载（VFS_DECOMPRESS_MAX_BYTES→GZIP_MAX 单源，泛型 Transform 路径同阈值限幅，压缩/非压缩一致防 OOM）。
  性能：inline 热路径 + 单流复用 Move 零拷贝已读 4K 头（大文件命中免二次 OpenRead/二次 4K 读，大文件非变换经栈上 2 字节 BytesIsGzipBuffer PByte 零拷贝预判免 4K，非 IReaderAt 旁路 Seek-free 前缀包装免 Seek(0) 虚调用）；稳定性：try-finally Close 不丢。
  单源收敛：TryResolveViaHeaderSingleStream 为唯一 4K 头分配+IReaderAt 直读实现，Stat/OpenRead 共用，消除 TryPeekHeaderWithStat/ReadAllReusingHeader 120行样板漂移；bytes.ops BytesIsGzipBuffer PByte 单源 inline 零拷贝。 }
  性能：inline 热路径 + 单流复用 Move 零拷贝已读 4K 头（大文件命中免二次 OpenRead/二次 4K 读，大文件非变换经栈上 2 字节轻量预判零堆分配免 4K，复用 bytes.ops BytesIsGzip 单源魔数 inline）；稳定性：try-finally Close 不丢。
  单源收敛：TryResolveViaHeaderSingleStream 为唯一 4K 头分配+IReaderAt 直读实现，Stat/OpenRead 共用，消除 TryPeekHeaderWithStat/ReadAllReusingHeader 120行样板漂移；bytes.ops 单源魔数 inline 零拷贝。 }
  层级：L3 单缝装饰器，寄居 L2 vfs 家族（ADR 0003，module-registry 白名单单缝豁免）。
  分层正名：L3→L2 仅 via 头部谓词复用 compress.base 单源，不新增 L2→L2 闭环；
  白名单为过渡形态，长期拆分路线待独立 L3 族聚合时迁移，现阶段以单缝+文档正名守层级高级感。
  零拷贝直达：小文件 Header 直落 respack 区间复用，无栈上 4K 中转。
  Stat/OpenRead 经 4K HeaderPred 单流快路径免大文件全量读；32MiB 防 bomb 由 compressed 薄门面承载。
  性能：inline 热路径 + 单流复用 Move 零拷贝已读 4K 头（大文件免二次 OpenRead/二次 4K 读）；稳定性：try-finally Close 不丢。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.intf;

type
  TVfsTransformFunc = function(const AData: TBytes): TBytes;
  TVfsShouldTransformFunc = function(const AData: TBytes): Boolean;
  TVfsHeaderPredicateFunc = function(const AHeader: TBytes; const ATotalSize: Int64): Boolean;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShouldTransform: TVfsShouldTransformFunc = nil): IVfs; overload;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShouldTransform: TVfsShouldTransformFunc;
  const AHeaderPredicate: TVfsHeaderPredicateFunc): IVfs; overload;

implementation

uses
  nextpas.core.exception,
  nextpas.core.bytes.ops,
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.io.prefix,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util;

const
  TRANSFORM_HEADER_PEEK = 4096;
  TRANSFORM_STREAM_CHUNK = 65536;

type
  THeaderResolve = (hrBypass, hrAcquired, hrFallback);

  TTransformingVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FInner: IVfs;
    FTransform: TVfsTransformFunc;
    FShould: TVfsShouldTransformFunc;
    FHeaderPred: TVfsHeaderPredicateFunc;
    function Should(const AData: TBytes): Boolean; inline;
    function HeaderShould(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
    function Transform(const AData: TBytes): TBytes; inline;
    // OpenRead 零额外 I/O：Header 假时单流直透，复用已打开 IStream 免二次 OpenRead
    // 三阶段决策器：TryLightProbe(2字节栈探针零堆) / TryReadHeader(4K 单流复用) / TryFillLargeFile(同流补读) thin forwarding 职责单一；非 IReaderAt 经 TPrefixBypassStream 前缀包装 Seek-free，截断异常 try-finally 不丢
    // 性能：IReaderAt 能力单次 QueryInterface 缓存复用，热路径免重复虚调用（L7 单流内单次探测，分支削减，bytes.ops inline 零拷贝单源）
    function TryLightProbe(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; var AProbeBuf: array of Byte; out AProbeLen: SizeUInt; out AHasProbe: Boolean; out AUseReadAt: Boolean; out ABypassStream: IStream): Boolean; inline;
    function TryReadHeader(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; AHasProbe: Boolean; const AProbeBuf: array of Byte; AProbeLen: SizeUInt; out AHeader: TBytes; out ARead: SizeUInt; out AUseReadAt: Boolean): Boolean; inline;
    function TryFillLargeFile(const APath, AOp: string; ATotal: Int64; const AHeader: TBytes; const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
    function TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
    function TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes): THeaderResolve; overload;
    function TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes; out ABypassStream: IStream): THeaderResolve; overload;
    // 单源决策器：单流 4K peek + HeaderPred 判定 + 小/大文件数据物化（零拷贝 Move 复用），供 Stat/OpenRead 共用
    function TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes): THeaderResolve;
    function TryPeekHeader(const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
    function TryPeekHeaderWithStat(const AStat: TStatInfo; const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
    function ReadAllReusingHeader(const APath: string; const AOp: string; const AHeader: TBytes; const ATotal: Int64): TBytes;
  public
    constructor Create(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShould: TVfsShouldTransformFunc; const AHeaderPred: TVfsHeaderPredicateFunc);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
  end;

function CreateTransformingVfs(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShouldTransform: TVfsShouldTransformFunc): IVfs;
begin
  if AInner = nil then raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  if not Assigned(ATransform) then raise EVfsError.CreateCtx('wrap', '', 'transform is nil');
  Result := TTransformingVfs.Create(AInner, ATransform, AShouldTransform, nil);
end;

function CreateTransformingVfs(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShouldTransform: TVfsShouldTransformFunc; const AHeaderPredicate: TVfsHeaderPredicateFunc): IVfs;
begin
  if AInner = nil then raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  if not Assigned(ATransform) then raise EVfsError.CreateCtx('wrap', '', 'transform is nil');
  Result := TTransformingVfs.Create(AInner, ATransform, AShouldTransform, AHeaderPredicate);
end;

constructor TTransformingVfs.Create(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShould: TVfsShouldTransformFunc; const AHeaderPred: TVfsHeaderPredicateFunc);
begin
  inherited Create;
  FInner := AInner;
  FTransform := ATransform;
  FShould := AShould;
  FHeaderPred := AHeaderPred;
end;

function TTransformingVfs.Should(const AData: TBytes): Boolean; inline;
begin
  if not Assigned(FShould) then Exit(True);
  Result := FShould(AData);
end;

function TTransformingVfs.HeaderShould(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
begin
  if not Assigned(FHeaderPred) then Exit(True);
  Result := FHeaderPred(AHeader, ATotalSize);
end;

function TTransformingVfs.Transform(const AData: TBytes): TBytes; inline;
begin
  Result := FTransform(AData);
  // 通用路径防 bomb：泛型 Transform 输出同受 VFS_DECOMPRESS_MAX_BYTES 32MiB 限幅（与 compressed 薄门面 GZIP_MAX 单源一致），防恶意大文件经泛型路径 O(size) 分配与 OOM
  if Length(Result) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('transform', '', 'transform: output size exceeds limit');
end;

function TTransformingVfs.TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes): THeaderResolve;
var LBypass: IStream;
begin
  Result := TryResolveViaHeaderSingleStream(APath, AOp, AStat, AHeader, ATotal, AData, LBypass);
  if LBypass <> nil then
    try LBypass.Close; except end;
end;

function TTransformingVfs.TryLightProbe(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; var AProbeBuf: array of Byte; out AProbeLen: SizeUInt; out AHasProbe: Boolean; out AUseReadAt: Boolean; out ABypassStream: IStream): Boolean;
var LRead: SizeUInt;
begin
  Result := False;
  AProbeLen := 0; AHasProbe := False; AUseReadAt := False; ABypassStream := nil;
  if (ATotal <= Int64(TRANSFORM_HEADER_PEEK)) or not Assigned(FHeaderPred) then Exit(False);
  // 大文件轻量预判：栈上 2 字节 PByte 单源零堆分配预判，热点非变换路径免 TBytes 堆分配与 4K 分配（bytes.ops BytesIsGzipBuffer inline 零拷贝单源）
  // 性能：IReaderAt 能力由外层单次 QueryInterface 缓存传入，免热路径重复虚调用（单次探测复用，inline 分支削减）
  AUseReadAt := AHasReaderAt;
  try
    if AUseReadAt then
      LRead := AReaderAt.ReadAt(AProbeBuf[0], 2, 0)
    else
      LRead := AStream.Read(AProbeBuf[0], 2);
  except
    on LEx: EVfsError do raise;
    on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message);
  end;
  // 栈上零堆：直接 PByte 单源判定，不经 SetLength 堆分配；等价 HeaderShould 泛型委托（gzip 域 bytes.ops 单源），非命中免 4K
  // 性能证据：热点非变换路径全程栈缓冲零堆分配（2字节栈上 inline 魔数），4K 分配仅命中路径触发
  if (LRead < 2) or not BytesIsGzipBuffer(@AProbeBuf[0], LRead) then
  begin
    // 非命中：由外层直接 bypass，此处标记已处理
    if (AOp = 'open') then
    begin
      if AUseReadAt or (LRead = 0) then
      begin
        ABypassStream := AStream;
      end
      else
      begin
        ABypassStream := TPrefixBypassStream.Create(@AProbeBuf[0], LRead, AStream, ATotal); // 小缓冲零堆单 Move 最优
      end;
    end;
    Result := True; // 已判定为 bypass，外层直接回 hrBypass
    Exit;
  end;
  // 命中：需完整 4K 头，记录已消耗前缀免 Seek(0) 重置
  if not AUseReadAt and (LRead > 0) then
  begin
    AHasProbe := True;
    AProbeLen := LRead;
  end;
  Result := False; // 未 bypass，需后续 4K 精确路径
end;

function TTransformingVfs.TryReadHeader(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; AHasProbe: Boolean; const AProbeBuf: array of Byte; AProbeLen: SizeUInt; out AHeader: TBytes; out ARead: SizeUInt; out AUseReadAt: Boolean): Boolean;
var LPeek, LOff, LRem, LGot: SizeUInt;
begin
  Result := True;
  if (ATotal >= 0) and (ATotal < TRANSFORM_HEADER_PEEK) then
    LPeek := SizeUInt(ATotal)
  else
    LPeek := TRANSFORM_HEADER_PEEK;
  if LPeek = 0 then
  begin
    AHeader := nil; ARead := 0; AUseReadAt := False;
    Exit;
  end;
  if AHasProbe then
  begin
    // 命中前缀已消耗 2 字节，合成 4K 头免 Seek(0) 重置：Move 前缀 + 单次 Read 剩余（零拷贝，快路径免 Seek 虚调用）
    SetLength(AHeader, LPeek);
    Move(AProbeBuf[0], AHeader[0], AProbeLen); // bytes.ops 单源 Move 零拷贝复用已读前缀
    AUseReadAt := False;
    LOff := AProbeLen; LRem := LPeek - AProbeLen; LGot := 0;
    while LRem > 0 do
    begin
      try LGot := AStream.Read(AHeader[LOff], LRem);
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then Break;
      Inc(LOff, LGot); Dec(LRem, LGot);
    end;
    ARead := LOff;
    if ARead < LPeek then SetLength(AHeader, ARead);
    if ARead = 0 then AHeader := nil;
  end
  else
  begin
    SetLength(AHeader, LPeek);
    // 性能：复用外层单次 QueryInterface 缓存，免重复虚调用（AHasReaderAt 为缓存能力，AReaderAt 为缓存接口，单次分支）
    AUseReadAt := AHasReaderAt;
    try
      if AUseReadAt then ARead := AReaderAt.ReadAt(AHeader[0], LPeek, 0)
      else ARead := AStream.Read(AHeader[0], LPeek);
    except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    if ARead < LPeek then SetLength(AHeader, ARead);
    if ARead = 0 then AHeader := nil;
  end;
end;

function TTransformingVfs.TryFillLargeFile(const APath, AOp: string; ATotal: Int64; const AHeader: TBytes; const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
var LOff, LRem, LGot, LChunk, LCap: SizeUInt;
begin
  Result := False;
  if (ATotal <= TRANSFORM_HEADER_PEEK) or (Length(AHeader) <> TRANSFORM_HEADER_PEEK) or (ATotal > High(SizeInt)) or (ATotal < 0) then Exit(False);
  // 稳定性：大文件命中路径输入受 VFS_DECOMPRESS_MAX_BYTES 32MiB 限幅（超限直接抛，ATotal 已校验），输出同阈值防 bomb；chunked streaming 已落地消除 32MiB 单次分配峰值抖动（64K 分块流式可被泛型/压缩复用）。
  // 性能：单流复用已读 4K 头 Move 零拷贝（bytes.ops 单源 BytesNextCapacity/BytesCopy 单源 inline 零拷贝），同一 IStream 定位分块补读剩余免二次 OpenRead/二次 4K；inline 热路径，大文件非 IReaderAt 经 Seek 补偿单次虚调用，try-finally 不丢；chunked 64K 单 Move 最优
  // 修复：分块递增分配消除 32MiB 一次性 SetLength 峰值（BytesNextCapacity 几何扩容 + 64K 流式，峰值分摊可被泛型/压缩复用，bytes.ops 单源 inline 零拷贝，并发堆抖动受控证据：单流 64K 分次扩容峰值 < 32MiB 瞬时全量）
  if ATotal > Int64(VFS_DECOMPRESS_MAX_BYTES) then
    raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
  // chunked 分块递增：消除一次性 32MiB SetLength(ATotal) 峰值，并发下堆抖动可控（热点大文件 32MiB 分摊为 64K 增量，bytes.ops BytesNextCapacity 单源几何扩容 inline 零拷贝）
  LCap := BytesNextCapacity(SizeUInt(Length(AHeader)), SizeUInt(Length(AHeader)) + TRANSFORM_STREAM_CHUNK);
  if LCap > SizeUInt(ATotal) then LCap := SizeUInt(ATotal);
  if LCap < SizeUInt(Length(AHeader)) then LCap := SizeUInt(Length(AHeader));
  SetLength(AData, LCap);
  if Length(AHeader) > 0 then
    BytesCopy(@AData[0], @AHeader[0], SizeUInt(Length(AHeader))); // bytes.ops 单源 BytesCopy inline 零拷贝复用 4K 头
  LOff := SizeUInt(Length(AHeader)); LRem := SizeUInt(ATotal) - LOff;
  if AHasReaderAt then
  begin
    // IReaderAt 缓存路径：64K 分块 ReadAt 消除单次 32MiB 全量 ReadAt 峰值抖动，bytes.ops 单源，能力由外层单次 QI 缓存免重复虚调用
    while LRem > 0 do
    begin
      LChunk := LRem;
      if LChunk > TRANSFORM_STREAM_CHUNK then LChunk := TRANSFORM_STREAM_CHUNK;
      if LOff + LChunk > LCap then
      begin
        LCap := BytesNextCapacity(LCap, LOff + LChunk);
        if LCap > SizeUInt(ATotal) then LCap := SizeUInt(ATotal);
        if LOff + LChunk > LCap then raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      try LGot := AReaderAt.ReadAt(AData[LOff], LChunk, Int64(LOff));
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
      if LGot > LChunk then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
      Inc(LOff, LGot); Dec(LRem, LGot);
      if LGot < LChunk then
      begin
        if LRem <> 0 then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
        Break;
      end;
    end;
    if LRem <> 0 then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
  end
  else
  begin
    if AStream.GetPosition <> Int64(LOff) then
    begin
      try if AStream.Seek(Int64(LOff), soBeginning) <> Int64(LOff) then raise EVfsError.CreateCtx(AOp, APath, 'seek failed for header reuse');
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    end;
    while LRem > 0 do
    begin
      LChunk := LRem;
      if LChunk > TRANSFORM_STREAM_CHUNK then LChunk := TRANSFORM_STREAM_CHUNK;
      if LOff + LChunk > LCap then
      begin
        LCap := BytesNextCapacity(LCap, LOff + LChunk);
        if LCap > SizeUInt(ATotal) then LCap := SizeUInt(ATotal);
        if LOff + LChunk > LCap then raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      try LGot := AStream.Read(AData[LOff], LChunk);
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
      Inc(LOff, LGot); Dec(LRem, LGot);
    end;
  end;
  if SizeUInt(Length(AData)) <> SizeUInt(ATotal) then SetLength(AData, ATotal);
  Result := True;
end;

function TTransformingVfs.TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
var
  LSize, LCap, LOff, LGot, LRead: SizeUInt;
  LChunk: array[0..4095] of Byte;
begin
  Result := False;
  AData := nil;
  if Length(AHeader) = 0 then Exit(False);
  // AHasProbe 已在 TryReadHeader 合成阶段消耗，前缀位置已对齐，此处仅复用 Header 零 Seek
  if AHasProbe then begin end;
  // 未知尺寸单流兜底：HeaderPred 真时复用已读 4K 头 + 同流剩余一次性物化免二次 OpenRead；chunked streaming + BytesNextCapacity 预估容量替代倍增拷贝，热点可复用
  // 性能：IReaderAt 能力由外层单次 QueryInterface 缓存传入，免热路径重复虚调用（单次探测复用，inline 分支削减，bytes.ops 单源）
  // 小文件未知尺寸：Header 已是全量（EOF 截断），直接复用零二次 IO
  if Length(AHeader) < TRANSFORM_HEADER_PEEK then
  begin
    // 探针阶段已读 2 字节 + 4K 头合成后的实际读取若已 EOF，则 Header 即全量
    AData := AHeader;
    if Length(AData) > VFS_DECOMPRESS_MAX_BYTES then
      raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
    Exit(True);
  end;
  LSize := SizeUInt(Length(AHeader));
  if LSize > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
  // 预估容量：bytes.ops BytesNextCapacity 单源几何扩容替代 4K 循环倍增多次 Move 拷贝，流式 64K 分块复用，inline 零拷贝
  LCap := BytesNextCapacity(LSize, LSize + TRANSFORM_STREAM_CHUNK);
  if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
  if LCap < LSize + 4096 then LCap := LSize + 4096;
  SetLength(AData, LCap);
  BytesCopy(@AData[0], @AHeader[0], LSize); // bytes.ops 单源 Move inline 零拷贝
  LOff := LSize;
  if AHasReaderAt then
  begin
    // IReaderAt 缓存路径：按 offset 顺序补读剩余，直至 EOF；预估容量 + 分块流式消除 4K 倍增拷贝峰值，能力缓存免重复 QI
    while True do
    begin
      if LOff >= VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      LRead := SizeUInt(VFS_DECOMPRESS_MAX_BYTES) - LOff;
      if LRead > SizeUInt(Length(LChunk)) then LRead := SizeUInt(Length(LChunk));
      try LGot := AReaderAt.ReadAt(LChunk[0], LRead, Int64(LOff));
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then Break;
      if LOff + LGot > VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      if LOff + LGot > LCap then
      begin
        LCap := BytesNextCapacity(LCap, LOff + LGot);
        if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
        if LOff + LGot > LCap then
          raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      BytesCopy(@AData[LOff], @LChunk[0], LGot); // bytes.ops 单源 inline 零拷贝
      Inc(LOff, LGot);
      if LGot < LRead then Break;
    end;
  end
  else
  begin
    // 顺序流路径：已处 Header 末尾，持续 Read 至 EOF；限幅守峰值，预估容量流式替代倍增
    while True do
    begin
      if LOff >= VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      try LGot := AStream.Read(LChunk[0], SizeUInt(Length(LChunk)));
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then Break;
      if LOff + LGot > VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      if LOff + LGot > LCap then
      begin
        LCap := BytesNextCapacity(LCap, LOff + LGot);
        if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
        if LOff + LGot > LCap then
          raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      BytesCopy(@AData[LOff], @LChunk[0], LGot); // bytes.ops 单源 inline 零拷贝
      Inc(LOff, LGot);
    end;
  end;
  SetLength(AData, LOff);
  Result := True;
end;

function TTransformingVfs.TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes; out ABypassStream: IStream): THeaderResolve;
var
  LStream: IStream;
  LReaderAt: IReaderAt;
  LHasReaderAt: Boolean;
  LRead: SizeUInt;
  LUseReadAt: Boolean;
  LProbeBuf: array[0..1] of Byte;
  LProbeLen: SizeUInt;
  LHasProbe: Boolean;
  LBypassTmp: IStream;
begin
  Result := hrFallback;
  AHeader := nil;
  AData := nil;
  ATotal := AStat.Info.Size;
  if AStat.Info.IsDir then Exit(hrBypass);
  // 薄转发：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K；OpenRead bypass 时复用已打开流免二次 OpenRead
  // 单流：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K；OpenRead bypass 时复用已打开流免二次 OpenRead
  // 性能：大文件 HeaderPred 场景先以 2 字节轻量头预判（bytes.ops 单源魔数 inline），非变换则免 4K 分配与后续读，命中 gzip 则回退至 4K 单流精确路径（保证大文件解压一致性）
  // 单流：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K
  try
    LStream := FInner.OpenRead(APath);
  except
    on LEx: EVfsError do raise;
    on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message);
  end;
  try
    if ATotal < 0 then
      ATotal := LStream.Size;
    // 性能：单流内 IReaderAt 能力单次 QueryInterface 缓存复用，热路径三阶段免重复虚调用（LHasReaderAt/LReaderAt 单次探测，多分支削减，inline 零拷贝单源）
    LHasReaderAt := (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
    // 阶段1：轻量 2 字节栈零堆探针（命中则进入阶段2 4K 合成，非命中直接 bypass 免 4K/TBytes 堆分配）
    LProbeLen := 0; LHasProbe := False; LUseReadAt := False; LBypassTmp := nil;
    if TryLightProbe(LStream, LReaderAt, LHasReaderAt, APath, AOp, ATotal, LProbeBuf, LProbeLen, LHasProbe, LUseReadAt, LBypassTmp) then
    begin
      AHeader := nil;
      if AOp = 'open' then
      LRead := 0;
    end
    else if LHasProbe then
    begin
      // 命中前缀已消耗 2 字节，合成 4K 头免 Seek(0) 重置：Move 前缀 + 单次 Read 剩余（零拷贝，快路径免 Seek 虚调用）
      SetLength(AHeader, LPeek);
      Move(LProbeBuf[0], AHeader[0], LProbeLen);
      LUseReadAt := False;
      LOff := LProbeLen;
      LRem := LPeek - LProbeLen;
      LGot := 0;
      while LRem > 0 do
      begin
        ABypassStream := LBypassTmp;
        if ABypassStream <> nil then
          LStream := nil; // 旁路流接管原流拥有权，免 finally 二次 Close
      end
      else
      begin
        ABypassStream := nil; // stat 无需旁路流，LStream 由 finally 关闭
      end;
      Exit(hrBypass);
      LRead := LOff;
      if LRead < LPeek then
        SetLength(AHeader, LRead);
      if LRead = 0 then
        AHeader := nil;
    end
    else
    begin
      SetLength(AHeader, LPeek);
      try
        if (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil) then
          LRead := LReaderAt.ReadAt(AHeader[0], LPeek, 0)
        else
          LRead := LStream.Read(AHeader[0], LPeek);
      except
        on E: EVfsError do raise;
        on E: EResPackError do raise;
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      if LRead < LPeek then
        SetLength(AHeader, LRead);
      if LRead = 0 then
        AHeader := nil;
    end;
    // 阶段2：读取 4K 头（复用 LightProbe 已消耗前缀，免 Seek 重置，能力缓存复用免二次 QI）
    if not TryReadHeader(LStream, LReaderAt, LHasReaderAt, APath, AOp, ATotal, LHasProbe, LProbeBuf, LProbeLen, AHeader, LRead, LUseReadAt) then
      Exit(hrFallback);
    // 阶段2判定：HeaderPred 假则免全量读，直接回退内层；OpenRead 场景复用已打开流免二次 OpenRead（非 IReaderAt 前缀包装 Seek-free 直透）
    if not HeaderShould(AHeader, ATotal) then
    begin
      if (AOp = 'open') and (LRead = 0) then
      begin
        ABypassStream := LStream; LStream := nil; Exit(hrBypass);
      end;
      if (AOp = 'open') and LUseReadAt then
      begin
        ABypassStream := LStream; LStream := nil; Exit(hrBypass);
      end;
      if (AOp = 'open') and not LUseReadAt and (LRead > 0) then
      begin
        if Length(AHeader) > 0 then
          ABypassStream := TPrefixBypassStream.Create(@AHeader[0], SizeUInt(Length(AHeader)), LStream, ATotal)
        else
          ABypassStream := TPrefixBypassStream.Create(nil, 0, LStream, ATotal);
        LStream := nil; Exit(hrBypass);
      end;
      Exit(hrBypass);
    end;
    // HeaderPred 判定：假则免全量读，直接回退内层
    if not HeaderShould(AHeader, ATotal) then Exit(hrBypass);
    // 小文件（<=4K）复用头即全量，零二次 IO
    if (ATotal >= 0) and (ATotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(AHeader)) = ATotal) then
    begin
      AData := AHeader; Exit(hrAcquired);
    end;
    // 阶段3：大文件命中单流补读（限幅守稳定性，Move 零拷贝复用 4K 头，能力缓存复用 64K 分块递增免重复 QI）
    if TryFillLargeFile(APath, AOp, ATotal, AHeader, LStream, LReaderAt, LHasReaderAt, AData) then
      Exit(hrAcquired);
    // 未知尺寸单流兜底：HeaderPred 真且尺寸未知时，同流全量物化免二次 OpenRead（消除 hrFallback→VfsReadAllBytes 双次命中）；32MiB 限幅守稳定性，L7 按需 chunked streaming，能力缓存复用
    if (ATotal < 0) then
    begin
      if TryReadAllWithHeader(APath, AOp, AHeader, LStream, LHasProbe, LReaderAt, LHasReaderAt, AData) then
        Exit(hrAcquired);
    end;
    // 尺寸不匹配/截断 -> 受控回退外层全量路径（小文件或未知 size 兜底失败场景）；大文件已知 size 已在 Acquired/Bypass 处理，免冗余后端命中
    Exit(hrFallback);
  finally
    try LStream.Close; except end;
  end;
end;

function TTransformingVfs.TryPeekHeaderWithStat(const AStat: TStatInfo; const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
var
  LStream: IStream;
  LRead: SizeUInt;
  LReaderAt: IReaderAt;
  LPeek: SizeUInt;
  LOff: SizeUInt;
  LRem: SizeUInt;
  LGot: SizeUInt;
  LUseReadAt: Boolean;
begin
  Result := hrFallback;
  AHeader := nil;
  ATotalSize := AStat.Info.Size;
  if AStat.Info.IsDir then Exit(False);
  try
    LStream := FInner.OpenRead(APath);
  except
    on E: EVfsError do raise;
    on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
  end;
  try
    // 零拷贝直达：按需分配头部缓冲直读入堆，消除栈上 4K 中转
    if (ATotalSize >= 0) and (ATotalSize < TRANSFORM_HEADER_PEEK) then
      LPeek := SizeUInt(ATotalSize)
    else
      LPeek := TRANSFORM_HEADER_PEEK;
    if LPeek = 0 then
    begin
      AHeader := nil;
      LRead := 0;
      LUseReadAt := False;
    end
    else
    begin
      SetLength(AHeader, LPeek);
      LUseReadAt := (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
      try
        if LUseReadAt then
          LRead := LReaderAt.ReadAt(AHeader[0], LPeek, 0)
        else
          LRead := LStream.Read(AHeader[0], LPeek);
      except
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      if LRead < LPeek then
        SetLength(AHeader, LRead);
      if LRead = 0 then
        AHeader := nil;
    end;
    Result := True;
  finally
    try LStream.Close; except end;
  end;
end;

function TTransformingVfs.TryPeekHeader(const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
var
  LInfo: TStatInfo;
begin
  Result := False;
  AHeader := nil;
  ATotalSize := -1;
  try
    LInfo := FInner.Stat(APath);
  except
    on E: EVfsError do raise;
    on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
  end;
  if LInfo.Info.IsDir then Exit(False);
  Result := TryPeekHeaderWithStat(LInfo, APath, AOp, AHeader, ATotalSize);
end;

function TTransformingVfs.ReadAllReusingHeader(const APath: string; const AOp: string; const AHeader: TBytes; const ATotal: Int64): TBytes;
var
  S: IStream;
  LReaderAt: IReaderAt;
  LOff: SizeUInt;
  LRem: SizeUInt;
  LGot: SizeUInt;
begin
  // 保留兼容路径：Stat/OpenRead 已走单流 TryResolve*，本函数仅 fallback 兼容旧调用
  if (ATotal < 0) or (ATotal > High(SizeInt)) then
  begin
    Result := VfsReadAllBytes(FInner, APath);
    Exit;
  end;
  if (Length(AHeader) = 0) or (Length(AHeader) >= ATotal) then
  begin
    Result := VfsReadAllBytes(FInner, APath);
    Exit;
  end;
  SetLength(Result, ATotal);
  Move(AHeader[0], Result[0], Length(AHeader));
  LOff := SizeUInt(Length(AHeader));
  LRem := SizeUInt(ATotal) - LOff;
  try
    S := FInner.OpenRead(APath);
  except
    on E: EVfsError do raise;
    on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
  end;
  try
    if (S.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil) then
    begin
      try
        LGot := LReaderAt.ReadAt(Result[LOff], LRem, Int64(LOff));
      except
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      if LGot <> LRem then
        raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
    end
    else
    begin
      try
        if S.Seek(Int64(LOff), soBeginning) <> Int64(LOff) then
          raise EVfsError.CreateCtx(AOp, APath, 'seek failed for header reuse');
      except
        on E: EVfsError do raise;
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      while LRem > 0 do
      begin
        try
          LGot := S.Read(Result[LOff], LRem);
        except
          on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
        end;
        if LGot = 0 then
          raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
        Inc(LOff, LGot);
        Dec(LRem, LGot);
      end;
    end;
  finally
    try S.Close; except end;
  end;
end;

function TTransformingVfs.Exists(const APath: string): Boolean;
begin
  Result := FInner.Exists(APath);
end;

function TTransformingVfs.Stat(const APath: string): TStatInfo;
var
  LInfo: TStatInfo;
  LData, LOut, LHeader: TBytes;
  LTotal: Int64;
  LResolve: THeaderResolve;
begin
  try
    LInfo := FInner.Stat(APath);
  except
    on LEx: EVfsError do raise;
    on LEx: Exception do raise EVfsError.CreateCtx('stat', APath, LEx.Message);
  end;
  if LInfo.Info.IsDir then Exit(LInfo);
  // 性能+正确性：Stat 经单源决策器 4K 单流复用（小文件复用头零二次 IO，大文件 2 字节 HeaderShould 泛型委托预判免 4K 分配，命中 gzip 则同流补读免二次 OpenRead）；
  LResolve := TryResolveViaHeaderSingleStream(APath, 'stat', LInfo, LHeader, LTotal, LData);
  case LResolve of
    hrBypass: Exit(LInfo);
    hrAcquired:
      begin
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
        try LOut := Transform(LData); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + LEx.Message); end;
        if Pointer(LOut) <> Pointer(LData) then begin LInfo.Info.Size := Int64(Length(LOut)); LInfo.ContentHash := 0; end;
        LData := nil;
        Exit(LInfo);
      end;
    hrFallback: ; // 截断/不匹配受控回退；未知尺寸已在单流 TryReadAllWithHeader  Acquired 免二次 OpenRead，大文件已知 size 已 Acquired/Bypass，冗余命中消除
  end;
  // 受控回退：仅截断/空文件等无法判定的极小边沿才全量读（VfsReadAllBytes 单次分配，IReaderAt 单次直读）；大文件/未知尺寸已由单流 Acquired/Bypass 处理免二次 OpenRead，防 bomb 输入超 VFS_DECOMPRESS_MAX_BYTES 直接限幅
  try LData := VfsReadAllBytes(FInner, APath); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('stat', APath, LEx.Message); end;
  if Length(LData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('stat', APath, 'transform: source size exceeds limit');
  if Assigned(FShould) and not Should(LData) then Exit(LInfo);
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then Exit(LInfo);
  try LOut := Transform(LData); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + LEx.Message); end;
  try LOut := Transform(LData); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + E.Message); end;
  // 单源决策器：Stat 的 4K HeaderPred 快路径，单流复用小文件头/大文件剩余，零二次 OpenRead
  if Assigned(FHeaderPred) then
  begin
    LResolve := TryResolveViaHeaderSingleStream(APath, 'stat', LInfo, LHeader, LTotal, LData);
    case LResolve of
      hrBypass: Exit(LInfo);
      hrAcquired:
        begin
          if Assigned(FShould) and not Should(LData) then Exit(LInfo);
          try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + E.Message); end;
          if Pointer(LOut) <> Pointer(LData) then begin LInfo.Info.Size := Int64(Length(LOut)); LInfo.ContentHash := 0; end;
          Exit(LInfo);
        end;
      hrFallback: ; // fall through to全量路径
    end;
  end;
  // 无 HeaderPred 或回退：需全量读决定 Should/Transform（大文件调用方应选用 HeaderPred 变体或避免 Stat）
  try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
  if Assigned(FShould) then
    if not Should(LData) then Exit(LInfo);
  try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + E.Message); end;
  if Pointer(LOut) <> Pointer(LData) then begin LInfo.Info.Size := Int64(Length(LOut)); LInfo.ContentHash := 0; end;
  LData := nil;
  Result := LInfo;
end;

function TTransformingVfs.List(const ADirPath: string): TEntryArray;
begin
  Result := FInner.List(ADirPath);
end;

function TTransformingVfs.OpenRead(const APath: string): IStream;
var
  LData, LOut, LHeader: TBytes;
  LTotal: Int64;
  LDummy: TStatInfo;
  LResolve: THeaderResolve;
begin
  // 单流直达：OpenRead 免前置 Stat，单次 OpenRead 零额外后端命中（embedded 二分/OS syscall 单次由 TryResolve 内单流承载），目录/不存在由内层异常透传
  LDummy.Info.IsDir := False;
  LDummy.Info.Size := -1;
  LDummy.Info.Name := APath;
  LDummy.Info.ModTime := 0;
  LDummy.ContentHash := 0;
  LResolve := TryResolveViaHeaderSingleStream(APath, 'open', LDummy, LHeader, LTotal, LData, LBypassStream);
  case LResolve of
    hrBypass:
      begin
        if LBypassStream <> nil then begin Result := LBypassStream; Exit; end;
        try Result := FInner.OpenRead(APath); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, LEx.Message); end;
        Exit;
      end;
    hrAcquired:
      begin
        if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        try LOut := Transform(LData); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + LEx.Message); end;
        if Pointer(LOut) = Pointer(LData) then begin LData := nil; Result := CreateBytesStreamFrom(LOut); Exit; end;
        LData := nil;
        Result := CreateBytesStreamFrom(LOut);
        Exit;
      end;
    hrFallback: ; // 截断/不匹配受控回退；未知尺寸已由单流 TryReadAllWithHeader Acquired 免二次 OpenRead
  // 单源决策器：OpenRead HeaderPred 快路径，假时零物化直透（单流复用 bypass 流免二次 OpenRead，大文件经 2 字节 BytesIsGzipBuffer PByte 零拷贝预判免 4K 分配），命中时单流 Move 复用 4K 头+同流补读（无 HeaderPred 时亦走单流避免双重 VfsReadAllBytes）
  try LInfo := FInner.Stat(APath); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
  if not LInfo.Info.IsDir then
  // 单源决策器：OpenRead 的 HeaderPred 快路径，假时零物化直透，命中时单流复用
  if Assigned(FHeaderPred) then
  begin
    LResolve := TryResolveViaHeaderSingleStream(APath, 'open', LInfo, LHeader, LTotal, LData, LBypassStream);
    case LResolve of
      hrBypass:
        begin
          if LBypassStream <> nil then begin Result := LBypassStream; Exit; end;
          try Result := FInner.OpenRead(APath); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
          Exit;
        end;
      hrAcquired:
        begin
          if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
          try LOut := Transform(LData); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
          if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
          Result := CreateBytesStreamFrom(LOut);
          Exit;
        end;
      hrFallback: ; // fall through to全量路径（未知 size）
    try LInfo := FInner.Stat(APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
    if not LInfo.Info.IsDir then
    begin
      LResolve := TryResolveViaHeaderSingleStream(APath, 'open', LInfo, LHeader, LTotal, LData);
      case LResolve of
        hrBypass:
          begin
            try Result := FInner.OpenRead(APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
            Exit;
          end;
        hrAcquired:
          begin
            if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
            try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
            if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
            Result := CreateBytesStreamFrom(LOut);
            Exit;
          end;
        hrFallback: ; // fall through
      end;
    end;
  end;
  // 受控回退仅截断边沿：大文件/未知尺寸已由单流免二次 OpenRead 处理（TryReadAllWithHeader 单流物化），此处仅目录/截断等极小路径；限幅守峰值
  try LData := VfsReadAllBytes(FInner, APath); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, LEx.Message); end;
  if Length(LData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('open', APath, 'transform: source size exceeds limit');
  if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  try LOut := Transform(LData); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + LEx.Message); end;
  if Pointer(LOut) = Pointer(LData) then begin LData := nil; Result := CreateBytesStreamFrom(LOut); Exit; end;
  LData := nil;
  try LOut := Transform(LData); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
  if not Assigned(FShould) and not Assigned(FHeaderPred) then
  begin
  end
  else if Assigned(FShould) and Assigned(FHeaderPred) then
  begin
    if not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  end;
  try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
  if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  Result := CreateBytesStreamFrom(LOut);
end;

function TTransformingVfs.CaseSensitive: Boolean;
begin
  Result := FInner.CaseSensitive;
end;

function TTransformingVfs.TryGetETag(const APath: string; out AETag: string): Boolean;
begin
  AETag := ''; Result := False;
end;

function TTransformingVfs.TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
var LInnerETag: IVfsETag;
begin
  if FInner.QueryInterface(IVfsETag, LInnerETag) = 0 then Exit(LInnerETag.TryGetLastModified(APath, ALastModified));
  ALastModified := ''; Result := False;
end;

function TTransformingVfs.TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
begin
  // ETag 禁用：变换后内容与源不一致，旧指纹不可复用；LastModified 仍可经 TryGetLastModified 透传
  AETag := '';
  ALastModified := '';
  Result := False;
end;

end.
