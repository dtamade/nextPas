{ nextpas.core.canvas.raster - CPU raster }
unit nextpas.core.canvas.raster;
{$I nextpas.core.settings.inc}
{$modeswitch advancedrecords}
interface
uses
  nextpas.core.canvas.base,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.image.base,
  nextpas.core.vector.tess,
  nextpas.core.vector.path,
  nextpas.core.canvas.intf;
type
  TCanvasState = record Mat: TMat2D; Clip: TPath; HasClip: Boolean; ClipR: TRect; end;
  TRasterCanvas = class(TInterfacedObject, ICanvas)
  private
    FBitmap: TBitmap;
    FStack: array of TCanvasState;
    FClip: TPath;
    FHasClip: Boolean;
    FClipR: TRect;
    FMat: TMat2D;
    procedure FillTrapezoids(const ATraps: array of TTrapezoid; AColor: TColor32);
    procedure FillTrapezoidsGradient(const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean);
    function TransformPoly(const APoly: array of TVec2): TPoly;
  public
    constructor Create(AWidth, AHeight: Integer);
    procedure Save; procedure Restore;
    procedure Concat(const AMat: TMat2D);
    procedure ClipPath(const APath: TPath);
    procedure ClipRect(const AR: TRect);
    procedure FillPath(const APath: TPath; const ABrush: TBrush);
    procedure StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
    procedure DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
    procedure DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
    function Snapshot: TBitmap;
  end;
function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
implementation
uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.graphics.errors,
  nextpas.core.math,
  nextpas.core.text.layout,
  nextpas.core.canvas.raster.fill,
  nextpas.core.canvas.raster.bitmap;
const TILE=16; MAX_SAVE_STACK=64;
function CreateRasterCanvas(AWidth, AHeight: Integer): ICanvas;
begin
  Result:=TRasterCanvas.Create(AWidth,AHeight);
end;
constructor TRasterCanvas.Create(AWidth, AHeight: Integer);
begin
  if (AWidth<=0) or (AHeight<=0) then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: width/height must be > 0');
  if (AWidth>16384) or (AHeight>16384) then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: exceeds 16384');
  inherited Create;
  try
    FBitmap:=TBitmap.Create(AWidth,AHeight,bfRGBA);
  except
    on E:EArgumentError do
      raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Create: '+E.Message);
  end;
  FMat:=TMat2D.Identity;
  FHasClip:=False;
end;
procedure TRasterCanvas.Save;
begin
  if Length(FStack)>=MAX_SAVE_STACK then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Save: stack overflow');
  SetLength(FStack,Length(FStack)+1);
  FStack[High(FStack)].Mat:=FMat;
  FStack[High(FStack)].Clip:=FClip;
  FStack[High(FStack)].HasClip:=FHasClip;
  FStack[High(FStack)].ClipR:=FClipR;
end;
procedure TRasterCanvas.Restore;
begin
  if Length(FStack)=0 then
    raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.Restore: stack underflow');
  FMat:=FStack[High(FStack)].Mat;
  FClip:=FStack[High(FStack)].Clip;
  FHasClip:=FStack[High(FStack)].HasClip;
  FClipR:=FStack[High(FStack)].ClipR;
  SetLength(FStack,Length(FStack)-1);
end;
procedure TRasterCanvas.Concat(const AMat: TMat2D);
begin
  FMat:=FMat.Concat(AMat);
end;
procedure TRasterCanvas.ClipPath(const APath: TPath);
var Poly: TPoly; R: TRect; Ix,Iy,Ix2,Iy2: Single;
begin
  if APath.IsEmpty then Exit;
  Poly:=PathFlatten(APath,0.25);
  Poly:=TransformPoly(Poly);
  if Length(Poly)=0 then Exit;
  R:=PolyBounds(Poly);
  if R.IsEmpty then begin FClipR:=R; FClip:=APath; FHasClip:=True; Exit; end;
  if not FHasClip then begin FClip:=APath; FClipR:=R; FHasClip:=True; Exit; end;
  Ix:=FClipR.X; if R.X>Ix then Ix:=R.X;
  Iy:=FClipR.Y; if R.Y>Iy then Iy:=R.Y;
  Ix2:=FClipR.X+FClipR.W; if R.X+R.W<Ix2 then Ix2:=R.X+R.W;
  Iy2:=FClipR.Y+FClipR.H; if R.Y+R.H<Iy2 then Iy2:=R.Y+R.H;
  if (Ix2<=Ix) or (Iy2<=Iy) then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  FClipR:=TRect.From(Ix,Iy,Ix2-Ix,Iy2-Iy);
  FClip:=PathIntersect(FClip,APath);
end;
procedure TRasterCanvas.ClipRect(const AR: TRect);
var Poly: TPoly; R: TRect; P: TPath; Ix,Iy,Ix2,Iy2: Single;
begin
  if AR.IsEmpty then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  P:=TPath.New.MoveTo(AR.X,AR.Y).LineTo(AR.X+AR.W,AR.Y).LineTo(AR.X+AR.W,AR.Y+AR.H).LineTo(AR.X,AR.Y+AR.H).Close;
  Poly:=PathFlatten(P,0.25);
  Poly:=TransformPoly(Poly);
  if Length(Poly)=0 then Exit;
  R:=PolyBounds(Poly);
  if not FHasClip then begin FClip:=P; FClipR:=R; FHasClip:=True; Exit; end;
  Ix:=FClipR.X; if R.X>Ix then Ix:=R.X;
  Iy:=FClipR.Y; if R.Y>Iy then Iy:=R.Y;
  Ix2:=FClipR.X+FClipR.W; if R.X+R.W<Ix2 then Ix2:=R.X+R.W;
  Iy2:=FClipR.Y+FClipR.H; if R.Y+R.H<Iy2 then Iy2:=R.Y+R.H;
  if (Ix2<=Ix) or (Iy2<=Iy) then begin FClipR:=TRect.From(0,0,0,0); FClip:=TPath.New; FHasClip:=True; Exit; end;
  FClipR:=TRect.From(Ix,Iy,Ix2-Ix,Iy2-Iy);
  FClip:=PathIntersect(FClip,P);
end;
function TRasterCanvas.TransformPoly(const APoly: array of TVec2): TPoly;
var I: Integer;
begin
  SetLength(Result,Length(APoly));
  for I:=0 to High(APoly) do Result[I]:=FMat.TransformPoint(APoly[I]);
end;
procedure TRasterCanvas.FillTrapezoids(const ATraps: array of TTrapezoid; AColor: TColor32);
begin
  nextpas.core.canvas.raster.fill.FillTrapezoids(FBitmap, ATraps, AColor, FClipR, FHasClip);
end;
procedure TRasterCanvas.FillTrapezoidsGradient(const ATraps: array of TTrapezoid; const AGrad: TGradient; const ABounds: TRect; ARadial: Boolean);
begin
  nextpas.core.canvas.raster.fill.FillTrapezoidsGradient(FBitmap, ATraps, AGrad, ABounds, ARadial, FClipR, FHasClip);
end;
procedure TRasterCanvas.FillPath(const APath: TPath; const ABrush: TBrush);
var Poly: TPoly; Traps: TTrapezoids; Bounds: TRect;
begin
  if APath.IsEmpty then Exit;
  Poly:=PathFlatten(APath,0.25);
  Poly:=TransformPoly(Poly);
  if Length(Poly)=0 then Exit;
  Bounds:=PolyBounds(Poly);
  Traps:=TessellatePoly(Poly);
  case ABrush.Kind of
    bkSolid: FillTrapezoids(Traps,ABrush.Color);
    bkLinearGradient: begin
      if ABrush.Gradient.ColorCount=0 then
        raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.FillPath: gradient no colors');
      FillTrapezoidsGradient(Traps,ABrush.Gradient,Bounds,False);
    end;
    bkRadialGradient: begin
      if ABrush.Gradient.ColorCount=0 then
        raise ECanvasError.Create('nextpas.core.canvas.raster.pas: TRasterCanvas.FillPath: gradient no colors');
      FillTrapezoidsGradient(Traps,ABrush.Gradient,Bounds,True);
    end;
  end;
end;
procedure TRasterCanvas.StrokePath(const APath: TPath; const ABrush: TBrush; const AOpts: TStrokeOptions);
var Stroked: TPath;
begin
  Stroked:=PathStroke(APath,AOpts);
  FillPath(Stroked,ABrush);
end;
procedure TRasterCanvas.DrawBitmap(const ABitmap: TBitmap; const ASrc, ADst: TRect; AQuality: TFilterQuality);
var ScaleX,ScaleY: Single;
begin
  if ABitmap.IsEmpty or ADst.IsEmpty or ASrc.IsEmpty then Exit;
  if FBitmap.IsEmpty or ABitmap.IsEmpty then Exit;
  if IsNaN(ASrc.X) or IsInfinite(ASrc.X) or IsNaN(ASrc.Y) or IsInfinite(ASrc.Y) or
     IsNaN(ASrc.W) or IsInfinite(ASrc.W) or IsNaN(ASrc.H) or IsInfinite(ASrc.H) or
     IsNaN(ADst.X) or IsInfinite(ADst.X) or IsNaN(ADst.Y) or IsInfinite(ADst.Y) or
     IsNaN(ADst.W) or IsInfinite(ADst.W) or IsNaN(ADst.H) or IsInfinite(ADst.H) then
    raise EArgumentError.CreateFmt('nextpas.core.canvas.raster.pas: TRasterCanvas.DrawBitmap: NaN/Inf ASrc=(%.2f,%.2f,%.2f,%.2f) ADst=(%.2f,%.2f,%.2f,%.2f)',[ASrc.X,ASrc.Y,ASrc.W,ASrc.H,ADst.X,ADst.Y,ADst.W,ADst.H]);
  if (Abs(ASrc.W)>High(Integer)) or (Abs(ASrc.H)>High(Integer)) or (Abs(ADst.W)>High(Integer)) or (Abs(ADst.H)>High(Integer)) or (Abs(ASrc.X)>High(Integer)) or (Abs(ASrc.Y)>High(Integer)) or (Abs(ADst.X)>High(Integer)) or (Abs(ADst.Y)>High(Integer)) then
    raise EArgumentError.CreateFmt('nextpas.core.canvas.raster.pas: TRasterCanvas.DrawBitmap: rect overflow ASrc=(%.2f,%.2f,%.2f,%.2f) ADst=(%.2f,%.2f,%.2f,%.2f)',[ASrc.X,ASrc.Y,ASrc.W,ASrc.H,ADst.X,ADst.Y,ADst.W,ADst.H]);
  if (Abs(ADst.W)<EPSILON) or (Abs(ADst.H)<EPSILON) then
    raise EArgumentError.CreateFmt('nextpas.core.canvas.raster.pas: TRasterCanvas.DrawBitmap: dst too small ADst=(%.2f,%.2f,%.2f,%.2f)',[ADst.X,ADst.Y,ADst.W,ADst.H]);
  ScaleX:=ASrc.W/ADst.W;
  ScaleY:=ASrc.H/ADst.H;
  if IsNaN(ScaleX) or IsInfinite(ScaleX) or IsNaN(ScaleY) or IsInfinite(ScaleY) then
    raise EArgumentError.CreateFmt('nextpas.core.canvas.raster.pas: TRasterCanvas.DrawBitmap: scale NaN/Inf ASrc=(%.2f,%.2f,%.2f,%.2f) ADst=(%.2f,%.2f,%.2f,%.2f)',[ASrc.X,ASrc.Y,ASrc.W,ASrc.H,ADst.X,ADst.Y,ADst.W,ADst.H]);
  if (Abs(ScaleX)>16384) or (Abs(ScaleY)>16384) then
    raise EArgumentError.CreateFmt('nextpas.core.canvas.raster.pas: TRasterCanvas.DrawBitmap: scale cap %.2f x %.2f ASrc=(%.2f,%.2f,%.2f,%.2f) ADst=(%.2f,%.2f,%.2f,%.2f)',[ScaleX,ScaleY,ASrc.X,ASrc.Y,ASrc.W,ASrc.H,ADst.X,ADst.Y,ADst.W,ADst.H]);
  BitmapBlit(FBitmap, ABitmap, ASrc, ADst, AQuality, FClipR, FHasClip);
end;
procedure TRasterCanvas.DrawGlyphRun(const ARun: TGlyphRun; const APos: TVec2);
const GlyphAdvanceFallback=8.0; GlyphAdvanceMinCells=6.0; GlyphAdvanceMaxCells=20.0; AdvanceMinPx=2.0; GlyphWidthRatio=0.78; GlyphInsetRatio=0.11; GlyphHeightCells=10.0; GlyphBaselineRatio=0.78; GlyphCornerRadius=1.0;
var I: Integer; R: TRect; P: TPath; Brush: TBrush; W,H,Adv,CR,LX,LY: Single;
  function BuildRoundedRect(const AR: TRect; ARad: Single): TPath; inline;
  begin
    if ARad<0.5 then ARad:=0.5;
    if ARad>AR.W*0.5 then ARad:=AR.W*0.5;
    if ARad>AR.H*0.5 then ARad:=AR.H*0.5;
    Result:=TPath.New.MoveTo(AR.X+ARad,AR.Y).LineTo(AR.X+AR.W-ARad,AR.Y).QuadTo(AR.X+AR.W,AR.Y,AR.X+AR.W,AR.Y+ARad).LineTo(AR.X+AR.W,AR.Y+AR.H-ARad).QuadTo(AR.X+AR.W,AR.Y+AR.H,AR.X+AR.W-ARad,AR.Y+AR.H).LineTo(AR.X+ARad,AR.Y+AR.H).QuadTo(AR.X,AR.Y+AR.H,AR.X,AR.Y+AR.H-ARad).LineTo(AR.X,AR.Y+ARad).QuadTo(AR.X,AR.Y,AR.X+ARad,AR.Y).Close;
  end;
  function ResolveAdvance(AIdx: Integer; AScale: Single): Single; inline;
  var LPrev: Single; LGlyph: LongWord; LAdvLay: Single;
  begin
    if (AIdx>=0) and (AIdx<High(ARun.Positions)) then begin Result:=ARun.Positions[AIdx+1].X-ARun.Positions[AIdx].X; if (Result>=AdvanceMinPx) and (Result<=GlyphAdvanceMaxCells*AScale) and (not IsNaN(Result)) and (not IsInfinite(Result)) then Exit; end
    else if AIdx<High(ARun.Positions) then begin Result:=ARun.Positions[AIdx+1].X-ARun.Positions[AIdx].X; if (Result>=AdvanceMinPx) and (Result<=GlyphAdvanceMaxCells*AScale) and (not IsNaN(Result)) and (not IsInfinite(Result)) then Exit; end;
    if (AIdx>0) and (AIdx<Length(ARun.Positions)) then begin LPrev:=ARun.Positions[AIdx].X-ARun.Positions[AIdx-1].X; if (LPrev>=AdvanceMinPx) and (LPrev<=GlyphAdvanceMaxCells*AScale) and (not IsNaN(LPrev)) and (not IsInfinite(LPrev)) then begin Result:=LPrev; Exit; end; end;
    if (AIdx>=0) and (AIdx<Length(ARun.Glyphs)) then begin LGlyph:=ARun.Glyphs[AIdx]; LAdvLay:=LayoutGlyphAdvance(LGlyph,10,AScale); if IsNaN(LAdvLay) or IsInfinite(LAdvLay) then LAdvLay:=GlyphAdvanceFallback*AScale; if LAdvLay<AdvanceMinPx then LAdvLay:=GlyphAdvanceMinCells*AScale; if LAdvLay>GlyphAdvanceMaxCells*AScale then LAdvLay:=GlyphAdvanceFallback*AScale; Result:=LAdvLay; Exit; end;
    Result:=GlyphAdvanceFallback*AScale;
    if Result<AdvanceMinPx then Result:=GlyphAdvanceMinCells*AScale;
    if Result>GlyphAdvanceMaxCells*AScale then Result:=GlyphAdvanceFallback*AScale;
  end;
begin
  if ARun.IsEmpty then Exit;
  if IsNaN(ARun.Scale) or IsInfinite(ARun.Scale) or (ARun.Scale<=0) then Exit;
  if IsNaN(APos.X) or IsInfinite(APos.X) or IsNaN(APos.Y) or IsInfinite(APos.Y) then Exit;
  Brush:=TBrush.Solid(Color32(24,24,24));
  CR:=GlyphCornerRadius*ARun.Scale;
  if CR<0.5 then CR:=0.5;
  if CR>2.5*ARun.Scale then CR:=1.0*ARun.Scale;
  for I:=0 to High(ARun.Glyphs) do begin
    if ARun.Glyphs[I]=32 then Continue;
    Adv:=ResolveAdvance(I,ARun.Scale);
    if IsNaN(Adv) or IsInfinite(Adv) then Adv:=GlyphAdvanceFallback*ARun.Scale;
    if Adv<AdvanceMinPx then Adv:=GlyphAdvanceMinCells*ARun.Scale;
    if Adv>GlyphAdvanceMaxCells*ARun.Scale then Adv:=GlyphAdvanceFallback*ARun.Scale;
    W:=Adv*GlyphWidthRatio; H:=GlyphHeightCells*ARun.Scale;
    if W<1 then W:=1; if H<1 then H:=1;
    LX:=Round(APos.X+ARun.Positions[I].X+Adv*GlyphInsetRatio);
    LY:=Round(APos.Y+ARun.Positions[I].Y-H*GlyphBaselineRatio);
    R:=TRect.From(LX,LY,Round(W),Round(H));
    P:=BuildRoundedRect(R,CR);
    FillPath(P,Brush);
  end;
end;
function TRasterCanvas.Snapshot: TBitmap;
begin
  Result:=FBitmap.Clone;
end;
end.
