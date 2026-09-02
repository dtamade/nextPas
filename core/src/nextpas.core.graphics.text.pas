{**
 * nextpas.core.graphics.text - 文本薄层产 TGlyphRun（Scale 打通 window/gpu.canvas）
 * 四段链：UTF-8→Grapheme(本地)→Glyph(本地宽度)→GlyphRun(Positions)
 * 单文件≤800行，L1 薄层本地 UTF-8/簇/度量，无 text.layout/unicode.segment 跨层依赖
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
  nextpas.core.base;

type
  TLocalDecode = record
    CodePoint: UInt32;
    ByteLen: Byte;
  end;

function LocalUTF8Decode(const AData: PByte; const ALen: SizeUInt): TLocalDecode;
var
  B: Byte;
begin
  Result.CodePoint := 0;
  Result.ByteLen := 0;
  if (ALen = 0) or (AData = nil) then
    Exit;
  B := AData[0];
  if B < $80 then
  begin
    Result.CodePoint := B;
    Result.ByteLen := 1;
  end
  else if (B and $E0) = $C0 then
  begin
    if ALen < 2 then Exit;
    if (AData[1] and $C0) <> $80 then Exit;
    Result.CodePoint := (UInt32(B and $1F) shl 6) or (UInt32(AData[1]) and $3F);
    if Result.CodePoint < $80 then begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 2;
  end
  else if (B and $F0) = $E0 then
  begin
    if ALen < 3 then Exit;
    if ((AData[1] and $C0) <> $80) or ((AData[2] and $C0) <> $80) then Exit;
    Result.CodePoint := (UInt32(B and $0F) shl 12) or ((UInt32(AData[1]) and $3F) shl 6) or (UInt32(AData[2]) and $3F);
    if Result.CodePoint < $800 then begin Result.ByteLen := 0; Exit; end;
    if (Result.CodePoint >= $D800) and (Result.CodePoint <= $DFFF) then begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 3;
  end
  else if (B and $F8) = $F0 then
  begin
    if ALen < 4 then Exit;
    if ((AData[1] and $C0) <> $80) or ((AData[2] and $C0) <> $80) or ((AData[3] and $C0) <> $80) then Exit;
    Result.CodePoint := (UInt32(B and $07) shl 18) or ((UInt32(AData[1]) and $3F) shl 12) or ((UInt32(AData[2]) and $3F) shl 6) or (UInt32(AData[3]) and $3F);
    if Result.CodePoint < $10000 then begin Result.ByteLen := 0; Exit; end;
    if Result.CodePoint > $10FFFF then begin Result.ByteLen := 0; Exit; end;
    Result.ByteLen := 4;
  end;
end;

function LocalIsWide(const ACp: UInt32): Boolean; inline;
begin
  if ACp < $1100 then Exit(False);
  if ACp <= $115F then Exit(True);
  if (ACp >= $2E80) and (ACp <= $A4CF) then Exit(True);
  if (ACp >= $AC00) and (ACp <= $D7A3) then Exit(True);
  if (ACp >= $F900) and (ACp <= $FAFF) then Exit(True);
  if (ACp >= $FE10) and (ACp <= $FE6F) then Exit(True);
  if (ACp >= $FF00) and (ACp <= $FF60) then Exit(True);
  if (ACp >= $FFE0) and (ACp <= $FFE6) then Exit(True);
  if ACp >= $1F000 then Exit(True);
  Result := False;
end;

function LocalCodepointWidth(const ACp: UInt32): Byte; inline;
begin
  if (ACp < 32) or (ACp = $7F) or ((ACp >= $80) and (ACp < $A0)) then
    Exit(0);
  if LocalIsWide(ACp) then
    Exit(2);
  Result := 1;
end;

function LocalGlyphAdvance(const ACp: UInt32; AFontSize, AScale: Single): Single; inline;
var
  LW: Byte;
begin
  if (AFontSize <= 0) or (AScale <= 0) then
    Exit(0);
  LW := LocalCodepointWidth(ACp);
  case LW of
    0: Result := 0;
    2: Result := AFontSize * AScale * 1.2;
  else
    Result := AFontSize * AScale * 0.6;
  end;
end;

function LocalGraphemeClusterByteLen(const AData: PByte; const ALen: SizeUInt): SizeUInt; inline;
var
  LDec, LNext: TLocalDecode;
begin
  if (AData = nil) or (ALen = 0) then
    Exit(0);
  LDec := LocalUTF8Decode(AData, ALen);
  if LDec.ByteLen = 0 then
    Exit(1);
  if LDec.CodePoint = 13 then
  begin
    if SizeUInt(LDec.ByteLen) < ALen then
    begin
      LNext := LocalUTF8Decode(@AData[LDec.ByteLen], ALen - SizeUInt(LDec.ByteLen));
      if (LNext.ByteLen > 0) and (LNext.CodePoint = 10) then
        Exit(SizeUInt(LDec.ByteLen) + SizeUInt(LNext.ByteLen));
    end;
  end;
  Result := SizeUInt(LDec.ByteLen);
end;

function LocalNextGrapheme(const AData: PByte; ALen: SizeUInt; AFontSize, AScale: Single; out AGlyph: UInt32; out AAdvance: Single): SizeUInt; inline;
var
  LBytes: SizeUInt;
  LDec: TLocalDecode;
begin
  AGlyph := $FFFD;
  AAdvance := 0;
  if (AData = nil) or (ALen = 0) then
    Exit(0);
  LBytes := LocalGraphemeClusterByteLen(AData, ALen);
  if LBytes = 0 then
    Exit(0);
  LDec := LocalUTF8Decode(AData, LBytes);
  if LDec.ByteLen > 0 then
    AGlyph := LDec.CodePoint
  else
    AGlyph := $FFFD;
  AAdvance := LocalGlyphAdvance(AGlyph, AFontSize, AScale);
  Result := LBytes;
end;

function TGlyphRun.IsEmpty: Boolean;
begin
  Result := Length(Glyphs) = 0;
end;

{ 内部：根据是否换行构建 Run，L1 本地簇/度量，无跨层依赖 }
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
  LDec: TLocalDecode;
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
  // 预分配：最坏 1B=1 grapheme，单次 SetLength+Move 零拷贝
  LCapa := SizeInt(LLen);
  if LCapa < 1 then LCapa := 1;
  SetLength(Result.GlyphRun.Glyphs, LCapa);
  SetLength(Result.GlyphRun.Positions, LCapa);
  LX := 0;
  LY := 0;
  LLineH := AFontSize * AScale;
  if AWrapped and (AMaxWidth > 0) and (LLineH > 0) then
    LLineH := AFontSize * AScale * 1.2;
  LMaxW := 0;
  LCount := 0;
  LPos := 0;
  while LPos < LLen do
  begin
    // grapheme 簇：本地边界，非法 UTF-8 按 1B U+FFFD
    LBytes := LocalNextGrapheme(PByte(@AText[LPos+1]), LLen - LPos, AFontSize, AScale, LGlyph, LAdv);
    if LBytes = 0 then
      Break;
    // 硬换行检测：簇内首码点为 LF/CR（已按本地合并 CRLF）
    LIsHardBreak := False;
    LDec := LocalUTF8Decode(PByte(@AText[LPos+1]), LBytes);
    if LDec.ByteLen > 0 then
    begin
      if (LDec.CodePoint = 10) or (LDec.CodePoint = 13) then
        LIsHardBreak := True;
    end;
    if LIsHardBreak then
    begin
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
    // 扩容：按需倍增
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
  if LX > LMaxW then LMaxW := LX;
  if LCount = 0 then
  begin
    SetLength(Result.GlyphRun.Glyphs, 0);
    SetLength(Result.GlyphRun.Positions, 0);
    Result.Bounds := TRect.From(0, 0, 0, 0);
    Exit;
  end;
  if LCount <> LCapa then
  begin
    SetLength(Result.GlyphRun.Glyphs, LCount);
    SetLength(Result.GlyphRun.Positions, LCount);
  end;
  LCurW := LMaxW;
  if AWrapped and (AMaxWidth > 0) and (LCount > 0) then
  begin
    if LCurW > AMaxWidth then LCurW := AMaxWidth;
    if LCurW < LMaxW then LCurW := LMaxW;
    if LCurW > AMaxWidth then LCurW := LMaxW;
  end;
  if LCurW < 0 then LCurW := 0;
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
  Result := BuildRun(AText, AFontSize, AScale, AMaxWidth, True);
end;

end.
