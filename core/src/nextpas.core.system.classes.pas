unit nextpas.core.system.classes;
{**
 * @desc Minimal Classes compatibility facade for stream types consumed by
 *   framework modules that are migrating away from direct RTL imports.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  Classes;

type
  TStream = Classes.TStream;
  THandleStream = Classes.THandleStream;
  TMemoryStream = Classes.TMemoryStream;
  TStringStream = Classes.TStringStream;
  TSeekOrigin = Classes.TSeekOrigin;
  TInterfacedObject = System.TInterfacedObject;
  IInterface = System.IInterface;

implementation

end.
