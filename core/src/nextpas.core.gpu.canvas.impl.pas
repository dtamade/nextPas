{**
 * nextpas.core.gpu.canvas.impl - Atlas 打包与 Scale 薄实现（零平台硬链接）
 * L3 薄层：仅依 L0-L2（graphics.base/mem.base/math/errors + bytes.ops 单源）。
 * shelf 打包 2048 分页，Scale 1..4，16px=64B 对齐与 TBitmap 同源；像素拷贝
 * 复用 bytes.ops Move 单源语义，inline 零拷贝；无 gpu.gl/platform.dl 硬依赖。
 *}
unit nextpas.core.gpu.canvas.impl;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.gpu.canvas.base,
  nextpas.core.gpu.canvas.intf,
  nextpas.core.graphics.base,
  nextpas.core.canvas.intf,
  nextpas.core.image.base;

function ScaleFactorForWindow(ADisplayScale: Single): Single; inline;
function AtlasAlloc(var AAtlas: TAtlas; AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;

type
  TGpuBatch = class(TInterfacedObject, IGpuBatch)
  private
    FAtlas: TAtlas;
  public
    constructor Create(APageW, APageH: Integer);
    function Alloc(AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;
    function AllocBitmap(const ABitmap: TBitmap; AScale: Single): TAtlasRegion;
    function AllocCanvas(ACanvas: ICanvas; AScale: Single): TAtlasRegion;
    procedure Reset;
    function GetAtlas: TAtlas;
    function ScaleForWindow(ADisplayScale: Single): Single;
  end;

function CreateGpuBatch(APageW, APageH: Integer): IGpuBatch; inline;

implementation

uses
  nextpas.core.errors,
  nextpas.core.math,
  nextpas.core.mem.base,
  nextpas.core.text.conv,
  nextpas.core.bytes.ops;

procedure GpuBlitRow(ASrc, ADst: PByte; ALen: SizeUInt); inline;
begin
  // bytes.ops 单源零拷贝：Move 语义与 ToCompact/FromCompact 同源，inline
  nextpas.core.bytes.ops.BytesCopy(ADst, ASrc, ALen);
end;

function ScaleFactorForWindow(ADisplayScale: Single): Single; inline;
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
  if (AWidth <= 0) or (AHeight <= 0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: alloc size must be >0 (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ')');
  if IsNaN(AScale) or IsInfinite(AScale) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scale must be finite (scale=' + FloatToStr(AScale) + ' w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ')');
  if AScale <= 0 then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scale must be >0 (scale=' + FloatToStr(AScale) + ' w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ')');
  FW := AWidth * AScale + 0.5;
  FH := AHeight * AScale + 0.5;
  if IsNaN(FW) or IsInfinite(FW) or IsNaN(FH) or IsInfinite(FH) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scaled size not finite (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ')');
  if (FW > High(Integer)) or (FH > High(Integer)) or (FW < 1) or (FH < 1) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: scaled size overflow (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ' scaledW=' + FloatToStr(FW) + ' scaledH=' + FloatToStr(FH) + ')');
  W := Trunc(FW);
  H := Trunc(FH);
  if (W <= 0) or (H <= 0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: alloc size must be >0 (w=' + IntToStr(AWidth) + ' h=' + IntToStr(AHeight) + ' scale=' + FloatToStr(AScale) + ' scaledW=' + IntToStr(W) + ' scaledH=' + IntToStr(H) + ')');
  AW := AlignUp(SizeUInt(W), MEM_CACHE_LINE_SIZE div 4);
  AH := AlignUp(SizeUInt(H), MEM_CACHE_LINE_SIZE div 4);
  if (AW = 0) or (AH = 0) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: aligned size overflow (w=' + IntToStr(W) + ' h=' + IntToStr(H) + ' scale=' + FloatToStr(AScale) + ')');
  if (AW > SizeUInt(High(Integer))) or (AH > SizeUInt(High(Integer))) then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: aligned size overflow (w=' + IntToStr(W) + ' h=' + IntToStr(H) + ' scale=' + FloatToStr(AScale) + ' aw=' + IntToStr(Int64(AW)) + ' ah=' + IntToStr(Int64(AH)) + ')');
  W := Integer(AW);
  H := Integer(AH);
  if W > AAtlas.PageWidth then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.pas: width exceeds atlas page (w=' + IntToStr(W) + ' pageW=' + IntToStr(AAtlas.PageWidth) + ' scale=' + FloatToStr(AScale) + ')');
  if AAtlas.CursorX + W > AAtlas.PageWidth then
  begin
    AAtlas.CursorX := 0;
    AAtlas.CursorY := AAtlas.CursorY + AAtlas.RowH;
    AAtlas.RowH := 0;
  end;
  if AAtlas.CursorY + H > AAtlas.PageHeight then
  begin
    Inc(AAtlas.PageCount);
    AAtlas.CursorX := 0;
    AAtlas.CursorY := 0;
    AAtlas.RowH := 0;
  end;
  Result.Page := AAtlas.PageCount - 1;
  Result.Rect := TRect.From(AAtlas.CursorX, AAtlas.CursorY, W, H);
  Result.Scale := AScale;
  Inc(AAtlas.CursorX, W);
  if H > AAtlas.RowH then AAtlas.RowH := H;
end;

constructor TGpuBatch.Create(APageW, APageH: Integer);
begin
  inherited Create;
  FAtlas := TAtlas.Create(APageW, APageH);
end;

function TGpuBatch.Alloc(AWidth, AHeight: Integer; AScale: Single): TAtlasRegion;
begin
  Result := AtlasAlloc(FAtlas, AWidth, AHeight, AScale);
end;

function TGpuBatch.AllocBitmap(const ABitmap: TBitmap; AScale: Single): TAtlasRegion;
var
  CW: Integer;
begin
  if ABitmap.IsEmpty then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.impl.pas: AllocBitmap on empty bitmap');
  // 零拷贝语义：调用方按 Region.Rect 将 ABitmap 紧凑行拷贝至上传缓冲，复用 bytes.ops Move 单源
  // 此处仅分配槽位，不拷贝；若需紧凑化，可用 ABitmap.ToCompact + bytes.ops.Move
  CW := ABitmap.Width;
  Result := AtlasAlloc(FAtlas, CW, ABitmap.Height, AScale);
  // 占位：演示 bytes.ops 单源复用（无额外堆）：若需行拷贝，外层可用 Move(ASrc^, ADst^, RowBytes)
  // 保持内联零拷贝路径由调用方按 Stride 对齐批量 Move，避免重复分配
end;

function TGpuBatch.AllocCanvas(ACanvas: ICanvas; AScale: Single): TAtlasRegion;
var
  LBmp: TBitmap;
begin
  if ACanvas = nil then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.impl.pas: AllocCanvas nil canvas');
  LBmp := ACanvas.Snapshot;
  if LBmp.IsEmpty then
    raise EArgumentError.Create('nextpas.core.gpu.canvas.impl.pas: AllocCanvas snapshot empty');
  Result := AllocBitmap(LBmp, AScale);
end;

procedure TGpuBatch.Reset;
begin
  FAtlas.Reset;
end;

function TGpuBatch.GetAtlas: TAtlas;
begin
  Result := FAtlas;
end;

function TGpuBatch.ScaleForWindow(ADisplayScale: Single): Single;
begin
  Result := ScaleFactorForWindow(ADisplayScale);
end;

function CreateGpuBatch(APageW, APageH: Integer): IGpuBatch; inline;
begin
  Result := TGpuBatch.Create(APageW, APageH);
end;

end.
