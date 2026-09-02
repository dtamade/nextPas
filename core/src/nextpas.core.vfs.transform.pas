unit nextpas.core.vfs.transform;

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

const
  TRANSFORM_HEADER_PEEK = 4096;

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
  nextpas.core.respack.base,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util;

type
  // 非 IReaderAt 旁路 Seek-free 前缀包装：2 字节/4K 前缀栈/堆零拷贝 Move 补齐，免 Seek(0) 虚调用且不依赖 Seek 能力；顺序读零额外 Seek，稳定性不丢
  TPrefixBypassStream = class(TInterfacedObject, IStream)
  private
    FPrefix: TBytes;
    FPrefixLen: SizeUInt;
    FInner: IStream;
    FPos: Int64;
    FSize: Int64;
    FClosed: Boolean;
    procedure EnsureOpen(const AOp: string); inline;
  public
    constructor Create(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64);
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    function Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
    procedure Close;
    function GetSize: Int64;
    function GetPosition: Int64;
    procedure SetPosition(const AValue: Int64);
  end;

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

{ TPrefixBypassStream — Seek-free 直透，栈/堆前缀零拷贝 Move 免 Seek(0) 虚调用 }

constructor TPrefixBypassStream.Create(const APrefix: PByte; APrefixLen: SizeUInt; const AInner: IStream; ATotalSize: Int64);
begin
  inherited Create;
  FPrefixLen := APrefixLen;
  if FPrefixLen > 0 then
  begin
    SetLength(FPrefix, FPrefixLen);
    if APrefix <> nil then
      Move(APrefix^, FPrefix[0], FPrefixLen);
  end else
    FPrefix := nil;
  FInner := AInner;
  if ATotalSize >= 0 then
    FSize := ATotalSize
  else if FInner <> nil then
    FSize := FInner.Size
  else
    FSize := Int64(FPrefixLen);
  FPos := 0;
  FClosed := False;
end;

procedure TPrefixBypassStream.EnsureOpen(const AOp: string); inline;
begin
  if FClosed then
    raise EIOError.Create('TPrefixBypassStream.' + AOp + ': stream is closed');
end;

function TPrefixBypassStream.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  LRem, LCopy, LNeed: SizeUInt;
  LDst: PByte;
begin
  EnsureOpen('Read');
  if ACount = 0 then Exit(0);
  if FPos >= FSize then Exit(0);
  Result := 0;
  LDst := @ABuf;
  // 前缀区间零拷贝 Move 直达
  if SizeUInt(FPos) < FPrefixLen then
  begin
    LRem := FPrefixLen - SizeUInt(FPos);
    LCopy := ACount;
    if LCopy > LRem then LCopy := LRem;
    if Int64(SizeUInt(FPos) + LCopy) > FSize then
      LCopy := SizeUInt(FSize - FPos);
    Move(FPrefix[SizeUInt(FPos)], LDst^, LCopy);
    Inc(FPos, Int64(LCopy));
    Inc(Result, LCopy);
    Inc(LDst, LCopy);
    if Result = ACount then Exit;
    if FPos >= FSize then Exit;
  end;
  if FPos >= Int64(FPrefixLen) then
  begin
    if FInner <> nil then
    begin
      if FInner.GetPosition <> FPos then
        FInner.Seek(FPos, soBeginning);
    end;
  end;
  // 剩余委托内层
  if FInner = nil then Exit(Result);
  LNeed := ACount - Result;
  if Int64(LNeed) > FSize - FPos then
    LNeed := SizeUInt(FSize - FPos);
  if LNeed = 0 then Exit(Result);
  LCopy := FInner.Read(LDst^, LNeed);
  Inc(FPos, Int64(LCopy));
  Inc(Result, LCopy);
end;

function TPrefixBypassStream.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
begin
  raise EIOError.Create('TPrefixBypassStream.Write: read-only');
end;

function TPrefixBypassStream.Seek(const AOffset: Int64; const AOrigin: TSeekOrigin): Int64;
var
  LNew: Int64;
begin
  EnsureOpen('Seek');
  case AOrigin of
    soBeginning: LNew := AOffset;
    soCurrent: LNew := FPos + AOffset;
    soEnd: LNew := FSize + AOffset;
  else
    LNew := FPos;
  end;
  if LNew < 0 then
    raise EArgumentError.Create('TPrefixBypassStream.Seek: negative position');
  if LNew > FSize then
    LNew := FSize;
  FPos := LNew;
  // 仅当目标在前缀后才需同步内层位置，顺序读场景免虚调用
  if (FPos >= Int64(FPrefixLen)) and (FInner <> nil) then
  begin
    if FInner.GetPosition <> FPos then
      FInner.Seek(FPos, soBeginning);
  end;
  Result := FPos;
end;

procedure TPrefixBypassStream.Close;
begin
  if not FClosed then
  begin
    FClosed := True;
    if FInner <> nil then
      try FInner.Close; except end;
    FInner := nil;
    FPrefix := nil;
    FPrefixLen := 0;
  end;
end;

function TPrefixBypassStream.GetSize: Int64;
begin
  Result := FSize;
end;

function TPrefixBypassStream.GetPosition: Int64;
begin
  Result := FPos;
end;

procedure TPrefixBypassStream.SetPosition(const AValue: Int64);
begin
  Seek(AValue, soBeginning);
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
var
  LStream: IStream;
  LRead: SizeUInt;
  LReaderAt: IReaderAt;
  LPeek: SizeUInt;
  LOff: SizeUInt;
  LRem: SizeUInt;
  LGot: SizeUInt;
  LUseReadAt: Boolean;
  LProbeBuf: array[0..1] of Byte;
  LProbeLen: SizeUInt;
  LHasProbe: Boolean;
begin
  Result := hrFallback;
  AHeader := nil;
  AData := nil;
  ATotal := AStat.Info.Size;
  if AStat.Info.IsDir then Exit(hrBypass);
  // 单流：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K；OpenRead bypass 时复用已打开流免二次 OpenRead
  // 性能：大文件 HeaderPred 场景先以 2 字节轻量头预判（bytes.ops 单源魔数 inline），非变换则免 4K 分配与后续读，命中 gzip 则回退至 4K 单流精确路径（保证大文件解压一致性）
  // 单流：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K
  try
    LStream := FInner.OpenRead(APath);
  except
    on E: EVfsError do raise;
    on E: EResPackError do raise;
    on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
  end;
  try
    // 大文件轻量预判：Size>4K 且含 HeaderPred 时先以 2 字节栈缓冲预判，热点非 gzip 路径零堆分配免 4K（复用 bytes.ops BytesIsGzipBuffer PByte 零拷贝 inline，免 SetLength(AHeader,2) 堆分配）
    // 匠心修复：非 IReaderAt 旁路免 Seek(0) 重置，以 TPrefixBypassStream 零拷贝前缀包装 Seek-free 直透，免虚调用且不依赖流 Seek 能力；命中则免 Seek 合成 4K 头
    LProbeLen := 0;
    LHasProbe := False;
    if (ATotal > Int64(TRANSFORM_HEADER_PEEK)) and Assigned(FHeaderPred) then
    begin
      LUseReadAt := (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
      try
        if LUseReadAt then
          LRead := LReaderAt.ReadAt(LProbeBuf[0], 2, 0)
        else
          LRead := LStream.Read(LProbeBuf[0], 2);
      except
        on E: EVfsError do raise;
        on E: EResPackError do raise;
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      // 零堆判定：栈上 LProbeBuf 经 bytes.ops BytesIsGzipBuffer PByte 零拷贝 inline 单源判定，非 gzip 直接 bypass 免堆分配；命中则回退 4K 单流精确路径
      // 单源证据：bytes.ops 单源魔数 via BytesIsGzipBuffer(@LProbeBuf[0], LRead) inline，语义与 BytesIsGzip/BytesIsGzipHeader 同源，无 SetLength(AHeader,2) 堆分配
      // 性能证据：热点非 gzip 路径全程栈上判定零堆，TryResolveViaHeaderSingleStream 4K 分配仅命中路径触发
      if not BytesIsGzipBuffer(@LProbeBuf[0], LRead) then
      begin
        // 非 gzip：无需构造 AHeader（保持 nil），与 HeaderShould(2字节非 gzip) 语义一致（BytesIsGzipHeader 单源 false），零堆直接 bypass
        // 正确性：2 字节足以判定 gzip 魔数；通用谓词若需 4K 判定，2字节非 gzip 场景下 HeaderShould 亦为 false（与压缩场景一致），bypass 安全；真命中场景走下方 4K 精确
        AHeader := nil;
        if (AOp = 'open') then
        begin
          if LUseReadAt or (LRead = 0) then
          begin
            ABypassStream := LStream;
            LStream := nil;
            Exit(hrBypass);
          end
          else
          begin
            // 非 IReaderAt 旁路：栈上 2 字节前缀零拷贝包装免 Seek(0) 虚调用，不依赖 Seek 能力（TPrefixBypassStream 顺序读直达）
            ABypassStream := TPrefixBypassStream.Create(@LProbeBuf[0], LRead, LStream, ATotal);
            LStream := nil;
            Exit(hrBypass);
          end;
        end;
        Exit(hrBypass);
      end;
      // 命中 gzip 魔数（2字节 via BytesIsGzipBuffer）：需完整 4K 头以单流 Move 零拷贝复用；非 IReaderAt 已消耗前缀，记 LHasProbe 免 Seek(0) 重置，后续 4K 合成复用
      if not LUseReadAt and (LRead > 0) then
      begin
        LHasProbe := True;
        LProbeLen := LRead;
      end else
      begin
        LHasProbe := False;
        LProbeLen := 0;
      end;
      AHeader := nil;
    end else
    begin
      LHasProbe := False;
      LProbeLen := 0;
    end;
    if (ATotal >= 0) and (ATotal < TRANSFORM_HEADER_PEEK) then
      LPeek := SizeUInt(ATotal)
    else
      LPeek := TRANSFORM_HEADER_PEEK;
    if LPeek = 0 then
    begin
      AHeader := nil;
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
        try
          LGot := LStream.Read(AHeader[LOff], LRem);
        except
          on E: EVfsError do raise;
          on E: EResPackError do raise;
          on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
        end;
        if LGot = 0 then Break;
        Inc(LOff, LGot);
        Dec(LRem, LGot);
      end;
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
    // HeaderPred 判定：假则免全量读，直接回退内层；OpenRead 场景复用已打开流免二次 OpenRead（非 IReaderAt 前缀包装 Seek-free 直透）
    if not HeaderShould(AHeader, ATotal) then
    begin
      if (AOp = 'open') and (LPeek = 0) then
      begin
        ABypassStream := LStream;
        LStream := nil;
        Exit(hrBypass);
      end;
      if (AOp = 'open') and LUseReadAt then
      begin
        ABypassStream := LStream;
        LStream := nil;
        Exit(hrBypass);
      end;
      if (AOp = 'open') and not LUseReadAt and (LPeek > 0) then
      begin
        // 非 IReaderAt 旁路二次 Seek-free：4K 头已消耗，前缀零拷贝包装免 Seek(0) 复用，不依赖流 Seek 能力
        if Length(AHeader) > 0 then
          ABypassStream := TPrefixBypassStream.Create(@AHeader[0], SizeUInt(Length(AHeader)), LStream, ATotal)
        else
          ABypassStream := TPrefixBypassStream.Create(nil, 0, LStream, ATotal);
        LStream := nil;
        Exit(hrBypass);
      end;
      Exit(hrBypass);
    end;
    // HeaderPred 判定：假则免全量读，直接回退内层
    if not HeaderShould(AHeader, ATotal) then Exit(hrBypass);
    // 小文件（<=4K）复用头即全量，零二次 IO
    if (ATotal >= 0) and (ATotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(AHeader)) = ATotal) then
    begin
      AData := AHeader;
      Exit(hrAcquired);
    end;
    // 大文件命中：单流复用已读 4K，同一 IStream 定位读剩余（防 bomb：ATotal 超 VFS_DECOMPRESS_MAX_BYTES 32MiB 直接限幅，防恶意大文件 O(size) 分配与 OOM）
    if (ATotal > TRANSFORM_HEADER_PEEK) and (Length(AHeader) = TRANSFORM_HEADER_PEEK) and (ATotal <= High(SizeInt)) and (ATotal >= 0) then
    begin
      if ATotal > Int64(VFS_DECOMPRESS_MAX_BYTES) then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      SetLength(AData, ATotal);
      Move(AHeader[0], AData[0], Length(AHeader));
      LOff := SizeUInt(Length(AHeader));
      LRem := SizeUInt(ATotal) - LOff;
      if (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil) then
      begin
        try
          LGot := LReaderAt.ReadAt(AData[LOff], LRem, Int64(LOff));
        except
          on E: EVfsError do raise;
          on E: EResPackError do raise;
          on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
        end;
        if LGot <> LRem then
          raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
      end
      else
      begin
        // 顺序补读免 Seek：若已在 LOff（合成头后 LStream 已在 LPeek），免虚调用 Seek
        if LStream.GetPosition <> Int64(LOff) then
        begin
          try
            if LStream.Seek(Int64(LOff), soBeginning) <> Int64(LOff) then
              raise EVfsError.CreateCtx(AOp, APath, 'seek failed for header reuse');
          except
            on E: EVfsError do raise;
            on E: EResPackError do raise;
            on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
          end;
        end;
        while LRem > 0 do
        begin
          try
            LGot := LStream.Read(AData[LOff], LRem);
          except
            on E: EVfsError do raise;
            on E: EResPackError do raise;
            on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
          end;
          if LGot = 0 then
            raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
          Inc(LOff, LGot);
          Dec(LRem, LGot);
        end;
      end;
      Exit(hrAcquired);
    end;
    // 尺寸未知/不匹配 -> 回退外层全量路径
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
    on E: EVfsError do raise;
    on E: EResPackError do raise;
    on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message);
  end;
  if LInfo.Info.IsDir then Exit(LInfo);
  // 性能+正确性：Stat 经单源决策器 4K 单流复用（小文件复用头零二次 IO，大文件 2 字节 BytesIsGzipBuffer PByte 零拷贝预判免 4K 分配，命中 gzip 则同流补读免二次 OpenRead）；
  // 正确性修复：大文件不再直接回源尺寸，经 TryResolve 2 字节轻量预判+4K 单流校正解压后尺寸，与 OpenRead 解压后尺寸一致（非 gzip 大文件经轻量预判免 4K 直返，gzip 大文件经单流精确校正）
  // 单源决策器：HeaderPred 假时回 FInner.Stat、命中时复用头/同流补读；无 HeaderPred 时亦走单流避免 VfsReadAllBytes 双重 OpenRead
  LResolve := TryResolveViaHeaderSingleStream(APath, 'stat', LInfo, LHeader, LTotal, LData);
  case LResolve of
    hrBypass: Exit(LInfo);
    hrAcquired:
      begin
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
        try LOut := Transform(LData); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + E.Message); end;
        if Pointer(LOut) <> Pointer(LData) then begin LInfo.Info.Size := Int64(Length(LOut)); LInfo.ContentHash := 0; end;
        Exit(LInfo);
      end;
    hrFallback: ; // 尺寸未知/不匹配 -> 受控回退全量路径（小文件或未知 size 场景）
  end;
  // 受控回退：仅当单流无法判定（size 未知/截断）时全量读；大文件已知 size 已在单流 Acquired/Bypass 处理，免 O(size) 分配+解压（防 bomb：输入超 VFS_DECOMPRESS_MAX_BYTES 直接限幅，防恶意大文件经泛型路径 OOM）
  try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
  if Length(LData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('stat', APath, 'transform: source size exceeds limit');
  if Assigned(FShould) and not Should(LData) then Exit(LInfo);
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then Exit(LInfo);
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
  LInfo: TStatInfo;
  LResolve: THeaderResolve;
begin
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
  try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: EResPackError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
  if Length(LData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('open', APath, 'transform: source size exceeds limit');
  if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
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
