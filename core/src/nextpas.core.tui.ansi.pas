unit nextpas.core.tui.ansi;

{**
 * @desc ANSI escape 序列 emitter——直接写入 TStringBuilder。
 *
 * 每个 helper 把一个 ratatui 概念翻译为终端期望的字节序列，目标 builder
 * 以 var 传入，字节直接落入每帧 builder 而无中间 AnsiString。emitter 粒度
 * 细：后端按需组合。
 *
 * 参考：ECMA-48 / ANSI X3.64 + xterm CSI 扩展（256 色 38;5;N / truecolor
 * 38;2;R;G;B SGR）。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.builder,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier;

{ 光标 + 屏幕原语。X/Y 为 0-based 输入，wire 上 +1 转 1-based。 }
procedure AnsiHideCursor(var B: TStringBuilder); inline;
procedure AnsiShowCursor(var B: TStringBuilder); inline;
procedure AnsiMoveTo(var B: TStringBuilder; AX, AY: Word);
procedure AnsiClearScreen(var B: TStringBuilder); inline;
procedure AnsiEnterAltScreen(var B: TStringBuilder); inline;
procedure AnsiLeaveAltScreen(var B: TStringBuilder); inline;
procedure AnsiEnableMouseClickTracking(var B: TStringBuilder);
procedure AnsiDisableMouseClickTracking(var B: TStringBuilder);
procedure AnsiEnableMouseDragTracking(var B: TStringBuilder);
procedure AnsiDisableMouseDragTracking(var B: TStringBuilder);
procedure AnsiEnableMouseTracking(var B: TStringBuilder);
procedure AnsiDisableMouseTracking(var B: TStringBuilder);
procedure AnsiEnableAlternateScroll(var B: TStringBuilder);
procedure AnsiDisableAlternateScroll(var B: TStringBuilder);

{ SGR emitter。每个写一个完整 SGR 序列，不 reset；后端在不兼容属性切换间
  调 AnsiSgrReset。 }
procedure AnsiSgrReset(var B: TStringBuilder); inline;
procedure AnsiSgrFg(var B: TStringBuilder; const AColor: TColor);
procedure AnsiSgrBg(var B: TStringBuilder; const AColor: TColor);
procedure AnsiSgrUl(var B: TStringBuilder; const AColor: TColor);
procedure AnsiSgrModifierAdd(var B: TStringBuilder; AModifier: TModifier);
procedure AnsiSgrModifierClear(var B: TStringBuilder; AModifier: TModifier);

implementation

{ 光标 + 屏幕 }

procedure AnsiHideCursor(var B: TStringBuilder);
begin
  { CSI ? 25 l }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?'); B.AppendChar('2'); B.AppendChar('5');
  B.AppendChar('l');
end;

procedure AnsiShowCursor(var B: TStringBuilder);
begin
  { CSI ? 25 h }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?'); B.AppendChar('2'); B.AppendChar('5');
  B.AppendChar('h');
end;

procedure AnsiMoveTo(var B: TStringBuilder; AX, AY: Word);
begin
  { CSI <row> ; <col> H — wire 1-based }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendUInt(UInt64(AY) + 1);
  B.AppendChar(';');
  B.AppendUInt(UInt64(AX) + 1);
  B.AppendChar('H');
end;

procedure AnsiClearScreen(var B: TStringBuilder);
begin
  { CSI 2 J }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('2'); B.AppendChar('J');
end;

procedure AnsiEnterAltScreen(var B: TStringBuilder);
begin
  { CSI ? 1049 h }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?');
  B.AppendChar('1'); B.AppendChar('0'); B.AppendChar('4'); B.AppendChar('9');
  B.AppendChar('h');
end;

procedure AnsiLeaveAltScreen(var B: TStringBuilder);
begin
  { CSI ? 1049 l }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?');
  B.AppendChar('1'); B.AppendChar('0'); B.AppendChar('4'); B.AppendChar('9');
  B.AppendChar('l');
end;

procedure AnsiDecPrivateMode(var B: TStringBuilder; AMode: Word; AEnable: Boolean); inline;
begin
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?');
  B.AppendUInt(AMode);
  if AEnable then
    B.AppendChar('h')
  else
    B.AppendChar('l');
end;

procedure AnsiEnableMouseClickTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1000, True);
  AnsiDecPrivateMode(B, 1006, True);
end;

procedure AnsiDisableMouseClickTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1000, False);
  AnsiDecPrivateMode(B, 1006, False);
end;

procedure AnsiEnableMouseDragTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1002, True);
  AnsiDecPrivateMode(B, 1006, True);
end;

procedure AnsiDisableMouseDragTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1002, False);
  AnsiDecPrivateMode(B, 1006, False);
end;

procedure AnsiEnableMouseTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1003, True);
  AnsiDecPrivateMode(B, 1006, True);
end;

procedure AnsiDisableMouseTracking(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1003, False);
  AnsiDecPrivateMode(B, 1006, False);
end;

procedure AnsiEnableAlternateScroll(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1007, True);
end;

procedure AnsiDisableAlternateScroll(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1007, False);
end;

{ SGR helpers }

const
  CSI_SGR_RESET: array[0..3] of Byte = (27, Ord('['), Ord('0'), Ord('m'));

procedure AnsiSgrReset(var B: TStringBuilder);
begin
  B.AppendBytes(PAnsiChar(@CSI_SGR_RESET[0]), 4);
end;

{ 内部：发 named/indexed 前景色。
  Named 0..7  -> SGR 30..37
  Named 8..15 -> SGR 90..97（亮色）
  Indexed >=16 -> SGR 38;5;N }
procedure EmitIndexedFg(var B: TStringBuilder; AIdx: Byte); inline;
var
  LBuf: array[0..4] of Byte;
begin
  LBuf[0] := 27;
  LBuf[1] := Ord('[');
  if AIdx < 8 then
  begin
    LBuf[2] := Ord('3');
    LBuf[3] := Ord('0') + AIdx;
    LBuf[4] := Ord('m');
    B.AppendBytes(PAnsiChar(@LBuf[0]), 5);
  end
  else if AIdx < 16 then
  begin
    LBuf[2] := Ord('9');
    LBuf[3] := Ord('0') + (AIdx - 8);
    LBuf[4] := Ord('m');
    B.AppendBytes(PAnsiChar(@LBuf[0]), 5);
  end
  else
  begin
    B.AppendBytes(PAnsiChar(@LBuf[0]), 2);
    B.AppendChar('3'); B.AppendChar('8');
    B.AppendChar(';'); B.AppendChar('5'); B.AppendChar(';');
    B.AppendUInt(AIdx);
    B.AppendChar('m');
  end;
end;

procedure EmitIndexedBg(var B: TStringBuilder; AIdx: Byte); inline;
var
  LBuf: array[0..5] of Byte;
begin
  LBuf[0] := 27;
  LBuf[1] := Ord('[');
  if AIdx < 8 then
  begin
    LBuf[2] := Ord('4');
    LBuf[3] := Ord('0') + AIdx;
    LBuf[4] := Ord('m');
    B.AppendBytes(PAnsiChar(@LBuf[0]), 5);
  end
  else if AIdx < 16 then
  begin
    LBuf[2] := Ord('1'); LBuf[3] := Ord('0'); LBuf[4] := Ord('0') + (AIdx - 8);
    LBuf[5] := Ord('m');
    B.AppendBytes(PAnsiChar(@LBuf[0]), 6);
  end
  else
  begin
    B.AppendBytes(PAnsiChar(@LBuf[0]), 2);
    B.AppendChar('4'); B.AppendChar('8');
    B.AppendChar(';'); B.AppendChar('5'); B.AppendChar(';');
    B.AppendUInt(AIdx);
    B.AppendChar('m');
  end;
end;

procedure AnsiSgrFg(var B: TStringBuilder; const AColor: TColor);
begin
  case AColor.Kind of
    ckUnset: ;     { no-op }
    ckReset:
      begin
        { SGR 39 = default foreground }
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('3'); B.AppendChar('9');
        B.AppendChar('m');
      end;
    ckIndexed:
      EmitIndexedFg(B, AColor.Index);
    ckRgb:
      begin
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('3'); B.AppendChar('8');
        B.AppendChar(';'); B.AppendChar('2'); B.AppendChar(';');
        B.AppendUInt(AColor.R); B.AppendChar(';');
        B.AppendUInt(AColor.G); B.AppendChar(';');
        B.AppendUInt(AColor.B);
        B.AppendChar('m');
      end;
  end;
end;

procedure AnsiSgrBg(var B: TStringBuilder; const AColor: TColor);
begin
  case AColor.Kind of
    ckUnset: ;
    ckReset:
      begin
        { SGR 49 = default background }
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('4'); B.AppendChar('9');
        B.AppendChar('m');
      end;
    ckIndexed:
      EmitIndexedBg(B, AColor.Index);
    ckRgb:
      begin
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('4'); B.AppendChar('8');
        B.AppendChar(';'); B.AppendChar('2'); B.AppendChar(';');
        B.AppendUInt(AColor.R); B.AppendChar(';');
        B.AppendUInt(AColor.G); B.AppendChar(';');
        B.AppendUInt(AColor.B);
        B.AppendChar('m');
      end;
  end;
end;

procedure AnsiSgrUl(var B: TStringBuilder; const AColor: TColor);
begin
  case AColor.Kind of
    ckUnset: ;
    ckReset:
      begin
        { SGR 59 = default underline color }
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('5'); B.AppendChar('9');
        B.AppendChar('m');
      end;
    ckIndexed:
      begin
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('5'); B.AppendChar('8');
        B.AppendChar(';'); B.AppendChar('5'); B.AppendChar(';');
        B.AppendUInt(AColor.Index);
        B.AppendChar('m');
      end;
    ckRgb:
      begin
        B.AppendByte(27); B.AppendChar('[');
        B.AppendChar('5'); B.AppendChar('8');
        B.AppendChar(';'); B.AppendChar('2'); B.AppendChar(';');
        B.AppendUInt(AColor.R); B.AppendChar(';');
        B.AppendUInt(AColor.G); B.AppendChar(';');
        B.AppendUInt(AColor.B);
        B.AppendChar('m');
      end;
  end;
end;

{ ratatui modifier bit -> SGR set 参数 (bold=1, dim=2, italic=3, ...) }
function SgrSet(ABit: TModifierBit): Byte; inline;
begin
  Result := 0;
  case ABit of
    mbBold:        Result := 1;
    mbDim:         Result := 2;
    mbItalic:      Result := 3;
    mbUnderlined:  Result := 4;
    mbSlowBlink:   Result := 5;
    mbRapidBlink:  Result := 6;
    mbReversed:    Result := 7;
    mbHidden:      Result := 8;
    mbCrossedOut:  Result := 9;
  end;
end;

{ SGR clear 码。bold/dim 共享 SGR 22，其余各自独立。 }
function SgrClear(ABit: TModifierBit): Byte; inline;
begin
  Result := 0;
  case ABit of
    mbBold, mbDim:               Result := 22;
    mbItalic:                    Result := 23;
    mbUnderlined:                Result := 24;
    mbSlowBlink, mbRapidBlink:   Result := 25;
    mbReversed:                  Result := 27;
    mbHidden:                    Result := 28;
    mbCrossedOut:                Result := 29;
  end;
end;

procedure EmitSgrCode(var B: TStringBuilder; ACode: Byte); inline;
begin
  B.AppendByte(27); B.AppendChar('[');
  B.AppendUInt(ACode);
  B.AppendChar('m');
end;

procedure AnsiSgrModifierAdd(var B: TStringBuilder; AModifier: TModifier);
var
  LBit: TModifierBit;
  LCode: Byte;
begin
  for LBit := Low(TModifierBit) to High(TModifierBit) do
    if LBit in AModifier then
    begin
      LCode := SgrSet(LBit);
      EmitSgrCode(B, LCode);
    end;
end;

procedure AnsiSgrModifierClear(var B: TStringBuilder; AModifier: TModifier);
var
  LBit: TModifierBit;
  LCode: Byte;
  LEmitted: array[Byte] of Boolean;
begin
  FillChar(LEmitted, SizeOf(LEmitted), 0);
  for LBit := Low(TModifierBit) to High(TModifierBit) do
    if LBit in AModifier then
    begin
      LCode := SgrClear(LBit);
      if not LEmitted[LCode] then
      begin
        EmitSgrCode(B, LCode);
        LEmitted[LCode] := True;
      end;
    end;
end;

end.
