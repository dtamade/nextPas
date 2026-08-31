unit nextpas.core.crypto.intf;

{$mode ObjFPC}{$H+}
{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.intf — 密码学模块接口契约

  Re-exports carrier from base and defines EC point validator interface.
  Keeps base ← intf direction: intf depends only on base.
}

interface

uses
  nextpas.core.crypto.base;

type
  TECPoint = nextpas.core.crypto.base.TECPoint;

  IECPointValidator = interface
    ['{A1B2C3D4-E5F6-0001-ABCD-1234567890AB}']
    function TryValidate(const APoint: TECPoint; out AError: string): Boolean;
  end;

implementation

end.
