unit nextpas.core.vfs.transform;

{** @desc L3 通用字节变换装饰器：任意 IVfs 的零拷贝按需变换视图
  层级：L3（寄居 L2 vfs 家族，registry 白名单豁免未拆分，ADR 0003）
  复用 L0-L1 + 仅 via 头部谓词复用 compress.base 单源，不新增 L2→L2 闭环；
  零拷贝直达：小文件 Header 直落 respack 区间复用，无栈上 4K 中转。
  Stat/OpenRead 经 4K HeaderPred 快路径免大文件全量读；32MiB 防 bomb 由 compressed 薄门面承载。
  性能：inline 热路径 + 零拷贝 Move 复用已读 4K 头（大文件免二次 4K 读）；稳定性：try-finally Close 不丢。 }

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
  nextpas.core.io.base,
  nextpas.core.io.memory,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util;

type
  TTransformingVfs = class(TInterfacedObject, IVfs, IVfsETag, IVfsServeMeta)
  private
    FInner: IVfs;
    FTransform: TVfsTransformFunc;
    FShould: TVfsShouldTransformFunc;
    FHeaderPred: TVfsHeaderPredicateFunc;
    function Should(const AData: TBytes): Boolean; inline;
    function HeaderShould(const AHeader: TBytes; const ATotalSize: Int64): Boolean; inline;
    function Transform(const AData: TBytes): TBytes; inline;
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
end;

function TTransformingVfs.TryPeekHeaderWithStat(const AStat: TStatInfo; const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
var
  LStream: IStream;
  LRead: SizeUInt;
  LReaderAt: IReaderAt;
  LPeek: SizeUInt;
begin
  Result := False;
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
    // 零拷贝直达：按需分配头部缓冲直读入堆，消除栈上 4K 中转 + Move 小文件二次物化
    // 小文件（<=4K）Header 长度即 TotalSize，Stat/OpenRead 可 CoW 复用 Header 为 LData 零二次 IO
    // 大文件仅 4K.peek；优先 IReaderAt.ReadAt 零扰动定位读（OS/embedded/memtree 三后端均暴露 IReaderAt），否则 Stream.Read
    if (ATotalSize >= 0) and (ATotalSize < TRANSFORM_HEADER_PEEK) then
      LPeek := SizeUInt(ATotalSize)
    else
      LPeek := TRANSFORM_HEADER_PEEK;
    if LPeek = 0 then
    begin
      AHeader := nil;
      LRead := 0;
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
        on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
      end;
      if LRead < LPeek then
        SetLength(AHeader, LRead);
      if LRead = 0 then
        AHeader := nil;
    end;
    Result := True;
  finally
    try
      LStream.Close;
    except
    end;
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
  // 大文件已读 4K 复用：单次 Move 复用 AHeader 前缀，剩余经 IReaderAt.ReadAt 定位读或 Seek+Read，免二次 4K 重读
  // 零拷贝：Move 仅 1 次，剩余定位读零扰动（embedded/os/memtree 均支持 IReaderAt）
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
begin
  try
    LInfo := FInner.Stat(APath);
  except
    on E: EVfsError do raise;
    on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message);
  end;
  if LInfo.Info.IsDir then Exit(LInfo);
  // 4K HeaderPred 快路径：大文件非变换场景免全量 VfsReadAllBytes 阻塞；复用已 Stat 结果零二次 Stat 调用
  if Assigned(FHeaderPred) then
  begin
    if TryPeekHeaderWithStat(LInfo, APath, 'stat', LHeader, LTotal) then
    begin
      if not HeaderShould(LHeader, LTotal) then Exit(LInfo);
      // 命中需变换：小文件（<=4K）复用已读 Header 零二次 IO；大文件复用 4K 头免二次 4K 重读
      if (LTotal >= 0) and (LTotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(LHeader)) = LTotal) then
        LData := LHeader
      else if (LTotal > TRANSFORM_HEADER_PEEK) and (Length(LHeader) = TRANSFORM_HEADER_PEEK) then
      begin
        try LData := ReadAllReusingHeader(APath, 'stat', LHeader, LTotal); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
      end
      else
      begin
        try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
        // HeaderPred 已真，仍需尊重 Should（若提供）防误判
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
      end;
      // 小文件路径的 Should 校验（大文件已在上方分支完成）
      if (LTotal >= 0) and (LTotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(LHeader)) = LTotal) then
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
      try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('stat', APath, 'transform failed: ' + E.Message); end;
      if Pointer(LOut) <> Pointer(LData) then begin LInfo.Info.Size := Int64(Length(LOut)); LInfo.ContentHash := 0; end;
      Exit(LInfo);
    end;
    // peek 失败回退全量路径
  end;
  // 无 HeaderPred 回退：需全量读决定 Should/Transform（大文件调用方应选用 HeaderPred 变体或避免 Stat）
  try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
  if Assigned(FShould) then
    if not Should(LData) then Exit(LInfo);
  // 若 LNeedFull 且 Should 为 nil 则必变换
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
begin
  // 4K HeaderPred 快路径：Should 假时零物化直透内层流（零拷贝无 VfsReadAllBytes）
  if Assigned(FHeaderPred) then
  begin
    if TryPeekHeader(APath, 'open', LHeader, LTotal) then
    begin
      if not HeaderShould(LHeader, LTotal) then
      begin
        try Result := FInner.OpenRead(APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
        Exit;
      end;
      // 命中需变换：小文件复用 Header 避免二次全量读
      if (LTotal >= 0) and (LTotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(LHeader)) = LTotal) then
      begin
        LData := LHeader;
        if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
        if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        Result := CreateBytesStreamFrom(LOut);
        Exit;
      end;
      // 大文件命中需变换：复用已读 4K 头免二次 4K 重读，单次剩余定位读
      if (LTotal > TRANSFORM_HEADER_PEEK) and (Length(LHeader) = TRANSFORM_HEADER_PEEK) then
      begin
        try LData := ReadAllReusingHeader(APath, 'open', LHeader, LTotal); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
        if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        try LOut := Transform(LData); except on E: Exception do raise EVfsError.CreateCtx('open', APath, 'transform failed: ' + E.Message); end;
        if Pointer(LOut) = Pointer(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
        Result := CreateBytesStreamFrom(LOut);
        Exit;
      end;
    end;
    // peek 失败或大小未知回退全量路径
  end;
  try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
  // Should 假或 Pointer 未变时复用已读 LData，省二次 FInner.OpenRead 磁盘 IO；单次 VfsReadAllBytes 已付 1 次拷贝，二次 IO 仅增系统调用无零拷贝收益
  if Assigned(FShould) and not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  if Assigned(FHeaderPred) and not HeaderShould(LData, Int64(Length(LData))) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
  if not Assigned(FShould) and not Assigned(FHeaderPred) then
  begin
    // 无谓词必变换
  end
  else if Assigned(FShould) and Assigned(FHeaderPred) then
  begin
    // 双谓词：Header 已真但 Should 仍需校验（防 header 误判）
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
