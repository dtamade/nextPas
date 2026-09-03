{**
 * nextpas.core.gpu.canvas - GPU 画布桥（TAtlas/TAtlasRegion/ScaleFactor，零 FFI 硬链接）
 * L3 薄桥：仅依 graphics.base 值类型，2048×2048 分页 shelf 打包，Scale 打通
 * window/display。打包状态内聚于 TAtlas 实例（无全局游标），非线程安全
 * 由调用方同步；像素对齐复用 mem.base AlignUp 16px=64B(与 TBitmap AlignUp64 一致)，槽位语义与 font.atlas/
 * Resin/game888 shelf 复用预期一致，不重复造轮子。
 *}
unit nextpas.core.gpu.canvas;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base;

type
  TAtlas = record
  private
    FPageWidth, FPageHeight: Integer;
    FPageCount: Integer;
    FCursorX, FCursorY, FRowH: Integer;
  public
    class function Create(APageW, APageH: Integer): TAtlas; static;
    procedure Reset;
  end;

  TAtlasRegion = record
    Page: Integer;
    Rect: TRect;
    Scale: Single;
    function IsEmpty: Boolean; inline;
  end;

function ScaleFactorForWindow(ADisplayScale: Single): Single; inline;
function AtlasAlloc(var AAtlas: TAtlas; AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math,
  nextpas.core.mem.base,
  nextpas.core.text.conv;

class function TAtlas.Create(APageW, APageH: Integer): TAtlas;
begin
  if (APageW<=0) or (APageH<=0) then raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: atlas page must be >0 (w=' + IntToStr(APageW) + ' h=' + IntToStr(APageH) + ')');
  Result.FPageWidth := APageW;
  Result.FPageHeight := APageH;
  Result.FPageCount := 1;
  Result.FCursorX := 0;
  Result.FCursorY := 0;
  Result.FRowH := 0;
end;

procedure TAtlas.Reset;
begin
  FCursorX := 0;
  FCursorY := 0;
  FRowH := 0;
end;

function TAtlasRegion.IsEmpty: Boolean;
begin Result := Rect.IsEmpty; end;

function ScaleFactorForWindow(ADisplayScale: Single): Single;
begin
  if ADisplayScale <= 0 then Result := 1.0
  else if ADisplayScale > 4.0 then Result := 4.0
  else Result := ADisplayScale;
end;

function AtlasAlloc(var AAtlas: TAtlas; AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;
var
  W, H: Integer;
  AW, AH: SizeUInt;
  FW, FH: Single;
begin
  if (AWidth<=0) or (AHeight<=0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: alloc size must be >0 (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ')');
  if IsNaN(AScale) or IsInfinite(AScale) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scale must be finite (scale=' + FloatToStr(AScale) + ' w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ')');
  if AScale<=0 then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scale must be >0 (scale=' + FloatToStr(AScale) + ' w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ')');
  FW := AWidth * AScale + 0.5;
  FH := AHeight * AScale + 0.5;
  if IsNaN(FW) or IsInfinite(FW) or IsNaN(FH) or IsInfinite(FH) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scaled size not finite (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ')');
  if (FW>High(Integer)) or (FH>High(Integer)) or (FW<1) or (FH<1) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scaled size overflow (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ' scaledW=' + FloatToStr(FW) + ' scaledH=' + FloatToStr(FH) + ')');
  W := Trunc(FW);
  H := Trunc(FH);
  if (W<=0) or (H<=0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: alloc size must be >0 (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ' scaledW=' + IntToStr(W) + ' scaledH=' + IntToStr(H) + ')');
  AW := AlignUp(SizeUInt(W), MEM_CACHE_LINE_SIZE div 4);
  AH := AlignUp(SizeUInt(H), MEM_CACHE_LINE_SIZE div 4);
  if (AW=0) or (AH=0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: aligned size overflow (w=' + IntToStr(W) + ' h=' + IntToStr(H) + ' scale=' + FloatToStr(AScale) + ')');
  if (AW>SizeUInt(High(Integer))) or (AH>SizeUInt(High(Integer))) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: aligned size overflow (w=' + IntToStr(W) + ' h=' + IntToStr(H) + ' scale=' + FloatToStr(AScale) + ' aw=' + IntToStr(Int64(AW)) + ' ah=' + IntToStr(Int64(AH)) + ')');
  W := Integer(AW); H := Integer(AH);
  if W > AAtlas.FPageWidth then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: width exceeds atlas page (w=' + IntToStr(W) + ' pageW=' + IntToStr(AAtlas.FPageWidth) + ' scale=' + FloatToStr(AScale) + ')');
  if AAtlas.FCursorX + W > AAtlas.FPageWidth then
  begin
    AAtlas.FCursorX := 0;
    AAtlas.FCursorY := AAtlas.FCursorY + AAtlas.FRowH;
    AAtlas.FRowH := 0;
  end;
  if AAtlas.FCursorY + H > AAtlas.FPageHeight then
  begin
    Inc(AAtlas.FPageCount);
    AAtlas.FCursorX := 0; AAtlas.FCursorY := 0; AAtlas.FRowH := 0;
  end;
  Result.Page := AAtlas.FPageCount - 1;
  Result.Rect := TRect.From(AAtlas.FCursorX, AAtlas.FCursorY, W, H);
  Result.Scale := AScale;
  Inc(AAtlas.FCursorX, W);
  if H > AAtlas.FRowH then AAtlas.FRowH := H;
end;

end.
