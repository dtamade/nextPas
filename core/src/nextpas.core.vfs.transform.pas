unit nextpas.core.vfs.transform;

{** @desc L3 单缝装饰器寄居 L2 家族：通用字节变换视图（ADR 0003）。
  层级：L3→L2 单向 via bytes.ops/vfs.base 单源（无 L2→L2 闭环）；Registry 单缝白名单过渡，L7 拆分为 nextpas.core.vfs.decorator 独立 L3 族后移除白名单固化 L0-L3 单向；可抽新模块候选，复用阻塞已显式标注。
  单源/性能：bytes.ops HeaderPred inline 零拷贝 + VFS_DECOMPRESS_MAX_BYTES 单源 32MiB 双阈值限幅；单流复用 4K 头 Move 零拷贝免二次 OpenRead，热点 2 字节栈探针零堆分配；稳定性 try-finally Close 不丢。 }

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
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util;

const
  TRANSFORM_HEADER_PEEK = 4096;

type
  // 可抽新模块候选：通用前缀旁路流 nextpas.core.io.prefix（L7 可拆分为独立可复用装饰器，供 io/os/embedded 复用）；当前寄居 transform 最小改动，复用阻塞候选。
  // 非 IReaderAt 旁路 Seek-free 前缀包装：2 字节/4K 前缀零拷贝 Move 补齐，免 Seek(0) 虚调用；顺序读零额外 Seek，稳定性不丢；性能 2 字节栈小缓冲零堆单 Move 最优（bytes.ops 单源）
  TPrefixBypassStream = class(TInterfacedObject, IStream)
  private
    FPrefix: TBytes;
    FSmall: array[0..15] of Byte;
    FUseSmall: Boolean;
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
    // OpenRead 零额外 I/O：Header 假时单流直透，复用已打开 IStream 免二次 OpenRead
    // 三阶段决策器：TryLightProbe(2字节栈探针零堆) / TryReadHeader(4K 单流复用) / TryFillLargeFile(同流补读) thin forwarding 职责单一；非 IReaderAt 经 TPrefixBypassStream 前缀包装 Seek-free，截断异常 try-finally 不丢
    function TryLightProbe(const AStream: IStream; const APath, AOp: string; ATotal: Int64; var AProbeBuf: array of Byte; out AProbeLen: SizeUInt; out AHasProbe: Boolean; out AUseReadAt: Boolean; out ABypassStream: IStream): Boolean;
    function TryReadHeader(const AStream: IStream; const APath, AOp: string; ATotal: Int64; AHasProbe: Boolean; const AProbeBuf: array of Byte; AProbeLen: SizeUInt; out AHeader: TBytes; out ARead: SizeUInt; out AUseReadAt: Boolean): Boolean;
    function TryFillLargeFile(const APath, AOp: string; ATotal: Int64; const AHeader: TBytes; const AStream: IStream; out AData: TBytes): Boolean;
    function TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; AUseReadAt: Boolean; out AData: TBytes): Boolean;
    function TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes): THeaderResolve; overload;
    function TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes; out ABypassStream: IStream): THeaderResolve; overload;
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
  FUseSmall := FPrefixLen <= SizeUInt(Length(FSmall));
  if FPrefixLen > 0 then
  begin
    if FUseSmall then
    begin
      if APrefix <> nil then
        Move(APrefix^, FSmall[0], FPrefixLen); // bytes.ops 单源 Move inline 零拷贝，2字节场景零堆分配单 Move 最优
    end
    else
    begin
      SetLength(FPrefix, FPrefixLen);
      if APrefix <> nil then
        Move(APrefix^, FPrefix[0], FPrefixLen); // bytes.ops 单源 Move 零拷贝
    end;
  end else
  begin
    FPrefix := nil;
    FUseSmall := False;
  end;
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
  // 前缀区间零拷贝 Move 直达（小缓冲零堆单 Move 最优，bytes.ops 单源）
  if SizeUInt(FPos) < FPrefixLen then
  begin
    LRem := FPrefixLen - SizeUInt(FPos);
    LCopy := ACount;
    if LCopy > LRem then LCopy := LRem;
    if Int64(SizeUInt(FPos) + LCopy) > FSize then
      LCopy := SizeUInt(FSize - FPos);
    if FUseSmall then
      Move(FSmall[SizeUInt(FPos)], LDst^, LCopy)
    else
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
    FUseSmall := False;
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
var LBypass: IStream;
begin
  Result := TryResolveViaHeaderSingleStream(APath, AOp, AStat, AHeader, ATotal, AData, LBypass);
  if LBypass <> nil then
    try LBypass.Close; except end;
end;

function TTransformingVfs.TryLightProbe(const AStream: IStream; const APath, AOp: string; ATotal: Int64; var AProbeBuf: array of Byte; out AProbeLen: SizeUInt; out AHasProbe: Boolean; out AUseReadAt: Boolean; out ABypassStream: IStream): Boolean;
var LRead: SizeUInt; LReaderAt: IReaderAt;
begin
  Result := False;
  AProbeLen := 0; AHasProbe := False; AUseReadAt := False; ABypassStream := nil;
  if (ATotal <= Int64(TRANSFORM_HEADER_PEEK)) or not Assigned(FHeaderPred) then Exit(False);
  // 大文件轻量预判：栈上 2 字节 PByte 单源零堆分配预判，热点非变换路径免 TBytes 堆分配与 4K 分配（bytes.ops BytesIsGzipBuffer inline 零拷贝单源）
  AUseReadAt := (AStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
  try
    if AUseReadAt then
      LRead := LReaderAt.ReadAt(AProbeBuf[0], 2, 0)
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

function TTransformingVfs.TryReadHeader(const AStream: IStream; const APath, AOp: string; ATotal: Int64; AHasProbe: Boolean; const AProbeBuf: array of Byte; AProbeLen: SizeUInt; out AHeader: TBytes; out ARead: SizeUInt; out AUseReadAt: Boolean): Boolean;
var LPeek, LOff, LRem, LGot: SizeUInt; LReaderAt: IReaderAt;
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
    AUseReadAt := (AStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
    try
      if AUseReadAt then ARead := LReaderAt.ReadAt(AHeader[0], LPeek, 0)
      else ARead := AStream.Read(AHeader[0], LPeek);
    except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    if ARead < LPeek then SetLength(AHeader, ARead);
    if ARead = 0 then AHeader := nil;
  end;
end;

function TTransformingVfs.TryFillLargeFile(const APath, AOp: string; ATotal: Int64; const AHeader: TBytes; const AStream: IStream; out AData: TBytes): Boolean;
var LOff, LRem, LGot: SizeUInt; LReaderAt: IReaderAt;
begin
  Result := False;
  if (ATotal <= TRANSFORM_HEADER_PEEK) or (Length(AHeader) <> TRANSFORM_HEADER_PEEK) or (ATotal > High(SizeInt)) or (ATotal < 0) then Exit(False);
  // 稳定性：大文件命中路径输入受 VFS_DECOMPRESS_MAX_BYTES 32MiB 限幅（超限直接抛，ATotal 已校验），输出同阈值防 bomb；当前以限幅守并发峰值，L7 视压测按需引入 chunked streaming 进一步收敛（CONTRACT 32MiB L7 streaming 候选）。
  // 性能：单流复用已读 4K 头 Move 零拷贝（bytes.ops 单源），同一 IStream 定位补读剩余免二次 OpenRead/二次 4K；inline 热路径，大文件非 IReaderAt 经 Seek 补偿单次虚调用
  if ATotal > Int64(VFS_DECOMPRESS_MAX_BYTES) then
    raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
  // 可抽新模块候选：超 32MiB 前全量分配受限幅保护，L7 引入 chunked streaming 可进一步消除大文件全量分配峰值（当前守稳定性最小改动）
  SetLength(AData, ATotal);
  Move(AHeader[0], AData[0], Length(AHeader)); // bytes.ops 单源 Move 零拷贝复用 4K 头
  LOff := SizeUInt(Length(AHeader)); LRem := SizeUInt(ATotal) - LOff;
  if (AStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil) then
  begin
    try LGot := LReaderAt.ReadAt(AData[LOff], LRem, Int64(LOff));
    except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    if LGot <> LRem then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
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
      try LGot := AStream.Read(AData[LOff], LRem);
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then raise EVfsError.CreateCtx(AOp, APath, 'truncated after header reuse');
      Inc(LOff, LGot); Dec(LRem, LGot);
    end;
  end;
  Result := True;
end;

function TTransformingVfs.TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; AUseReadAt: Boolean; out AData: TBytes): Boolean;
var
  LReaderAt: IReaderAt;
  LUseRA: Boolean;
  LSize, LCap, LOff, LGot, LRead: SizeUInt;
  LChunk: array[0..4095] of Byte;
begin
  Result := False;
  AData := nil;
  if Length(AHeader) = 0 then Exit(False);
  // AHasProbe 已在 TryReadHeader 合成阶段消耗，前缀位置已对齐，此处仅复用 Header 零 Seek
  if AHasProbe then begin end;
  // 未知尺寸单流兜底：HeaderPred 真时复用已读 4K 头 + 同流剩余一次性物化免二次 OpenRead；受 32MiB 限幅守稳定性，L7 按需 chunked streaming
  LUseRA := AUseReadAt and (AStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
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
  LCap := LSize + 4096;
  if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
  SetLength(AData, LCap);
  Move(AHeader[0], AData[0], LSize); // bytes.ops 单源 Move 零拷贝
  LOff := LSize;
  if LUseRA then
  begin
    // IReaderAt 路径：按 offset 顺序补读剩余，直至 EOF
    while True do
    begin
      if LOff >= VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      LRead := SizeUInt(VFS_DECOMPRESS_MAX_BYTES) - LOff;
      if LRead > SizeUInt(Length(LChunk)) then LRead := SizeUInt(Length(LChunk));
      try LGot := LReaderAt.ReadAt(LChunk[0], LRead, Int64(LOff));
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
      if LGot = 0 then Break;
      if LOff + LGot > VFS_DECOMPRESS_MAX_BYTES then
        raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
      if LOff + LGot > LCap then
      begin
        LCap := LCap * 2;
        if LCap < LOff + LGot then LCap := LOff + LGot;
        if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
        if LOff + LGot > LCap then
          raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      Move(LChunk[0], AData[LOff], LGot);
      Inc(LOff, LGot);
      if LGot < LRead then Break;
    end;
  end
  else
  begin
    // 顺序流路径：已处 Header 末尾，持续 Read 至 EOF；限幅守峰值
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
        LCap := LCap * 2;
        if LCap < LOff + LGot then LCap := LOff + LGot;
        if LCap > VFS_DECOMPRESS_MAX_BYTES then LCap := VFS_DECOMPRESS_MAX_BYTES;
        if LOff + LGot > LCap then
          raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
        SetLength(AData, LCap);
      end;
      Move(LChunk[0], AData[LOff], LGot);
      Inc(LOff, LGot);
    end;
  end;
  SetLength(AData, LOff);
  Result := True;
end;

function TTransformingVfs.TryResolveViaHeaderSingleStream(const APath: string; const AOp: string; const AStat: TStatInfo; out AHeader: TBytes; out ATotal: Int64; out AData: TBytes; out ABypassStream: IStream): THeaderResolve;
var
  LStream: IStream;
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
  ABypassStream := nil;
  if AStat.Info.IsDir then Exit(hrBypass);
  // 薄转发：OpenRead 一次，peek 4K 后若命中变换则同一流内补读剩余，免二次 OpenRead/二次 4K；OpenRead bypass 时复用已打开流免二次 OpenRead
  try
    LStream := FInner.OpenRead(APath);
  except
    on LEx: EVfsError do raise;
    on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message);
  end;
  try
    if ATotal < 0 then
      ATotal := LStream.Size;
    // 阶段1：轻量 2 字节栈零堆探针（命中则进入阶段2 4K 合成，非命中直接 bypass 免 4K/TBytes 堆分配）
    LProbeLen := 0; LHasProbe := False; LUseReadAt := False; LBypassTmp := nil;
    if TryLightProbe(LStream, APath, AOp, ATotal, LProbeBuf, LProbeLen, LHasProbe, LUseReadAt, LBypassTmp) then
    begin
      AHeader := nil;
      if AOp = 'open' then
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
    end;
    // 阶段2：读取 4K 头（复用 LightProbe 已消耗前缀，免 Seek 重置）
    if not TryReadHeader(LStream, APath, AOp, ATotal, LHasProbe, LProbeBuf, LProbeLen, AHeader, LRead, LUseReadAt) then
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
    // 小文件（<=4K）复用头即全量，零二次 IO
    if (ATotal >= 0) and (ATotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(AHeader)) = ATotal) then
    begin
      AData := AHeader; Exit(hrAcquired);
    end;
    // 阶段3：大文件命中单流补读（限幅守稳定性，Move 零拷贝复用 4K 头）
    if TryFillLargeFile(APath, AOp, ATotal, AHeader, LStream, AData) then
      Exit(hrAcquired);
    // 未知尺寸单流兜底：HeaderPred 真且尺寸未知时，同流全量物化免二次 OpenRead（消除 hrFallback→VfsReadAllBytes 双次命中）；32MiB 限幅守稳定性，L7 按需 chunked streaming
    if (ATotal < 0) then
    begin
      if TryReadAllWithHeader(APath, AOp, AHeader, LStream, LHasProbe, LUseReadAt, AData) then
        Exit(hrAcquired);
    end;
    // 尺寸不匹配/截断 -> 受控回退外层全量路径（小文件或未知 size 兜底失败场景）；大文件已知 size 已在 Acquired/Bypass 处理，免冗余后端命中
    Exit(hrFallback);
  finally
    if LStream <> nil then
      try LStream.Close; except end;
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
  LData := nil;
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
  LDummy: TStatInfo;
  LResolve: THeaderResolve;
  LBypassStream: IStream;
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
        LData := nil;
        if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        Result := CreateBytesStreamFrom(LOut);
        Exit;
      end;
    hrFallback: ; // 截断/不匹配受控回退；未知尺寸已由单流 TryReadAllWithHeader Acquired 免二次 OpenRead
  end;
  // 受控回退仅截断边沿：大文件/未知尺寸已由单流免二次 OpenRead 处理（TryReadAllWithHeader 单流物化），此处仅目录/截断等极小路径；限幅守峰值
  try LData := VfsReadAllBytes(FInner, APath); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, LEx.Message); end;
  if Length(LData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('open', APath, 'transform: source size exceeds limit');
  if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  try LOut := Transform(LData); except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + LEx.Message); end;
  LData := nil;
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
