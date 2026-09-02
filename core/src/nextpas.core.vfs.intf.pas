unit nextpas.core.vfs.intf;

{** @desc IVfs 契约：只读文件树视图。流词汇唯一来源是 nextpas.core.io.intf。 }

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.text.view,
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

  { 零拷贝视图扩展：TStringView 零堆分配路径探测，复用 bytes.ops 单源 CompareBytesOrdered，inline 零额外调用。
    反哺 owner：webview.vfs 剥首段分支需 View 直通 Exists/OpenRead，消除 ToString 物化；热点 memtree/embedded 真零拷贝，os 回退单次物化。 }
  IVfsView = interface(IInterface)
    ['{E9A4C7B1-3F2D-4E8A-9B6C-1D5F8A0C3E42}']
    function ExistsView(const APath: TStringView): Boolean;
    function OpenReadView(const APath: TStringView): IStream;
  end;

implementation

end.
