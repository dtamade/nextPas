{**
 * nextpas.core.image.intf - 图像编解码接口契约（接口化范式）
 * L2，面向接口编程时引此单元，开箱即用引门面 nextpas.core.image。
 *}
unit nextpas.core.image.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.image.base;

type
  IImageDecoder = interface
    ['{A1B2C3D4-1111-2222-3333-444444555566}']
    function Decode(const AData: TBytes; out AWidth, AHeight: Integer): TBytes;
    function IsAvailable: Boolean;
  end;

  IImageEncoder = interface
    ['{B2C3D4E5-2222-3333-4444-555555666677}']
    function Encode(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
    function IsAvailable: Boolean;
  end;

  IImageCodec = interface(IImageDecoder)
    ['{C3D4E5F6-3333-4444-5555-666666777788}']
    function EncodeRgba(const APixels: TBytes; AWidth, AHeight: Integer): TBytes;
  end;

implementation

end.
