unit nextpas.core.vfs.transform;

{ L3 通用字节变换视图 }

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
    function TryLightProbe(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; var AProbeBuf: array of Byte; out AProbeLen: SizeUInt; out AHasProbe: Boolean; out AUseReadAt: Boolean; out ABypassStream: IStream): Boolean;
    function TryReadHeader(const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; const APath, AOp: string; ATotal: Int64; AHasProbe: Boolean; const AProbeBuf: array of Byte; AProbeLen: SizeUInt; out AHeader: TBytes; out ARead: SizeUInt; out AUseReadAt: Boolean): Boolean;
    function TryFillLargeFile(const APath, AOp: string; ATotal: Int64; const AHeader: TBytes; const AStream: IStream; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
    function TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
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
  // 输入先限幅：32MiB 前置校验避免 Transform 内部分配峰值后才抛（VFS_DECOMPRESS_MAX_BYTES 单源 32MiB via vfs.base→compress.base）；输出仍后置校验但立即置 nil 释放峰值驻留
  if Length(AData) > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx('transform', '', 'transform: source size exceeds limit');
  Result := FTransform(AData);
  if Length(Result) > VFS_DECOMPRESS_MAX_BYTES then
  begin
    Result := nil;
    raise EVfsError.CreateCtx('transform', '', 'transform: output size exceeds limit');
  end;
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
    // 命中前缀已消耗 2 字节，合成 4K 头免 Seek(0) 重置：前缀 + 单次 Read 剩余（bytes.ops BytesCopy 单源 inline 零拷贝，免索引元素喂无类型参数 inline 红线）
    SetLength(AHeader, LPeek);
    BytesCopy(@AHeader[0], @AProbeBuf[0], AProbeLen);
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
var LOff, LRem: SizeUInt;
begin
  Result := False;
  if (ATotal <= TRANSFORM_HEADER_PEEK) or (Length(AHeader) <> TRANSFORM_HEADER_PEEK) or (ATotal > High(SizeInt)) or (ATotal < 0) then Exit(False);
  if ATotal > Int64(VFS_DECOMPRESS_MAX_BYTES) then
    raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
  // perf: 单次精确分配，无 BytesNextCapacity 几何扩容多次 Move；限幅前置，bytes.ops BytesCopy inline 零拷贝复用 4K 头
  SetLength(AData, ATotal);
  if Length(AHeader) > 0 then
    BytesCopy(@AData[0], @AHeader[0], SizeUInt(Length(AHeader))); // inline 零拷贝
  LOff := SizeUInt(Length(AHeader));
  LRem := SizeUInt(ATotal) - LOff;
  if LRem = 0 then Exit(True);
  // 单源填充器 At 偏移版复用 VfsFillFromStream 单源（IReaderAt 缓存复用，无二次 QI，回退 Seek 单次）
  try
    VfsFillFromStreamAtCached(AStream, AReaderAt, AHasReaderAt, APath, PByte(@AData[LOff]), LRem, Int64(LOff));
  except
    on LEx: EVfsError do raise;
    on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message);
  end;
  Result := True;
end;

function TTransformingVfs.TryReadAllWithHeader(const APath, AOp: string; const AHeader: TBytes; const AStream: IStream; AHasProbe: Boolean; const AReaderAt: IReaderAt; AHasReaderAt: Boolean; out AData: TBytes): Boolean;
var
  LKnown: Int64;
  LOff, LRem: SizeUInt;
  LChunk: array[0..4095] of Byte;
  LGot: SizeUInt;
  LParts: array of TBytes;
  LPartCount: SizeInt;
  LTotal: SizeUInt;
  LOne: TBytes;
begin
  Result := False;
  AData := nil;
  if Length(AHeader) = 0 then Exit(False);
  if AHasProbe then begin end;
  if Length(AHeader) < TRANSFORM_HEADER_PEEK then
  begin
    AData := AHeader;
    if Length(AData) > VFS_DECOMPRESS_MAX_BYTES then
      raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
    Exit(True);
  end;
  // 已知尺寸优先精确分配复用 At 填充器，无几何扩容
  LKnown := AStream.Size;
  if LKnown >= 0 then
  begin
    if LKnown > Int64(VFS_DECOMPRESS_MAX_BYTES) then
      raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
    if LKnown < Int64(Length(AHeader)) then
      LKnown := Int64(Length(AHeader));
    SetLength(AData, LKnown);
    BytesCopy(@AData[0], @AHeader[0], SizeUInt(Length(AHeader))); // inline 零拷贝
    LOff := SizeUInt(Length(AHeader));
    LRem := SizeUInt(LKnown) - LOff;
    if LRem > 0 then
      try VfsFillFromStreamAtCached(AStream, AReaderAt, AHasReaderAt, APath, PByte(@AData[LOff]), LRem, Int64(LOff));
      except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    Exit(True);
  end;
  // 真正未知尺寸：4K 栈块收集 + 单次 BytesConcatMany，消除每块 SetLength 全量 Move；复用 bytes.ops 单源
  LTotal := SizeUInt(Length(AHeader));
  if LTotal > VFS_DECOMPRESS_MAX_BYTES then
    raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
  SetLength(LParts, 1);
  LParts[0] := AHeader;
  LPartCount := 1;
  LOff := LTotal;
  while True do
  begin
    if LOff >= VFS_DECOMPRESS_MAX_BYTES then
      raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
    try
      if AHasReaderAt then
        LGot := AReaderAt.ReadAt(LChunk[0], SizeUInt(Length(LChunk)), Int64(LOff))
      else
        LGot := AStream.Read(LChunk[0], SizeUInt(Length(LChunk)));
    except on LEx: EVfsError do raise; on LEx: Exception do raise EVfsError.CreateCtx(AOp, APath, LEx.Message); end;
    if LGot = 0 then Break;
    if LOff + LGot > VFS_DECOMPRESS_MAX_BYTES then
      raise EVfsError.CreateCtx(AOp, APath, 'transform: source size exceeds limit');
    SetLength(LOne, LGot);
    BytesCopy(@LOne[0], @LChunk[0], LGot); // inline 零拷贝
    if LPartCount >= Length(LParts) then SetLength(LParts, LPartCount + 8);
    LParts[LPartCount] := LOne;
    Inc(LPartCount);
    Inc(LOff, LGot);
    Inc(LTotal, LGot);
    if LGot < SizeUInt(Length(LChunk)) then Break;
  end;
  if LPartCount = 1 then
    AData := AHeader
  else
  begin
    SetLength(LParts, LPartCount);
    AData := BytesConcatMany(LParts); // 单次分配物化，bytes.ops 单源
  end;
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
    // 性能：单流内 IReaderAt 能力单次 QueryInterface 缓存复用，热路径三阶段免重复虚调用（LHasReaderAt/LReaderAt 单次探测，多分支削减，inline 零拷贝单源）
    LHasReaderAt := (LStream.QueryInterface(IReaderAt, LReaderAt) = 0) and (LReaderAt <> nil);
    // 阶段1：轻量 2 字节栈零堆探针（命中则进入阶段2 4K 合成，非命中直接 bypass 免 4K/TBytes 堆分配）
    LProbeLen := 0; LHasProbe := False; LUseReadAt := False; LBypassTmp := nil;
    if TryLightProbe(LStream, LReaderAt, LHasReaderAt, APath, AOp, ATotal, LProbeBuf, LProbeLen, LHasProbe, LUseReadAt, LBypassTmp) then
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
        if Pointer(LOut) = Pointer(LData) then begin LData := nil; Result := CreateBytesStreamFrom(LOut); Exit; end;
        LData := nil;
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
  if Pointer(LOut) = Pointer(LData) then begin LData := nil; Result := CreateBytesStreamFrom(LOut); Exit; end;
  LData := nil;
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
