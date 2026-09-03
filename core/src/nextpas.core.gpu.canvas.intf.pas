{**
 * nextpas.core.gpu.canvas.intf - GPU 批接口（ICanvas→GPU 批，零平台硬依赖）
 * L3，仅依 L1-L2（graphics.base/canvas.intf/image.base + canvas.base），
 * 不直连 gpu.gl/platform.dl；上传由调用方注入回调或经 window 层消费 Region。
 *}
unit nextpas.core.gpu.canvas.intf;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.canvas.intf,
  nextpas.core.image.base,
  nextpas.core.gpu.canvas.base;

type
  IGpuBatch = interface
    ['{8F3A2C11-4D2E-4A9B-9C12-5E6F7A8B9C0D}']
    function Alloc(AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;
    function AllocBitmap(const ABitmap: TBitmap; AScale: Single): TAtlasRegion;
    function AllocCanvas(ACanvas: ICanvas; AScale: Single): TAtlasRegion;
    procedure Reset;
    function GetAtlas: TAtlas;
    function ScaleForWindow(ADisplayScale: Single): Single;
    property Atlas: TAtlas read GetAtlas;
  end;

implementation

end.
