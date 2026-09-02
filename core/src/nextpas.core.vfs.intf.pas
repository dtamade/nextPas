unit nextpas.core.vfs.intf;

{** @desc IVfs 契约：只读文件树视图。流词汇唯一来源是 nextpas.core.io.intf。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf,
  nextpas.core.vfs.base;

type
  { 只读契约（INV-V1）；实现发布后为不可变快照（INV-V2） }
  IVfs = interface(IInterface)
    ['{7C4E1A20-9B3F-4D8E-A6C1-2F5D80B14E01}']
    function Exists(const APath: string): Boolean;
    function Stat(const APath: string): TStatInfo;
    function List(const ADirPath: string): TEntryArray;
    function OpenRead(const APath: string): IStream;
    function CaseSensitive: Boolean;
  end;

  { 可选能力：预计算 ETag / Last-Modified 快速路径（embedded 零分配命中，os/memtree 回退 false） }
  IVfsETag = interface(IInterface)
    ['{B2D7E6A1-4C9F-4A1E-9E3D-7F1A2C8D5B30}']
    function TryGetETag(const APath: string; out AETag: string): Boolean;
    function TryGetLastModified(const APath: string; out ALastModified: string): Boolean;
  end;

  { 扩展：单次查找同时取 ETag+LastModified（ServeVfs 三连击→单次二分），embedded 零分配命中 }
  IVfsServeMeta = interface(IInterface)
    ['{A3F1B2C4-8E9D-4F6A-9B2C-1D4E5F607890}']
    function TryGetServeMeta(const APath: string; out AETag, ALastModified: string): Boolean;
  end;

{ 单源 VfsETagHelper：TryGet* 三方法 Supports 级联同构收口（mount/overlay/embed 共用），
  inline 热路径 + 零拷贝 Supports 直通，bytes.ops 外零额外分配，单源防漂移 }
function VfsETagHelperTryGetETag(const AFs: IVfs; const APath: string; out AETag: string): Boolean; inline;
function VfsETagHelperTryGetLastModified(const AFs: IVfs; const APath: string; out ALastModified: string): Boolean; inline;
function VfsETagHelperTryGetServeMeta(const AFs: IVfs; const APath: string; out AETag, ALastModified: string): Boolean; inline;

implementation

function VfsETagHelperTryGetETag(const AFs: IVfs; const APath: string; out AETag: string): Boolean; inline;
var
  LIntf: IVfsETag;
begin
  AETag := '';
  if (AFs = nil) then Exit(False);
  if AFs.QueryInterface(IVfsETag, LIntf) = 0 then
    Exit(LIntf.TryGetETag(APath, AETag));
  Result := False;
end;

function VfsETagHelperTryGetLastModified(const AFs: IVfs; const APath: string; out ALastModified: string): Boolean; inline;
var
  LIntf: IVfsETag;
begin
  ALastModified := '';
  if (AFs = nil) then Exit(False);
  if AFs.QueryInterface(IVfsETag, LIntf) = 0 then
    Exit(LIntf.TryGetLastModified(APath, ALastModified));
  Result := False;
end;

function VfsETagHelperTryGetServeMeta(const AFs: IVfs; const APath: string; out AETag, ALastModified: string): Boolean; inline;
var
  LMeta: IVfsServeMeta;
  LETagIntf: IVfsETag;
begin
  AETag := '';
  ALastModified := '';
  if (AFs = nil) then Exit(False);
  if AFs.QueryInterface(IVfsServeMeta, LMeta) = 0 then
    Exit(LMeta.TryGetServeMeta(APath, AETag, ALastModified));
  if AFs.QueryInterface(IVfsETag, LETagIntf) = 0 then
  begin
    Result := LETagIntf.TryGetETag(APath, AETag);
    if Result then
      LETagIntf.TryGetLastModified(APath, ALastModified);
    Exit;
  end;
  Result := False;
end;

end.
