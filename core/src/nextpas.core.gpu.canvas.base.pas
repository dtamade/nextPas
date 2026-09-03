{**
 * nextpas.core.gpu.canvas.base - Atlas 值类型底座（零堆）
 * L3 薄桥底座：仅依 graphics.base，承 TAtlas/TAtlasRegion 值类型与常量。
 * 对齐复用 mem.base MEM_CACHE_LINE_SIZE（64B → 16px），与 TBitmap AlignUp64 同源。
 * Scale 1..4 打通 window/display，无平台硬依赖。
 *}
unit nextpas.core.gpu.canvas.base;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base;

type
  TAtlas = record
    PageWidth, PageHeight: Integer;
    PageCount: Integer;
    CursorX, CursorY, RowH: Integer;
    class function Create(APageW, APageH: Integer): TAtlas; static;
    procedure Reset; inline;
  end;

  TAtlasRegion = record
    Page: Integer;
    Rect: TRect;
    Scale: Single;
    function IsEmpty: Boolean; inline;
  end;

const
  GPU_ATLAS_DEFAULT_PAGE = 2048;
  GPU_ATLAS_SCALE_MIN = 1.0;
  GPU_ATLAS_SCALE_MAX = 4.0;
  GPU_ATLAS_ALIGN_PX = 16; // 16 px *4 =64B cache line

implementation

uses
  nextpas.core.errors,
  nextpas.core.text.conv;

class function TAtlas.Create(APageW, APageH: Integer): TAtlas;
begin
  if (APageW <= 0) or (APageH <= 0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: atlas page must be >0 (w=' + IntToStr(APageW) + ' h=' + IntToStr(APageH) + ')');
  Result.PageWidth := APageW;
  Result.PageHeight := APageH;
  Result.PageCount := 1;
  Result.CursorX := 0;
  Result.CursorY := 0;
  Result.RowH := 0;
end;

procedure TAtlas.Reset;
begin
  CursorX := 0;
  CursorY := 0;
  RowH := 0;
end;

function TAtlasRegion.IsEmpty: Boolean;
begin
  Result := Rect.IsEmpty;
end;

end.
