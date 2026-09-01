unit nextpas.core.vfs.transform;

{** @desc L3 通用字节变换装饰器：任意 IVfs 的零拷贝按需变换视图
  L3 decorator seam 寄居 L2 vfs 家族（registry 白名单豁免未拆分，ADR 0003）；
  复用 L0-L1 + 仅 via 头部谓词复用 compress.base 单源，不新增 L2→L2 闭环。
  Stat/OpenRead 经 4K HeaderPred 快路径免大文件全量读；32MiB 防 bomb 由 compressed 薄门面承载。 }

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

function TTransformingVfs.TryPeekHeader(const APath: string; const AOp: string; out AHeader: TBytes; out ATotalSize: Int64): Boolean;
var
  LStream: IStream;
  LBuf: array[0..TRANSFORM_HEADER_PEEK-1] of Byte;
  LRead: SizeUInt;
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
  ATotalSize := LInfo.Info.Size;
  try
    LStream := FInner.OpenRead(APath);
  except
    on E: EVfsError do raise;
    on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
  end;
  try
    try
      LRead := LStream.Read(LBuf[0], TRANSFORM_HEADER_PEEK);
    except
      on E: Exception do raise EVfsError.CreateCtx(AOp, APath, E.Message);
    end;
    SetLength(AHeader, LRead);
    if LRead > 0 then Move(LBuf[0], AHeader[0], LRead);
    Result := True;
  finally
    try
      LStream.Close;
    except
    end;
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
  // 4K HeaderPred 快路径：大文件非变换场景免全量 VfsReadAllBytes 阻塞
  if Assigned(FHeaderPred) then
  begin
    if TryPeekHeader(APath, 'stat', LHeader, LTotal) then
    begin
      if not HeaderShould(LHeader, LTotal) then Exit(LInfo);
      // 命中需变换：小文件（<=4K）复用已读 Header 零二次 IO
      if (LTotal >= 0) and (LTotal <= TRANSFORM_HEADER_PEEK) and (Int64(Length(LHeader)) = LTotal) then
        LData := LHeader
      else
      begin
        try LData := VfsReadAllBytes(FInner, APath); except on E: EVfsError do raise; on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
        // HeaderPred 已真，仍需尊重 Should（若提供）防误判
        if Assigned(FShould) and not Should(LData) then Exit(LInfo);
      end;
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
    end;
    // peek 失败或大文件命中回退全量路径
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
