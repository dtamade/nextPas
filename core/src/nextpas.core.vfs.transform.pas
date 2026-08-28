unit nextpas.core.vfs.transform;

{** @desc L3 通用字节变换装饰器：任意 IVfs 的零拷贝按需变换视图。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.vfs.intf;

type
  TVfsTransformFunc = function(const AData: TBytes): TBytes;
  TVfsShouldTransformFunc = function(const AData: TBytes): Boolean;

function CreateTransformingVfs(const AInner: IVfs;
  const ATransform: TVfsTransformFunc;
  const AShouldTransform: TVfsShouldTransformFunc = nil): IVfs;

implementation

uses
  nextpas.core.exception,
  nextpas.core.io.memory,
  nextpas.core.vfs.base,
  nextpas.core.vfs.errors,
  nextpas.core.vfs.util;

type
  TTransformingVfs = class(TInterfacedObject, IVfs, IVfsETag)
  private
    FInner: IVfs;
    FTransform: TVfsTransformFunc;
    FShould: TVfsShouldTransformFunc;
    function Should(const AData: TBytes): Boolean; inline;
    function Transform(const AData: TBytes): TBytes; inline;
  public
    constructor Create(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShould: TVfsShouldTransformFunc);
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
  end;

function CreateTransformingVfs(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShouldTransform: TVfsShouldTransformFunc): IVfs;
begin
  if AInner = nil then raise EVfsError.CreateCtx('wrap', '', 'inner VFS is nil');
  if not Assigned(ATransform) then raise EVfsError.CreateCtx('wrap', '', 'transform is nil');
  Result := TTransformingVfs.Create(AInner, ATransform, AShouldTransform);
end;

constructor TTransformingVfs.Create(const AInner: IVfs; const ATransform: TVfsTransformFunc; const AShould: TVfsShouldTransformFunc);
begin
  inherited Create;
  FInner := AInner;
  FTransform := ATransform;
  FShould := AShould;
end;

function TTransformingVfs.Should(const AData: TBytes): Boolean; inline;
begin
  if not Assigned(FShould) then Exit(True);
  Result := FShould(AData);
end;

function TTransformingVfs.Transform(const AData: TBytes): TBytes; inline;
begin
  Result := FTransform(AData);
end;

function TTransformingVfs.Exists(const APath: string): Boolean;
begin
  Result := FInner.Exists(APath);
end;

function TTransformingVfs.Stat(const APath: string): TStatInfo;
var LInfo: TStatInfo; LData: TBytes; LOut: TBytes;
begin
  LInfo := FInner.Stat(APath);
  if LInfo.Info.IsDir then Exit(LInfo);
  try LData := VfsReadAllBytes(FInner, APath); except on E: Exception do raise EVfsError.CreateCtx('stat', APath, E.Message); end;
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
var LData: TBytes; LOut: TBytes;
begin
  try LData := VfsReadAllBytes(FInner, APath); except on E: Exception do raise EVfsError.CreateCtx('open', APath, E.Message); end;
  // Should 假或 Pointer 未变时复用已读 LData，省二次 FInner.OpenRead 磁盘 IO；单次 VfsReadAllBytes 已付 1 次拷贝，二次 IO 仅增系统调用无零拷贝收益
  if not Should(LData) then begin Result := CreateBytesStreamFrom(LData); Exit; end;
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

end.
