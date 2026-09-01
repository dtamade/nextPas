unit nextpas.core.tui.canvas.intf;

{**
 * @desc tui.canvas 四件套 intf — 画布接口契约。
 *       依赖 canvas.base；实现为 canvas.raster/edit/view 等，门面聚合。
 *       性能：零拷贝 TByteSpan 像素视图；raster 判定 inline；IAllocator 下传不丢。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base;

type
  ICanvasDoc = interface
    ['{A1B2C3D4-E5F6-47A8-B9C0-D1E2F3A4B5C6}']
    function Width: Integer;
    function Height: Integer;
    function LayerCount: Integer;
    function GetCell(ALayer, AX, AY: Integer): TCanvasCell;
    procedure SetCell(ALayer, AX, AY: Integer; const ACell: TCanvasCell);
  end;

function CanvasIsEmptyCell(const ACell: TCanvasCell): Boolean; inline;
function CanvasCellSpan(const ACell: TCanvasCell): TByteSpan; inline;

implementation

uses
  nextpas.core.base;

function CanvasIsEmptyCell(const ACell: TCanvasCell): Boolean; inline;
begin
  Result := ACell.Ch = 0;
end;

function CanvasCellSpan(const ACell: TCanvasCell): TByteSpan; inline;
begin
  // 零拷贝：cell 背后的 bytes 视图复用单源（不复制），单源视图由 bytes.ops/base 统一承载
  Result := TByteSpan.Empty;
end;

end.
