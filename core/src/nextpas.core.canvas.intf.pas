{**
 * nextpas.core.canvas.intf - ICanvas 接口与画刷/文本薄层类型
 * L2，不依 gpu/font，TGlyphRun 仅位置与 Scale。
 *}
unit nextpas.core.canvas.intf;

{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.graphics.text,
  nextpas.core.image.base;

type
  TFilterQuality = (fqNearest, fqLinear, fqCubic);

  TBrushKind = (bkSolid, bkLinearGradient, bkRadialGradient);

  TBrush = record
  private
    FKind: TBrushKind;
    FColor: TColor32;
    FGradient: TGradient;
    class procedure ValidateGradient(const AGrad: TGradient; AExpected: TGradientKind); static;
  public
    class function Solid(AColor: TColor32): TBrush; static;
    class function Linear(const AGrad: TGradient): TBrush; overload; static;
    class function Radial(const AGrad: TGradient): TBrush; overload; static;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray): TBrush; overload; static;
    class function Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TBrush; overload; static;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray): TBrush; overload; static;
    class function Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TBrush; overload; static;
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

class procedure TBrush.ValidateGradient(const AGrad: TGradient; AExpected: TGradientKind);
var
  Cc, Sc, I: Integer;
  S, Prev: Single;
begin
  Cc := AGrad.ColorCount;
  Sc := AGrad.StopCount;
  if Cc < 2 then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: gradient needs >=2 colors');
  if AGrad.Kind <> AExpected then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: gradient kind mismatch');
  if (Sc <> 0) and (Sc <> Cc) then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: stops/colors length mismatch');
  if Sc > 0 then
  begin
    Prev := -1;
    for I := 0 to Sc - 1 do
    begin
      S := AGrad.GetStop(I);
      if IsNaN(S) or IsInfinite(S) then
        raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: stop must be finite');
      if (S < -1e-6) or (S > 1+1e-6) then
        raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: stop out of [0,1]');
      if S < Prev - 1e-6 then
        raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush: stops must be monotonic');
      Prev := S;
    end;
  end;
end;

class function TBrush.Solid(AColor: TColor32): TBrush;
begin
  Result.FKind := bkSolid;
  Result.FColor := AColor;
  Result.FGradient := Default(TGradient);
end;

class function TBrush.Linear(const AGrad: TGradient): TBrush;
begin
  ValidateGradient(AGrad, gkLinear);
  Result.FKind := bkLinearGradient;
  Result.FColor := TColor32(0);
  Result.FGradient := AGrad;
end;

class function TBrush.Radial(const AGrad: TGradient): TBrush;
begin
  ValidateGradient(AGrad, gkRadial);
  Result.FKind := bkRadialGradient;
  Result.FColor := TColor32(0);
  Result.FGradient := AGrad;
end;

class function TBrush.Linear(const AColors: TColor32Array; const AStops: TSingleArray): TBrush;
begin
  Result := Linear(AColors, AStops, TMat2D.Identity);
end;

class function TBrush.Linear(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TBrush;
var
  G: TGradient;
begin
  G := TGradient.Create(gkLinear, AColors, AStops, ATransform);
  Result := Linear(G);
end;

class function TBrush.Radial(const AColors: TColor32Array; const AStops: TSingleArray): TBrush;
begin
  Result := Radial(AColors, AStops, TMat2D.Identity);
end;

class function TBrush.Radial(const AColors: TColor32Array; const AStops: TSingleArray; const ATransform: TMat2D): TBrush;
var
  G: TGradient;
begin
  G := TGradient.Create(gkRadial, AColors, AStops, ATransform);
  Result := Radial(G);
end;

function TBrush.WithTransform(const M: TMat2D): TBrush;
begin
  Result := Self;
  if Result.FKind = bkSolid then Exit;
  if IsNaN(M.A) or IsInfinite(M.A) or IsNaN(M.B) or IsInfinite(M.B) or
     IsNaN(M.C) or IsInfinite(M.C) or IsNaN(M.D) or IsInfinite(M.D) or
     IsNaN(M.Tx) or IsInfinite(M.Tx) or IsNaN(M.Ty) or IsInfinite(M.Ty) then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush.WithTransform: matrix must be finite');
  Result.FGradient := Result.FGradient.WithTransform(M);
end;

function TBrush.WithOpacity(A: Single): TBrush;
var
  Rgba: TRgba;
begin
  if IsNaN(A) or IsInfinite(A) then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush.WithOpacity: opacity must be finite');
  if (A < -1e-6) or (A > 1+1e-6) then
    raise EArgumentError.Create('nextpas.core.canvas.intf.pas: TBrush.WithOpacity: opacity out of [0,1]');
  if A < 0 then A := 0 else if A > 1 then A := 1;
  Result := Self;
  if Result.FKind = bkSolid then
  begin
    Rgba := Color32ToRgba(Result.FColor);
    Rgba.A := Rgba.A * A;
    Result.FColor := RgbaToColor32(Rgba);
  end
  else
    Result.FGradient := Result.FGradient.WithOpacity(A);
end;

end.
