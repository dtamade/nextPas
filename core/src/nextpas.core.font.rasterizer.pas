unit nextpas.core.font.rasterizer;
{**
 * @desc 扫描线光栅化器：Bezier 自适应细分 → 边表 → 扫描线填充 → Alpha8 覆盖率位图。
 *       零外部依赖，纯 Pascal 实现。4x4 超采样抗锯齿。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.math,
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base;

const
  {** 超采样倍率 }
  FONT_RASTER_AA_SCALE = 4;

type
  {** 内部活跃边表条目 }
  TActiveEdge = record
    X: Single;       // 当前扫描线的 X 交叉位置
    StepX: Single;   // 每条扫描线的 X 步进 (InvSlope)
    Remain: Int32;   // 剩余扫描线数
  end;

  {** 纯 Pascal 扫描线光栅化器 }
  TFontRasterizer = class
  private
    FEdges: TFontEdgeArray;
    FEdgeCount: Int32;
    FActiveEdges: array of TActiveEdge;
    FActiveCount: Int32;
    procedure EdgeTableClear;
    procedure EdgeTableAddSegment(AX0, AY0, AX1, AY1: Single);
    procedure SortEdgeTable;
    procedure RasterizeSubPixel(ABitmap: PByte; AWidth, AHeight: Int32;
      const AOutline: TFontGlyphOutline; AAScale: Int32);
  public
    constructor Create;
    destructor Destroy; override;
    {** 光栅化字形轮廓为 Alpha8 位图。
        AOutline: 字形轮廓（font units）
        ASizePx: 目标字号（像素）
        AUnitsPerEm: 字体 units/em（通常 1000 或 2048） }
    function Rasterize(const AOutline: TFontGlyphOutline;
      ASizePx: Single; AUnitsPerEm: UInt16): TFontRasterResult;
  end;

{** 将二次 Bezier 曲线展平为线段列表（ADepth 内部递归深度，外部调用传 0） }
procedure FontFlattenQuadraticBezier(AP0X, AP0Y, AP1X, AP1Y, AP2X, AP2Y: Single;
  AFlatness: Single; var ALines: TFontLineSegmentArray; var ACount: Int32;
  ADepth: Int32 = 0);
{** 从轮廓提取线段列表（处理 on/off-curve 点） }
procedure FontExtractLineSegments(const AOutline: TFontGlyphOutline;
  out ALines: TFontLineSegmentArray);

implementation

{ ========================================================================= }
{ Bezier 展平                                                               }
{ ========================================================================= }

procedure FontFlattenQuadraticBezier(AP0X, AP0Y, AP1X, AP1Y, AP2X, AP2Y: Single;
  AFlatness: Single; var ALines: TFontLineSegmentArray; var ACount: Int32;
  ADepth: Int32);
var
  LMidX, LMidY, LDevX, LDevY, LDistSq: Single;
  LM01X, LM01Y, LM12X, LM12Y, LMMX, LMMY: Single;
begin
  LMidX := (AP0X + AP2X) * 0.5;
  LMidY := (AP0Y + AP2Y) * 0.5;
  LDevX := AP1X - LMidX;
  LDevY := AP1Y - LMidY;
  LDistSq := LDevX * LDevX + LDevY * LDevY;

  if (LDistSq <= AFlatness) or (ADepth >= RASTERIZER_MAX_SUBDIVISIONS) then
  begin
    if ACount >= Length(ALines) then
      SetLength(ALines, Length(ALines) + 16);
    ALines[ACount].X0 := AP0X;
    ALines[ACount].Y0 := AP0Y;
    ALines[ACount].X1 := AP2X;
    ALines[ACount].Y1 := AP2Y;
    Inc(ACount);
    Exit;
  end;

  LM01X := (AP0X + AP1X) * 0.5;
  LM01Y := (AP0Y + AP1Y) * 0.5;
  LM12X := (AP1X + AP2X) * 0.5;
  LM12Y := (AP1Y + AP2Y) * 0.5;
  LMMX := (LM01X + LM12X) * 0.5;
  LMMY := (LM01Y + LM12Y) * 0.5;

  FontFlattenQuadraticBezier(AP0X, AP0Y, LM01X, LM01Y, LMMX, LMMY,
    AFlatness, ALines, ACount, ADepth + 1);
  FontFlattenQuadraticBezier(LMMX, LMMY, LM12X, LM12Y, AP2X, AP2Y,
    AFlatness, ALines, ACount, ADepth + 1);
end;

procedure FontExtractLineSegments(const AOutline: TFontGlyphOutline;
  out ALines: TFontLineSegmentArray);
var
  LI, LJ, LNumPoints: Int32;
  LContourStart, LContourEnd, LIdx0, LIdx1, LIdx2: Int32;
  LOn0, LOn1: Boolean;
  LX0, LY0, LX1, LY1, LX2, LY2: Single;
  LCount: Int32;
begin
  SetLength(ALines, 0);
  if AOutline.ContourCount <= 0 then
    Exit;

  LNumPoints := Length(AOutline.Points);
  if LNumPoints <= 0 then
    Exit;

  SetLength(ALines, LNumPoints * 2);
  LCount := 0;

  for LI := 0 to AOutline.ContourCount - 1 do
  begin
    if LI = 0 then
      LContourStart := 0
    else
      LContourStart := AOutline.ContourEnds[LI - 1] + 1;
    LContourEnd := AOutline.ContourEnds[LI];

    if LContourEnd < LContourStart then
      Continue;

    LJ := LContourStart;
    while LJ <= LContourEnd do
    begin
      LIdx0 := LJ;
      LIdx1 := LJ + 1;
      if LIdx1 > LContourEnd then
        LIdx1 := LContourStart;

      LOn0 := AOutline.Points[LIdx0].OnCurve;
      LOn1 := AOutline.Points[LIdx1].OnCurve;

      if LOn0 and LOn1 then
      begin
        if LCount >= Length(ALines) then
          SetLength(ALines, Length(ALines) + 16);
        ALines[LCount].X0 := AOutline.Points[LIdx0].X;
        ALines[LCount].Y0 := AOutline.Points[LIdx0].Y;
        ALines[LCount].X1 := AOutline.Points[LIdx1].X;
        ALines[LCount].Y1 := AOutline.Points[LIdx1].Y;
        Inc(LCount);
        Inc(LJ);
      end
      else if LOn0 and (not LOn1) then
      begin
        LIdx2 := LJ + 2;
        if LIdx2 > LContourEnd then
          LIdx2 := LContourStart;

        LX0 := AOutline.Points[LIdx0].X;
        LY0 := AOutline.Points[LIdx0].Y;
        LX1 := AOutline.Points[LIdx1].X;
        LY1 := AOutline.Points[LIdx1].Y;
        LX2 := AOutline.Points[LIdx2].X;
        LY2 := AOutline.Points[LIdx2].Y;

        if AOutline.Points[LIdx2].OnCurve then
        begin
          FontFlattenQuadraticBezier(LX0, LY0, LX1, LY1, LX2, LY2,
            RASTERIZER_FLATNESS_PX, ALines, LCount, 0);
          Inc(LJ, 2);
        end
        else
        begin
          FontFlattenQuadraticBezier(LX0, LY0, LX1, LY1,
            (LX1 + LX2) * 0.5, (LY1 + LY2) * 0.5,
            RASTERIZER_FLATNESS_PX, ALines, LCount, 0);
          Inc(LJ);
        end;
      end
      else if (not LOn0) and (not LOn1) then
      begin
        LX0 := AOutline.Points[LIdx0].X;
        LY0 := AOutline.Points[LIdx0].Y;
        LX1 := AOutline.Points[LIdx1].X;
        LY1 := AOutline.Points[LIdx1].Y;

        LIdx2 := LJ + 2;
        if LIdx2 > LContourEnd then
          LIdx2 := LContourStart;

        if AOutline.Points[LIdx2].OnCurve then
        begin
          LX2 := AOutline.Points[LIdx2].X;
          LY2 := AOutline.Points[LIdx2].Y;
          FontFlattenQuadraticBezier(
            (LX0 + LX1) * 0.5, (LY0 + LY1) * 0.5,
            LX1, LY1, LX2, LY2,
            RASTERIZER_FLATNESS_PX, ALines, LCount, 0);
          Inc(LJ, 2);
        end
        else
        begin
          FontFlattenQuadraticBezier(
            (LX0 + LX1) * 0.5, (LY0 + LY1) * 0.5,
            LX1, LY1,
            (LX1 + LX2) * 0.5, (LY1 + LY2) * 0.5,
            RASTERIZER_FLATNESS_PX, ALines, LCount, 0);
          Inc(LJ);
        end;
      end
      else
        Inc(LJ);
    end;
  end;

  SetLength(ALines, LCount);
end;

{ ========================================================================= }
{ TFontRasterizer 构造/析构                                                 }
{ ========================================================================= }

constructor TFontRasterizer.Create;
begin
  inherited Create;
  FEdges := nil;
  FEdgeCount := 0;
  FActiveEdges := nil;
  FActiveCount := 0;
end;

destructor TFontRasterizer.Destroy;
begin
  SetLength(FEdges, 0);
  SetLength(FActiveEdges, 0);
  inherited Destroy;
end;

{ ========================================================================= }
{ 边表管理                                                                   }
{ ========================================================================= }

procedure TFontRasterizer.EdgeTableClear;
begin
  FEdgeCount := 0;
end;

procedure TFontRasterizer.EdgeTableAddSegment(AX0, AY0, AX1, AY1: Single);
var
  LYMin, LYMax, LXAtYMin: Single;
begin
  if Abs(AY1 - AY0) < 0.001 then
    Exit;

  if FEdgeCount >= Length(FEdges) then
    SetLength(FEdges, FEdgeCount + 64);

  if AY0 < AY1 then
  begin
    LYMin := AY0;
    LYMax := AY1;
    LXAtYMin := AX0;
  end
  else
  begin
    LYMin := AY1;
    LYMax := AY0;
    LXAtYMin := AX1;
  end;

  FEdges[FEdgeCount].YMin := LYMin;
  FEdges[FEdgeCount].YMax := LYMax;
  FEdges[FEdgeCount].XAtYMin := LXAtYMin;
  FEdges[FEdgeCount].InvSlope := (AX1 - AX0) / (AY1 - AY0);
  Inc(FEdgeCount);
end;

procedure TFontRasterizer.SortEdgeTable;
var
  LI, LJ: Int32;
  LTemp: TFontEdge;
begin
  for LI := 1 to FEdgeCount - 1 do
  begin
    LTemp := FEdges[LI];
    LJ := LI;
    while (LJ > 0) and (FEdges[LJ - 1].YMin > LTemp.YMin) do
    begin
      FEdges[LJ] := FEdges[LJ - 1];
      Dec(LJ);
    end;
    if LJ <> LI then
      FEdges[LJ] := LTemp;
  end;
end;

{ ========================================================================= }
{ 子像素扫描线光栅化（二值填充 + 偶奇规则）                                    }
{ ========================================================================= }

procedure TFontRasterizer.RasterizeSubPixel(ABitmap: PByte;
  AWidth, AHeight: Int32; const AOutline: TFontGlyphOutline;
  AAScale: Int32);
var
  LLines: TFontLineSegmentArray;
  LI, LJ: Int32;
  LScanY: Single;
  LEdgeIdx: Int32;
  LRem: Int32;
  LBaseX, LBaseY, LScale: Single;
  LRow: PByte;
  LInside: Boolean;
  LXLeft, LXRight: Int32;
  LTempAE: TActiveEdge;
  LX0, LY0, LX1, LY1: Single;
begin
  FontExtractLineSegments(AOutline, LLines);
  if Length(LLines) = 0 then
    Exit;

  FillChar(ABitmap^, AWidth * AHeight, 0);

  LScale := AAScale;
  LBaseX := -AOutline.XMin * LScale;
  LBaseY := -AOutline.YMin * LScale;
  EdgeTableClear;

  for LI := 0 to High(LLines) do
  begin
    LX0 := LLines[LI].X0 * LScale + LBaseX;
    LY0 := LLines[LI].Y0 * LScale + LBaseY;
    LX1 := LLines[LI].X1 * LScale + LBaseX;
    LY1 := LLines[LI].Y1 * LScale + LBaseY;
    EdgeTableAddSegment(LX0, LY0, LX1, LY1);
  end;

  if FEdgeCount = 0 then
    Exit;

  SortEdgeTable;

  if FEdgeCount > Length(FActiveEdges) then
    SetLength(FActiveEdges, FEdgeCount);

  LEdgeIdx := 0;
  FActiveCount := 0;
  LScanY := Trunc(FEdges[0].YMin);
  if LScanY < FEdges[0].YMin then
    LScanY := LScanY + 1.0;

  while (LScanY < AHeight) and ((FActiveCount > 0) or (LEdgeIdx < FEdgeCount)) do
  begin
    // 添加新进入的边
    while (LEdgeIdx < FEdgeCount) and (FEdges[LEdgeIdx].YMin <= LScanY) do
    begin
      FActiveEdges[FActiveCount].X := FEdges[LEdgeIdx].XAtYMin +
        (LScanY - FEdges[LEdgeIdx].YMin) * FEdges[LEdgeIdx].InvSlope;
      FActiveEdges[FActiveCount].StepX := FEdges[LEdgeIdx].InvSlope;
      LRem := Ceil(FEdges[LEdgeIdx].YMax - LScanY);
      if LRem < 1 then
        LRem := 1;
      FActiveEdges[FActiveCount].Remain := LRem;
      Inc(FActiveCount);
      Inc(LEdgeIdx);
    end;

    // 排序活跃边（按 X）
    for LI := 1 to FActiveCount - 1 do
    begin
      LTempAE := FActiveEdges[LI];
      LJ := LI;
      while (LJ > 0) and (FActiveEdges[LJ - 1].X > LTempAE.X) do
      begin
        FActiveEdges[LJ] := FActiveEdges[LJ - 1];
        Dec(LJ);
      end;
      if LJ <> LI then
        FActiveEdges[LJ] := LTempAE;
    end;

    // 偶奇规则：在每个交叉点翻转，奇数区间填充
    if FActiveCount >= 2 then
    begin
      LRow := ABitmap + Trunc(LScanY) * AWidth;
      LInside := False;
      for LJ := 0 to FActiveCount - 2 do
      begin
        LInside := not LInside;
        if LInside then
        begin
          LXLeft := Trunc(FActiveEdges[LJ].X);
          LXRight := Trunc(FActiveEdges[LJ + 1].X);
          for LI := Max(0, LXLeft) to Min(AWidth - 1, LXRight) do
            LRow[LI] := 255;
        end;
      end;
    end;

    // 推进扫描线
    LScanY := LScanY + 1.0;

    // 更新活跃边
    LI := 0;
    while LI < FActiveCount do
    begin
      FActiveEdges[LI].X := FActiveEdges[LI].X + FActiveEdges[LI].StepX;
      FActiveEdges[LI].Remain := FActiveEdges[LI].Remain - 1;
      if FActiveEdges[LI].Remain <= 0 then
      begin
        FActiveEdges[LI] := FActiveEdges[FActiveCount - 1];
        Dec(FActiveCount);
      end
      else
        Inc(LI);
    end;
  end;
end;

{ ========================================================================= }
{ 主光栅化 API                                                               }
{ ========================================================================= }

function TFontRasterizer.Rasterize(const AOutline: TFontGlyphOutline;
  ASizePx: Single; AUnitsPerEm: UInt16): TFontRasterResult;
var
  LWidth, LHeight, LSubW, LSubH: Int32;
  LSubBitmap: TBytes;
  LSI, LSJ: Int32;
  LX, LY, LI: Int32;
  LSum: UInt32;
  LAAScale: Int32;
  LScale: Single;
  LScaled: TFontGlyphOutline;
  LMinX, LMinY, LMaxX, LMaxY: Single;
begin
  FontRasterResultClear(Result);

  if AOutline.ContourCount <= 0 then
    Exit;
  if AUnitsPerEm = 0 then
    Exit;
  if ASizePx <= 0 then
    Exit;

  // 缩放轮廓：font units → pixels
  // 用原始轮廓边界计算位图尺寸，避免逐点舍入累积误差
  LScale := ASizePx / AUnitsPerEm;
  LWidth := Ceil(AOutline.XMax * LScale) - Floor(AOutline.XMin * LScale);
  LHeight := Ceil(AOutline.YMax * LScale) - Floor(AOutline.YMin * LScale);
  if (LWidth <= 0) or (LHeight <= 0) then
    Exit;

  // 缩放点坐标：Floor 去掉小数部分，与位图原点对齐
  LScaled.ContourCount := AOutline.ContourCount;
  SetLength(LScaled.ContourEnds, Length(AOutline.ContourEnds));
  for LI := 0 to High(AOutline.ContourEnds) do
    LScaled.ContourEnds[LI] := AOutline.ContourEnds[LI];

  SetLength(LScaled.Points, Length(AOutline.Points));
  for LI := 0 to High(AOutline.Points) do
  begin
    LScaled.Points[LI].X := Floor(AOutline.Points[LI].X * LScale) -
      Floor(AOutline.XMin * LScale);
    LScaled.Points[LI].Y := Floor(AOutline.Points[LI].Y * LScale) -
      Floor(AOutline.YMin * LScale);
    LScaled.Points[LI].OnCurve := AOutline.Points[LI].OnCurve;
  end;

  LScaled.XMin := 0;
  LScaled.YMin := 0;
  LScaled.XMax := LWidth;
  LScaled.YMax := LHeight;

  LAAScale := FONT_RASTER_AA_SCALE;
  LSubW := LWidth * LAAScale;
  LSubH := LHeight * LAAScale;

  SetLength(LSubBitmap, LSubW * LSubH);

  RasterizeSubPixel(@LSubBitmap[0], LSubW, LSubH, LScaled, LAAScale);

  // 下采样 4x4 块 → 平均值 → Alpha8
  SetLength(Result.Pixels, LWidth * LHeight);
  for LY := 0 to LHeight - 1 do
    for LX := 0 to LWidth - 1 do
    begin
      LSum := 0;
      for LSI := 0 to LAAScale - 1 do
        for LSJ := 0 to LAAScale - 1 do
          Inc(LSum, LSubBitmap[(LY * LAAScale + LSI) * LSubW + LX * LAAScale + LSJ]);
      Result.Pixels[LY * LWidth + LX] :=
        Byte(Min(255, LSum div (LAAScale * LAAScale)));
    end;

  Result.WidthPx := LWidth;
  Result.HeightPx := LHeight;
  Result.BearingXPx := LScaled.XMin;
  Result.BearingYPx := LScaled.YMax;
  Result.AdvancePx := LWidth;
  Result.PitchBytes := LWidth;
end;

end.
