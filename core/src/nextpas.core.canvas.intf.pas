{**
 * nextpas.core.canvas.intf - ICanvas 接口与画刷/文本薄层类型
 * L2，不依 gpu/font，TGlyphRun 仅位置与 Scale。
 *}
unit nextpas.core.canvas.intf;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.canvas.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.graphics.text,
  nextpas.core.image.base;

type
  TFilterQuality = nextpas.core.canvas.base.TFilterQuality;

  TBrushKind = (bkSolid, bkLinearGradient, bkRadialGradient);

  TBrush = record
  private
    FKind: TBrushKind;
    FColor: TColor32;
    FGradient: TGradient;
  public
    class function Solid(AColor: TColor32): TBrush; static;
    class function Linear(const AGrad: TGradient): TBrush; static;
    class function Radial(const AGrad: TGradient): TBrush; static;
    function WithTransform(const M: TMat2D): TBrush; inline;
    function WithOpacity(A: Single): TBrush;
    property Kind: TBrushKind read FKind;
    property Color: TColor32 read FColor;
    property Gradient: TGradient read FGradient;
  end;

  TGlyphRun = nextpas.core.graphics.text.TGlyphRun;

  ICanvas = interface
    ['{A1B2C3D4-E5F6-47A8-9B0C-1D2E3F4A5B6C}']
    procedure Save;
    procedure Restore;
    procedure Concat(const AMat: TMat2D);
    procedure ClipPath(const APath: TPath);
    procedure ClipRect(const AR: TRect);
    procedure FillPath(const APath: TPath; const ABrush: TBrush);
    procedure StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
    procedure DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
    procedure DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
    function Snapshot: TBitmap; // 供测试 golden 取图
  end;

  ICanvasGuard = interface
    ['{B2C3D4E5-F6A7-8901-BCDE-222222000002}']
  end;

function AutoSave(ACanvas: ICanvas): ICanvasGuard;

implementation

uses
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.math;

type
  TCanvasGuard = class(TInterfacedObject, ICanvasGuard)
  private
    FCanvas: ICanvas;
  public
    constructor Create(ACanvas: ICanvas);
    destructor Destroy; override;
  end;

constructor TCanvasGuard.Create(ACanvas: ICanvas);
begin
  inherited Create;
  FCanvas := ACanvas;
  if FCanvas <> nil then FCanvas.Save;
end;

destructor TCanvasGuard.Destroy;
begin
  if FCanvas <> nil then
    try FCanvas.Restore; except end;
  inherited Destroy;
end;

function AutoSave(ACanvas: ICanvas): ICanvasGuard;
begin
  Result := TCanvasGuard.Create(ACanvas);
end;

class function TBrush.Solid(AColor: TColor32): TBrush;
begin
  Result.FKind := bkSolid;
  Result.FColor := AColor;
  Result.FGradient := Default(TGradient);
end;

class function TBrush.Linear(const AGrad: TGradient): TBrush;
begin
  if AGrad.Kind <> gkLinear then
    raise EColorError.Create('nextpas.core.canvas.intf.pas: TBrush.Linear: gradient kind mismatch (expected gkLinear)');
  Result.FKind := bkLinearGradient;
  Result.FColor := TColor32(0);
  Result.FGradient := AGrad;
end;

class function TBrush.Radial(const AGrad: TGradient): TBrush;
begin
  if AGrad.Kind <> gkRadial then
    raise EColorError.Create('nextpas.core.canvas.intf.pas: TBrush.Radial: gradient kind mismatch (expected gkRadial)');
  Result.FKind := bkRadialGradient;
  Result.FColor := TColor32(0);
  Result.FGradient := AGrad;
end;

function TBrush.WithTransform(const M: TMat2D): TBrush;
begin
  Result := Self;
  if Result.FKind = bkSolid then Exit;
  Result.FGradient := Result.FGradient.WithTransform(M);
end;

function TBrush.WithOpacity(A: Single): TBrush;
var
  Rgba: TRgba;
  LOpacity: Single;
begin
  LOpacity := A;
  if IsNaN(LOpacity) or IsInfinite(LOpacity) then
    raise EColorError.Create('nextpas.core.canvas.intf.pas: TBrush.WithOpacity: opacity must be finite');
  if (LOpacity < -1e-6) or (LOpacity > 1+1e-6) then
    raise EColorError.Create('nextpas.core.canvas.intf.pas: TBrush.WithOpacity: opacity out of [0,1]');
  if LOpacity < 0 then LOpacity := 0 else if LOpacity > 1 then LOpacity := 1;
  Result := Self;
  if Result.FKind = bkSolid then
  begin
    Rgba := Color32ToRgba(Result.FColor);
    Rgba.A := Rgba.A * LOpacity;
    Result.FColor := RgbaToColor32(Rgba);
  end
  else
    Result.FGradient := Result.FGradient.WithOpacity(LOpacity);
end;

end.
