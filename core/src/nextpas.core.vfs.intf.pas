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

implementation

end.
