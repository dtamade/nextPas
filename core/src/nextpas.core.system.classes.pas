unit nextpas.core.system.classes;
{**
 * @desc Sysroot Classes 兼容门面。
 *   Re-export FPC Classes 类型 — 其他模块通过此门面使用 Classes 类型，
 *   不得直接 uses Classes。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  Classes,
  nextpas.core.io.intf;

type
  TSeekOrigin = Classes.TSeekOrigin;
  TStream = Classes.TStream;
  TFileStream = Classes.TFileStream;
  TList = Classes.TList;
  TInterfaceList = Classes.TInterfaceList;
  TStringList = Classes.TStringList;

  IStream = nextpas.core.io.intf.IStream;
  IReader = nextpas.core.io.intf.IReader;
  IWriter = nextpas.core.io.intf.IWriter;

const
  fmCreate = Classes.fmCreate;
  fmOpenRead = Classes.fmOpenRead;
  fmOpenWrite = Classes.fmOpenWrite;
  fmOpenReadWrite = Classes.fmOpenReadWrite;
  fmShareDenyNone = Classes.fmShareDenyNone;
  fmShareDenyWrite = Classes.fmShareDenyWrite;

implementation

end.
