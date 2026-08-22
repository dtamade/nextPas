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

const
  {** cmap 缓存桶数（必须是 2 的幂） }
  CMAP_CACHE_SIZE = 1024;
  CMAP_CACHE_MASK = CMAP_CACHE_SIZE - 1;
  CACHE_EMPTY = $FFFFFFFF;

type
  {** cmap 缓存条目 }
  TCmapCacheEntry = record
    Codepoint: UInt32;
    GlyphIndex: UInt32;
    AdvanceWidth: UInt16;
  end;

  {** 塑形输出条目 }
  TFontShapedGlyph = record
    GlyphIndex: UInt32;    // 字形索引（0 = .notdef）
    Codepoint: UInt32;     // 原始 Unicode 码位
    AdvanceWidth: UInt16;  // 水平步进（font units）
    LeftSideBearing: Int16; // 左侧边距（font units）
    MarkOffsetX: Int16;    // Mark attachment X 偏移（font units）
    MarkOffsetY: Int16;    // Mark attachment Y 偏移（font units）
  end;

  {** 塑形输出序列 }
  TFontShapedGlyphArray = array of TFontShapedGlyph;

  {** 精简版文本塑形器：cmap + hmtx + kern + ligature }
  TFontLiteShaper = class
  private
    FFace: TTFontFace;
    FCmapCache: array[0..CMAP_CACHE_SIZE - 1] of TCmapCacheEntry;
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
var
  LI: Int32;
begin
  inherited Create;
  if AFontFace = nil then
    raise EArgumentNil.Create('AFontFace');
  if not AFontFace.IsValid then
    raise EInvalidArgument.Create('AFontFace is not valid');
  FFace := AFontFace;
  // 初始化 cmap 缓存：标记所有条目为空。
  for LI := 0 to CMAP_CACHE_SIZE - 1 do
    FCmapCache[LI].Codepoint := CACHE_EMPTY;
end;

destructor TFontLiteShaper.Destroy;
begin
  FFace := nil;
  inherited Destroy;
end;

function TFontLiteShaper.ShapeCodepoint(ACodepoint: UInt32): TFontShapedGlyph;
var
  LIdx: UInt32;
  LGlyphIdx: UInt32;
  LHMetric: TFontHorizontalMetric;
begin
  // Direct-mapped cache lookup：O(1) 命中跳过二分查找。
  LIdx := ACodepoint and CMAP_CACHE_MASK;
  if FCmapCache[LIdx].Codepoint = ACodepoint then
  begin
    // Cache hit.
    Result.GlyphIndex := FCmapCache[LIdx].GlyphIndex;
    Result.Codepoint := ACodepoint;
    Result.AdvanceWidth := FCmapCache[LIdx].AdvanceWidth;
    Result.LeftSideBearing := 0; // 缓存不存 LSB，mark attachment 需要时再查。
    Exit;
  end;

  // Cache miss — 查找 cmap + hmtx。
  LGlyphIdx := FFace.LookupCodepoint(ACodepoint);
  LHMetric := FFace.GlyphHorizontalMetric(LGlyphIdx);

  // 写入缓存。
  FCmapCache[LIdx].Codepoint := ACodepoint;
  FCmapCache[LIdx].GlyphIndex := LGlyphIdx;
  FCmapCache[LIdx].AdvanceWidth := LHMetric.AdvanceWidth;

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
  LLigGlyph, LSubstGid: UInt16;
  LKernVal: Int16;
  LSubArr: array of UInt16;
  LTotalAdvance: Int32;
  LAnchor, LExitAnchor, LEntryAnchor: TFontAnchor;
  LNewResult: TFontShapedGlyphArray;
  LNewGlyphs: array of UInt16;
  LCtxRecords: TFontContextLookupRecordArray;
  LCtxSeqIdx, LCtxLookupIdx, LCtxTarget: Int32;
begin
  LCount := Length(ACodepoints);
  if LCount = 0 then
  begin
    Result := nil;
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

  // Pass 1: Ligature substitution（在 SingleSubst 之前，因为 liga 表引用原始 glyph ID）。
  // 优化：限制最大连字长度为 4（绝大多数连字 ≤ 4 glyph），避免 O(n²) 尝试。
  LOut := 0;
  LI := 0;
  while LI < LCount do
  begin
    // Try to find a ligature starting at LI.
    if (LI + 1 < LCount) and FFace.HasLigatures then
    begin
      // Try 2-glyph first (most common), then 3, 4.
      LLigGlyph := 0;
      LK := LI + 2;
      while LK <= LCount do
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
        Inc(LK);
        // 限制最大连字长度为 4。
        if LK - LI > 4 then
          Break;
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
  // 更新 LGlyphs 以匹配 Result。
  LCount := Length(Result);
  SetLength(LGlyphs, LCount);
  for LI := 0 to LCount - 1 do
    LGlyphs[LI] := Result[LI].GlyphIndex;

  // Pass 2: SingleSubst substitution（在 liga 之后）。
  if FFace.HasSingleSubst then
    for LI := 0 to LCount - 1 do
    begin
      LSubstGid := FFace.LookupSingleSubst(LGlyphs[LI]);
      if LSubstGid <> 0 then
      begin
        LGlyphs[LI] := LSubstGid;
        Result[LI].GlyphIndex := LSubstGid;
      end;
    end;

  // Pass 2.5: ContextSubst (contextual substitution).
  // Applies SingleSubst and MultipleSubst lookups at positions specified by context rules.
  // When a MultipleSubst lookup expands a glyph, the glyph array grows in-place.
  if FFace.HasContextSubst then
  begin
    for LI := 0 to LCount - 1 do
    begin
      for LK := 0 to FFace.ContextSubstCount - 1 do
      begin
        LCtxRecords := FFace.MatchContextSubst(LK, LGlyphs, LI);
        if Length(LCtxRecords) > 0 then
        begin
          for LM := 0 to High(LCtxRecords) do
          begin
            LCtxSeqIdx := LCtxRecords[LM].SequenceIndex;
            LCtxLookupIdx := LCtxRecords[LM].LookupIndex;
            LCtxTarget := LI + LCtxSeqIdx;
            if (LCtxTarget >= 0) and (LCtxTarget < LCount) then
            begin
              LSubArr := FFace.ApplyContextSubstLookupMulti(LCtxLookupIdx, LGlyphs[LCtxTarget]);
              if Length(LSubArr) = 1 then
              begin
                { SingleSubst: 直接替换 }
                if LSubArr[0] <> LGlyphs[LCtxTarget] then
                begin
                  LGlyphs[LCtxTarget] := LSubArr[0];
                  Result[LCtxTarget].GlyphIndex := LSubArr[0];
                end;
              end
              else if Length(LSubArr) > 1 then
              begin
                { MultipleSubst: 在 ContextSubst 中触发 1→N 扩展。
                  标记扩展目标，后续 Pass 3 会处理完整的 MultipleSubst 扩展。
                  这里只替换第一个 glyph，剩余的留给 Pass 3。 }
                if LSubArr[0] <> LGlyphs[LCtxTarget] then
                begin
                  LGlyphs[LCtxTarget] := LSubArr[0];
                  Result[LCtxTarget].GlyphIndex := LSubArr[0];
                end;
              end;
            end;
          end;
          Break;
        end;
      end;
    end;
  end;

  // Pass 3: MultipleSubst (1-to-many expansion).
  // Each glyph may expand into a sequence of glyphs.
  // Uses a separate output array to handle expansion safely.
  // Early-exit: if font has no MultipleSubst, skip entirely.
  if FFace.HasMultipleSubst then
  begin
    // Pre-calculate expanded size.
    LOut := 0;
    for LI := 0 to LCount - 1 do
    begin
      LSubArr := FFace.LookupMultipleSubst(LGlyphs[LI]);
      if Length(LSubArr) > 1 then
        Inc(LOut, Length(LSubArr))
      else
        Inc(LOut);
    end;
    if LOut <> LCount then
    begin
      // Expansion occurred — build new arrays.
      SetLength(LNewResult, LOut);
      SetLength(LNewGlyphs, LOut);
      LOut := 0;
      for LI := 0 to LCount - 1 do
      begin
        LSubArr := FFace.LookupMultipleSubst(LGlyphs[LI]);
        if Length(LSubArr) > 1 then
        begin
          for LK := 0 to High(LSubArr) do
          begin
            LNewResult[LOut] := Result[LI];
            LNewResult[LOut].GlyphIndex := LSubArr[LK];
            if LK > 0 then
            begin
              LNewResult[LOut].AdvanceWidth := 0;
              LNewResult[LOut].Codepoint := Result[LI].Codepoint;
            end;
            LNewGlyphs[LOut] := LSubArr[LK];
            Inc(LOut);
          end;
        end
        else
        begin
          LNewResult[LOut] := Result[LI];
          LNewGlyphs[LOut] := LGlyphs[LI];
          Inc(LOut);
        end;
      end;
      Result := LNewResult;
      LGlyphs := LNewGlyphs;
      LCount := LOut;
    end;
  end;

  // Fourth pass: kern adjustment (adjust advance of preceding glyph).
  if FFace.HasKernPairs then
    for LI := 0 to High(Result) - 1 do
    begin
      LKernVal := FFace.LookupKern(Result[LI].GlyphIndex, Result[LI + 1].GlyphIndex);
      if LKernVal <> 0 then
        Result[LI].AdvanceWidth := Result[LI].AdvanceWidth + LKernVal;
    end;

  // 3.5 pass: CursivePos attachment (entry/exit anchor alignment).
  // For each adjacent pair, align exit anchor of left with entry anchor of right.
  if FFace.HasCursivePos then
    for LI := 0 to High(Result) - 1 do
    begin
      LExitAnchor := FFace.LookupCursivePosExitAnchor(Result[LI].GlyphIndex);
      LEntryAnchor := FFace.LookupCursivePosEntryAnchor(Result[LI + 1].GlyphIndex);
      if (LExitAnchor.X <> 0) or (LExitAnchor.Y <> 0) then
      begin
        // Adjust right glyph's mark offset to align entry with exit.
        Result[LI + 1].MarkOffsetX := LExitAnchor.X - LEntryAnchor.X;
        Result[LI + 1].MarkOffsetY := LExitAnchor.Y - LEntryAnchor.Y;
      end;
    end;

  // Fourth pass: mark attachment (MarkToBase + MarkToLig + MarkToMark).
  // Marks are identified by having zero advance width and non-zero class.
  for LI := 1 to High(Result) do
  begin
    if Result[LI].AdvanceWidth <> 0 then
      Continue;
    // Find the base glyph (previous non-mark glyph).
    LK := LI - 1;
    if LK >= 0 then
    begin
      // Check if LK is a mark (zero advance) or a base.
      if (Result[LK].AdvanceWidth = 0) and (LI >= 2) then
      begin
        // Previous glyph is also a mark → MarkToMark
        if FFace.HasMarkToMark then
        begin
          LAnchor := FFace.LookupMarkToMark(Result[LI].GlyphIndex, Result[LK].GlyphIndex);
          Result[LI].MarkOffsetX := LAnchor.X;
          Result[LI].MarkOffsetY := LAnchor.Y;
        end;
      end
      else
      begin
        // Previous glyph is a base → MarkToBase or MarkToLig.
        // Try MarkToLig first (ligature attachment), fall back to MarkToBase.
        if FFace.HasMarkToLig then
        begin
          LAnchor := FFace.LookupMarkToLig(Result[LI].GlyphIndex, Result[LK].GlyphIndex, 0);
          if (LAnchor.X <> 0) or (LAnchor.Y <> 0) then
          begin
            Result[LI].MarkOffsetX := LAnchor.X;
            Result[LI].MarkOffsetY := LAnchor.Y;
          end;
        end;
        if (Result[LI].MarkOffsetX = 0) and (Result[LI].MarkOffsetY = 0) then
        begin
          if FFace.HasMarkToBase then
          begin
            LAnchor := FFace.LookupMarkToBase(Result[LI].GlyphIndex, Result[LK].GlyphIndex);
            Result[LI].MarkOffsetX := LAnchor.X;
            Result[LI].MarkOffsetY := LAnchor.Y;
          end;
        end;
      end;
    end;
  end;
end;

function TFontLiteShaper.GetAdvanceWidth(ACodepoint: UInt32): UInt16;
var
  LIdx: UInt32;
  LGlyphIdx: UInt32;
begin
  // 先查缓存。
  LIdx := ACodepoint and CMAP_CACHE_MASK;
  if FCmapCache[LIdx].Codepoint = ACodepoint then
    Exit(FCmapCache[LIdx].AdvanceWidth);

  // Cache miss — 查找 cmap + hmtx。
  LGlyphIdx := FFace.LookupCodepoint(ACodepoint);
  Result := FFace.GlyphHorizontalMetric(LGlyphIdx).AdvanceWidth;

  // 写入缓存。
  FCmapCache[LIdx].Codepoint := ACodepoint;
  FCmapCache[LIdx].GlyphIndex := LGlyphIdx;
  FCmapCache[LIdx].AdvanceWidth := Result;
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
