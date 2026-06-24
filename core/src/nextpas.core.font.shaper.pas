unit nextpas.core.font.shaper;
{**
 * @desc 精简版文本塑形器：cmap 查找 + hmtx 步进宽度。
 *       逐字塑形（无连字、无字距调整、无复杂塑形）。
 *       设计为终端渲染场景的最小化实现。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.font.base,
  nextpas.core.font.ttface;

type
  {** 塑形输出条目 }
  TFontShapedGlyph = record
    GlyphIndex: UInt32;    // 字形索引（0 = .notdef）
    Codepoint: UInt32;     // 原始 Unicode 码位
    AdvanceWidth: UInt16;  // 水平步进（font units）
    LeftSideBearing: Int16; // 左侧边距（font units）
  end;

  {** 塑形输出序列 }
  TFontShapedGlyphArray = array of TFontShapedGlyph;

  {** 精简版文本塑形器：cmap + hmtx + kern + ligature }
  TFontLiteShaper = class
  private
    FFace: TTFontFace;
  public
    {** 创建塑形器（AFontFace 不归本对象所有，调用方需保活） }
    constructor Create(AFontFace: TTFontFace);
    destructor Destroy; override;
    {** 塑形单个 codepoint }
    function ShapeCodepoint(ACodepoint: UInt32): TFontShapedGlyph;
    {** 塑形 codepoint 序列，应用 kern 调整和连字替换。
        返回的字形数可能少于输入（连字合并时）。 }
    function ShapeString(const ACodepoints: array of UInt32): TFontShapedGlyphArray;
    {** 获取字形水平步进宽度（font units） }
    function GetAdvanceWidth(ACodepoint: UInt32): UInt16;
    {** font units → 像素转换 }
    function FontUnitsToPixels(AFontUnits, AFontSizePx: Int32): Single;
    {** 查找 kern 对调整值（font units） }
    function GetKernAdjust(ALeftCodepoint, ARightCodepoint: UInt32): Int16;
  end;

implementation

{ ========================================================================= }
{ TFontLiteShaper                                                           }
{ ========================================================================= }

constructor TFontLiteShaper.Create(AFontFace: TTFontFace);
begin
  inherited Create;
  if AFontFace = nil then
    raise EArgumentNil.Create('AFontFace');
  if not AFontFace.IsValid then
    raise EInvalidArgument.Create('AFontFace is not valid');
  FFace := AFontFace;
end;

destructor TFontLiteShaper.Destroy;
begin
  FFace := nil;
  inherited Destroy;
end;

function TFontLiteShaper.ShapeCodepoint(ACodepoint: UInt32): TFontShapedGlyph;
var
  LGlyphIdx: UInt32;
  LHMetric: TFontHorizontalMetric;
begin
  LGlyphIdx := FFace.LookupCodepoint(ACodepoint);
  LHMetric := FFace.GlyphHorizontalMetric(LGlyphIdx);

  Result.GlyphIndex := LGlyphIdx;
  Result.Codepoint := ACodepoint;
  Result.AdvanceWidth := LHMetric.AdvanceWidth;
  Result.LeftSideBearing := LHMetric.LeftSideBearing;
end;

function TFontLiteShaper.ShapeString(
  const ACodepoints: array of UInt32): TFontShapedGlyphArray;
var
  LI, LCount, LOut, LK, LM: Int32;
  LGlyphs: array of UInt16;
  LLigGlyph: UInt16;
  LKernVal: Int16;
  LSubArr: array of UInt16;
  LTotalAdvance: Int32;
begin
  LCount := Length(ACodepoints);
  if LCount = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // First pass: basic shape (cmap + hmtx).
  SetLength(Result, LCount);
  SetLength(LGlyphs, LCount);
  for LI := 0 to LCount - 1 do
  begin
    Result[LI] := ShapeCodepoint(ACodepoints[LI]);
    LGlyphs[LI] := Result[LI].GlyphIndex;
  end;

  // Second pass: ligature substitution.
  LOut := 0;
  LI := 0;
  while LI < LCount do
  begin
    // Try to find a ligature starting at LI.
    if (LI + 1 < LCount) and FFace.HasLigatures then
    begin
      // Try progressively longer sequences.
      LLigGlyph := 0;
      for LK := LCount downto LI + 2 do
      begin
        // Build glyph sub-array.
        SetLength(LSubArr, LK - LI);
        for LM := 0 to LK - LI - 1 do
          LSubArr[LM] := LGlyphs[LI + LM];
        LLigGlyph := FFace.LookupLigature(LSubArr);
        if LLigGlyph <> 0 then
        begin
          // Replace first glyph with ligature glyph.
          Result[LOut].GlyphIndex := LLigGlyph;
          Result[LOut].Codepoint := ACodepoints[LI];
          // Ligature advance = sum of component advances.
          LTotalAdvance := 0;
          for LM := LI to LK - 1 do
            LTotalAdvance := LTotalAdvance + Result[LM].AdvanceWidth;
          Result[LOut].AdvanceWidth := LTotalAdvance;
          Result[LOut].LeftSideBearing := Result[LI].LeftSideBearing;
          Inc(LOut);
          LI := LK;  // Skip consumed components.
          Break;
        end;
      end;
      if LLigGlyph <> 0 then
        Continue;
    end;

    // No ligature — copy glyph as-is.
    if LOut <> LI then
      Result[LOut] := Result[LI];
    Inc(LOut);
    Inc(LI);
  end;
  SetLength(Result, LOut);

  // Third pass: kern adjustment (adjust advance of preceding glyph).
  if FFace.HasKernPairs then
    for LI := 0 to High(Result) - 1 do
    begin
      LKernVal := FFace.LookupKern(Result[LI].GlyphIndex, Result[LI + 1].GlyphIndex);
      if LKernVal <> 0 then
        Result[LI].AdvanceWidth := Result[LI].AdvanceWidth + LKernVal;
    end;
end;

function TFontLiteShaper.GetAdvanceWidth(ACodepoint: UInt32): UInt16;
var
  LGlyphIdx: UInt32;
begin
  LGlyphIdx := FFace.LookupCodepoint(ACodepoint);
  Result := FFace.GlyphHorizontalMetric(LGlyphIdx).AdvanceWidth;
end;

function TFontLiteShaper.FontUnitsToPixels(AFontUnits, AFontSizePx: Int32): Single;
var
  LMetrics: TFontMetrics;
begin
  LMetrics := FFace.Metrics;
  if LMetrics.UnitsPerEm > 0 then
    Result := AFontUnits * AFontSizePx / LMetrics.UnitsPerEm
  else
    Result := 0;
end;

function TFontLiteShaper.GetKernAdjust(ALeftCodepoint, ARightCodepoint: UInt32): Int16;
var
  LLeftGid, LRightGid: UInt32;
begin
  if not FFace.HasKernPairs then
    Exit(0);
  LLeftGid := FFace.LookupCodepoint(ALeftCodepoint);
  LRightGid := FFace.LookupCodepoint(ARightCodepoint);
  Result := FFace.LookupKern(LLeftGid, LRightGid);
end;

end.
