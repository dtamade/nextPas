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
{ DECAWM (DECSET 7): disable auto-wrap so cell-grid TUI is not corrupted by
  terminal reflow (crossterm DisableLineWrap / ratatui EnterAlternateScreen). }
procedure AnsiDisableAutoWrap(var B: TStringBuilder);
procedure AnsiEnableAutoWrap(var B: TStringBuilder);
procedure AnsiEnableMouseClickTracking(var B: TStringBuilder);
procedure AnsiDisableMouseClickTracking(var B: TStringBuilder);
procedure AnsiEnableMouseDragTracking(var B: TStringBuilder);
procedure AnsiDisableMouseDragTracking(var B: TStringBuilder);
procedure AnsiEnableMouseTracking(var B: TStringBuilder);
procedure AnsiDisableMouseTracking(var B: TStringBuilder);
procedure AnsiEnableAlternateScroll(var B: TStringBuilder);
procedure AnsiDisableAlternateScroll(var B: TStringBuilder);

{ Terminal focus reporting (DECSET 1004) — reply CSI I / CSI O. }
procedure AnsiEnableFocusReporting(var B: TStringBuilder);
procedure AnsiDisableFocusReporting(var B: TStringBuilder);

{ Bracketed paste (DECSET 2004) — paste start CSI 200~ / end CSI 201~. }
procedure AnsiEnableBracketedPaste(var B: TStringBuilder);
procedure AnsiDisableBracketedPaste(var B: TStringBuilder);

{ Synchronized update (DECSET 2026) — batch multipatch draws to reduce tear.
  Pair Begin/End around one frame's DrawPatches (crossterm/ratatui style). }
procedure AnsiBeginSynchronizedUpdate(var B: TStringBuilder);
procedure AnsiEndSynchronizedUpdate(var B: TStringBuilder);

{ OSC 8 超链接（刀 21，锚 grok osc8.rs）：开 `ESC]8;id=..;url BEL` /
  关 `ESC]8;;BEL`。BEL 终止（0x07）——OSC-BEL 后紧跟 CSI 的混合序列
  主流终端均正确解析（如标题设置）；ST（ESC \）兼容面更窄。url 中
  控制字符剔除，防提前终止序列/注入。 }
procedure AnsiOsc8Open(var B: TStringBuilder; const AUrl: AnsiString;
  AId: Cardinal = 0);
procedure AnsiOsc8Close(var B: TStringBuilder);

{ Kitty keyboard progressive enhancement.
  flags: 1=disambiguate escapes, 4=report alternate keys (default 5). }
const
  KittyKeyboardDefaultFlags = 5;

procedure AnsiKittyKeyboardPush(var B: TStringBuilder; AFlags: Integer = KittyKeyboardDefaultFlags);
procedure AnsiKittyKeyboardPop(var B: TStringBuilder);
{ CSI ? u — query progressive enhancement flags (reply: CSI ? <flags> u). }
procedure AnsiKittyKeyboardQuery(var B: TStringBuilder);

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

procedure AnsiOsc8Open(var B: TStringBuilder; const AUrl: AnsiString;
  AId: Cardinal);
var
  LI: Integer;
  LCh: Byte;
begin
  { ESC ] 8 ; params ; url BEL —— params 空时仍保留双分号（规范：`8;;url`）；
    params 非空（id=..）时 `8;id=..;url` }
  B.AppendByte(27); B.AppendChar(']'); B.AppendChar('8'); B.AppendChar(';');
  if AId <> 0 then
  begin
    B.AppendStr('id=');
    B.AppendUInt(AId);
    B.AppendChar(';');
  end
  else
    B.AppendChar(';');
  for LI := 1 to System.Length(AUrl) do
  begin
    LCh := Byte(AUrl[LI]);
    if (LCh < 32) or (LCh = 127) then
      Continue;   { 剔除控制字符：防提前终止序列 / 注入 }
    B.AppendByte(LCh);
  end;
  B.AppendByte(7);   { BEL }
end;

procedure AnsiOsc8Close(var B: TStringBuilder);
begin
  { ESC ] 8 ; ; BEL }
  B.AppendByte(27); B.AppendChar(']'); B.AppendChar('8'); B.AppendChar(';');
  B.AppendChar(';');
  B.AppendByte(7);
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

procedure AnsiDisableAutoWrap(var B: TStringBuilder);
begin
  { CSI ? 7 l — DECAWM off }
  AnsiDecPrivateMode(B, 7, False);
end;

procedure AnsiEnableAutoWrap(var B: TStringBuilder);
begin
  { CSI ? 7 h — DECAWM on }
  AnsiDecPrivateMode(B, 7, True);
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

procedure AnsiEnableFocusReporting(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1004, True);
end;

procedure AnsiDisableFocusReporting(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 1004, False);
end;

procedure AnsiEnableBracketedPaste(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 2004, True);
end;

procedure AnsiDisableBracketedPaste(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 2004, False);
end;

procedure AnsiBeginSynchronizedUpdate(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 2026, True);
end;

procedure AnsiEndSynchronizedUpdate(var B: TStringBuilder);
begin
  AnsiDecPrivateMode(B, 2026, False);
end;

procedure AnsiKittyKeyboardPush(var B: TStringBuilder; AFlags: Integer);
begin
  { CSI = <flags> ; 1 u  — mode 1 = set/replace progressive enhancement flags }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('=');
  B.AppendUInt(UInt64(AFlags));
  B.AppendChar(';');
  B.AppendChar('1');
  B.AppendChar('u');
end;

procedure AnsiKittyKeyboardPop(var B: TStringBuilder);
begin
  { CSI < u  — restore progressive enhancement stack }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('<');
  B.AppendChar('u');
end;

procedure AnsiKittyKeyboardQuery(var B: TStringBuilder);
begin
  { CSI ? u — request current progressive enhancement flags }
  B.AppendByte(27); B.AppendChar('[');
  B.AppendChar('?');
  B.AppendChar('u');
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
