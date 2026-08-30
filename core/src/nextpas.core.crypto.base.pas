unit nextpas.core.crypto.base;

{$mode ObjFPC}{$H+}
{$I nextpas.core.settings.inc}

{ nextpas.core.crypto.base — 密码学模块公共载体

  Owner of TECPoint and other lightweight carriers. Pure data, no logic.
  Base depends only on L0 (nextpas.core.base) for TBytes.
}

interface

uses
  nextpas.core.base;

type
  TECPoint = record
    X: TBytes;
    Y: TBytes;
    IsInfinity: Boolean;
  end;

implementation

end.
