unit nextpas.core.system.classes;
{**
 * @desc Sysroot Classes 兼容门面 — stub 收敛，无 FPC 直引。
 *   TSeekOrigin 单源委托 nextpas.core.io.base（L1 owner），
 *   其余 9 类型经 nextpas.core.system.classes.impl 单源实现，
 *   复用 nextpas.core.bytes.ops（inline/零拷贝），析构释放不丢。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.base,
  nextpas.core.io.intf,
  nextpas.core.system.classes.impl;

type
  TSeekOrigin = nextpas.core.io.base.TSeekOrigin;
  TDuplicates = nextpas.core.system.classes.impl.TDuplicates;
  TStream = nextpas.core.system.classes.impl.TStream;
  THandleStream = nextpas.core.system.classes.impl.THandleStream;
  TMemoryStream = nextpas.core.system.classes.impl.TMemoryStream;
  TFileStream = nextpas.core.system.classes.impl.TFileStream;
  TList = nextpas.core.system.classes.impl.TList;
  TInterfaceList = nextpas.core.system.classes.impl.TInterfaceList;
  TStringList = nextpas.core.system.classes.impl.TStringList;
  TThread = nextpas.core.system.classes.impl.TThread;

  IStream = nextpas.core.io.intf.IStream;
  IReader = nextpas.core.io.intf.IReader;
  IWriter = nextpas.core.io.intf.IWriter;

const
  dupIgnore = nextpas.core.system.classes.impl.dupIgnore;
  dupAccept = nextpas.core.system.classes.impl.dupAccept;
  dupError = nextpas.core.system.classes.impl.dupError;

  { File mode constants — standard Windows file sharing values }
  fmCreate = $FF00;
  fmOpenRead = $0000;
  fmOpenWrite = $0001;
  fmOpenReadWrite = $0002;
  fmShareDenyNone = $0040;
  fmShareDenyRead = $0030;
  fmShareDenyWrite = $0020;
  fmShareExclusive = $0010;

implementation

end.
