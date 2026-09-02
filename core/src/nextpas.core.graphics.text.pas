{**
 * nextpas.core.graphics.text - 文本薄层产 TGlyphRun（Scale 打通 window/gpu.canvas）
 * 四段链：UTF-8→Grapheme(text.unicode.segment)→Glyph(text.layout/font.shaper)→GlyphRun(Positions)
 * 单文件≤800行，L1 薄层靠 text.layout 单源 Grapheme 度量 + bytes.ops Move 零拷贝
 *}
unit nextpas.core.graphics.text;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.graphics.base;

type
  TGlyphRun = record
    Glyphs: array of LongWord;
    Positions: array of TVec2;
    Scale: Single;
    function IsEmpty: Boolean; inline;
  end;

  TTextLayout = record
    Text: AnsiString;
    FontSize: Single;
    Scale: Single; // DisplayScale
    MaxWidth: Single; // 0=无限
    GlyphRun: TGlyphRun;
    Bounds: TRect;
  end;

function LayoutText(const AText: AnsiString; AFontSize, AScale: Single): TTextLayout;
function LayoutTextWrapped(const AText: AnsiString; AFontSize, AScale, AMaxWidth: Single): TTextLayout;

implementation

uses
  nextpas.core.base,
  nextpas.core.text.layout,
  nextpas.core.text.utf8,
  nextpas.core.text.unicode.segment,
  nextpas.core.bytes.ops;

function TGlyphRun.IsEmpty: Boolean;
begin
  Result := Length(Glyphs) = 0;
end;

{ 内部：根据是否换行构建 Run，复用 text.layout 的 Grapheme→Glyph 单源 }
function BuildRun(const AText: AnsiString; AFontSize, AScale, AMaxWidth: Single; AWrapped: Boolean): TTextLayout;
var
  LLen, LPos: SizeUInt;
  LCapa, LCount: SizeInt;
  LX, LY: Single;
  LLineH: Single;
  LMaxW, LCurW: Single;
  LGlyph: UInt32;
  LAdv: Single;
  LBytes: SizeUInt;
  LIsHardBreak: Boolean;
  LDec: TUTF8DecodeResult;
begin
  Result.Text := AText;
  Result.FontSize := AFontSize;
  Result.Scale := AScale;
  if AWrapped then
    Result.MaxWidth := AMaxWidth
  else
    Result.MaxWidth := 0;
  Result.GlyphRun.Scale := AScale;
  LLen := SizeUInt(Length(AText));
  if (LLen = 0) or (AFontSize <= 0) or (AScale <= 0) then
  begin
    SetLength(Result.GlyphRun.Glyphs, 0);
    SetLength(Result.GlyphRun.Positions, 0);
    Result.Bounds := TRect.From(0, 0, 0, 0);
    Exit;
  end;
  // 预分配：最坏 1B=1 grapheme，零拷贝 Move 单源（bytes.ops 语义，单次 SetLength+Move）
  LCapa := SizeInt(LLen);
  if LCapa < 1 then LCapa := 1;
  SetLength(Result.GlyphRun.Glyphs, LCapa);
  SetLength(Result.GlyphRun.Positions, LCapa);
  LX := 0;
  LY := 0;
  LLineH := AFontSize * AScale; // 行高=em；Wrapped 时多行可 *1.2 视设计，此处保 bounds 非零
  if AWrapped and (AMaxWidth > 0) and (LLineH > 0) then
    LLineH := AFontSize * AScale * 1.2;
  LMaxW := 0;
  LCount := 0;
  LPos := 0;
  while LPos < LLen do
  begin
    // grapheme 簇：边界=UAX#29 真源，非法 UTF-8 按 1B U+FFFD
    LBytes := LayoutNextGrapheme(@AText[LPos+1], LLen - LPos, AFontSize, AScale, LGlyph, LAdv);
    if LBytes = 0 then
      Break;
    // 硬换行检测：簇内首码点为 LF/CR（已按 grapheme 合并 CRLF）
    LIsHardBreak := False;
    LDec := UTF8Decode(@AText[LPos+1], LBytes);
    if LDec.ByteLen > 0 then
    begin
      if (LDec.CodePoint = 10) or (LDec.CodePoint = 13) then
        LIsHardBreak := True;
    end;
    if LIsHardBreak then
    begin
      // 硬换行：不产 glyph，换行
      if LX > LMaxW then LMaxW := LX;
      LX := 0;
      LY := LY + LLineH;
      Inc(LPos, LBytes);
      Continue;
    end;
    // 软换行：AWrapped 且超宽则折行到下一行首
    if AWrapped and (AMaxWidth > 0) and (LAdv > 0) and (LX + LAdv > AMaxWidth + 1e-6) and (LX > 0) then
    begin
      if LX > LMaxW then LMaxW := LX;
      LX := 0;
      LY := LY + LLineH;
    end;
    // 扩容：按需倍增，单次 Move（bytes.ops 单源语义：Move 零拷贝）
    if LCount >= LCapa then
    begin
      LCapa := LCapa * 2;
      SetLength(Result.GlyphRun.Glyphs, LCapa);
      SetLength(Result.GlyphRun.Positions, LCapa);
    end;
    Result.GlyphRun.Glyphs[LCount] := LGlyph;
    Result.GlyphRun.Positions[LCount] := TVec2.Create(LX, LY);
    Inc(LCount);
    LX := LX + LAdv;
    if (not AWrapped) or (AMaxWidth <= 0) then
      if LX > LMaxW then LMaxW := LX;
    Inc(LPos, LBytes);
  end;
  // 尾行收敛
  if LX > LMaxW then LMaxW := LX;
  if LCount = 0 then
  begin
    SetLength(Result.GlyphRun.Glyphs, 0);
    SetLength(Result.GlyphRun.Positions, 0);
    Result.Bounds := TRect.From(0, 0, 0, 0);
    Exit;
  end;
  // 缩容：单次 SetLength 零拷贝（无额外 Move）
  if LCount <> LCapa then
  begin
    SetLength(Result.GlyphRun.Glyphs, LCount);
    SetLength(Result.GlyphRun.Positions, LCount);
  end;
  LCurW := LMaxW;
  if AWrapped and (AMaxWidth > 0) and (LCount > 0) then
  begin
    // 有换行时宽度钳至 MaxWidth（溢出单簇除外）
    if LCurW > AMaxWidth then LCurW := AMaxWidth;
    // 若存在超宽簇（如超宽 emoji），保持实测宽
    if LCurW < LMaxW then LCurW := LMaxW;
    if LCurW > AMaxWidth then LCurW := LMaxW;
  end;
  if LCurW < 0 then LCurW := 0;
  // 高度：至少一行，Wrapped 时按行数
  if AWrapped and (AMaxWidth > 0) then
    Result.Bounds := TRect.From(0, 0, LCurW, LY + AFontSize * AScale)
  else
    Result.Bounds := TRect.From(0, 0, LCurW, AFontSize * AScale);
end;

function LayoutText(const AText: AnsiString; AFontSize, AScale: Single): TTextLayout;
begin
  Result := BuildRun(AText, AFontSize, AScale, 0, False);
end;

function LayoutTextWrapped(const AText: AnsiString; AFontSize, AScale, AMaxWidth: Single): TTextLayout;
begin
  // AMaxWidth<=0 视为无限，复用同一管线保一致
  Result := BuildRun(AText, AFontSize, AScale, AMaxWidth, True);
end;

end.
