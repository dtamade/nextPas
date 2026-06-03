unit nextpas.core.tui.backend.ansi;

{**
 * @desc 具体 ANSI 后端——把 TDiffEntries 翻译为 ANSI 字节序列并 flush 到 fd。
 *
 * 每帧 ANSI 字节在 backend 拥有的 TStringBuilder 中累积，帧末一次性
 * 通过 platform_console_write flush。builder 跨帧复用（Clear 保留容量）。
 *
 * 样式最小化：记住上次发出的样式，任何字段变化触发 SGR 0 + 重新应用
 * （保守策略，对齐 ratatui CrosstermBackend 默认行为）。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.text.builder,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.ansi;

type
  TAnsiMouseMode = (amMouseNone, amMouseClick, amMouseDrag, amMouseFull);

  TAnsiBackend = class
  private
    FFd: Int32;
    FOut: TStringBuilder;
    FLastInit: Boolean;
    FLastFg: TColor;
    FLastBg: TColor;
    FLastUl: TColor;
    FLastModifier: TModifier;
  public
    constructor Create(AFd: Int32);
    destructor Destroy; override;

    { 重置缓存的 SGR 状态——进入 alt screen / 首帧前调用，确保下次
      ApplyCellStyle 发出完整 SGR 序列。 }
    procedure ResetStyleCache;

    { buffer 级 helper。不 flush；帧末调 Flush。 }
    procedure HideCursor;
    procedure ShowCursor;
    procedure ClearScreen;
    procedure EnterAlternate(AMouseMode: TAnsiMouseMode = amMouseFull;
      AAlternateScrollKeys: Boolean = False);
    procedure LeaveAlternate(AMouseMode: TAnsiMouseMode = amMouseFull;
      AAlternateScrollKeys: Boolean = False);
    procedure MoveTo(AX, AY: Word);

    { 把 Patches 翻译为 ANSI 字节。Patches 假定按 (Y,X) 排序——buffer Diff
      按行主序产出，同行相邻 cell 复用光标不发 MoveTo。 }
    procedure DrawPatches(const APatches: TDiffEntries);
    procedure DrawPatchesN(const APatches: TDiffEntries; ACount: Integer);

    { 把 builder 内容一次性 flush 到 fd。返回 False 表示写失败。 }
    function Flush: Boolean;

    { 追加外部预构建的原始字节（如图像协议序列）。不 flush。 }
    procedure AppendRawBytes(const AData; ALen: Integer);

    { 测试/诊断——窥视未 flush 的字节。 }
    function PendingLength: Integer; inline;
    function PendingBytes: PByte; inline;
    procedure DiscardPending; inline;
  end;

implementation

uses
  nextpas.core.platform.console;

{ TAnsiBackend }

constructor TAnsiBackend.Create(AFd: Int32);
begin
  inherited Create;
  FFd := AFd;
  FOut.Init(4096);
  ResetStyleCache;
end;

destructor TAnsiBackend.Destroy;
begin
  FOut.Done;
  inherited;
end;

procedure TAnsiBackend.ResetStyleCache;
begin
  FLastInit := False;
  FLastFg := UnsetColor;
  FLastBg := UnsetColor;
  FLastUl := UnsetColor;
  FLastModifier := [];
end;

procedure TAnsiBackend.HideCursor;     begin AnsiHideCursor(FOut); end;
procedure TAnsiBackend.ShowCursor;     begin AnsiShowCursor(FOut); end;
procedure TAnsiBackend.ClearScreen;    begin AnsiClearScreen(FOut); end;

procedure TAnsiBackend.EnterAlternate(AMouseMode: TAnsiMouseMode;
  AAlternateScrollKeys: Boolean);
begin
  AnsiEnterAltScreen(FOut);
  case AMouseMode of
    amMouseClick: AnsiEnableMouseClickTracking(FOut);
    amMouseDrag:  AnsiEnableMouseDragTracking(FOut);
    amMouseFull:  AnsiEnableMouseTracking(FOut);
  else
    ;
  end;
  if AAlternateScrollKeys then
    AnsiEnableAlternateScroll(FOut);
  ResetStyleCache;
end;

procedure TAnsiBackend.LeaveAlternate(AMouseMode: TAnsiMouseMode;
  AAlternateScrollKeys: Boolean);
begin
  AnsiSgrReset(FOut);
  case AMouseMode of
    amMouseClick: AnsiDisableMouseClickTracking(FOut);
    amMouseDrag:  AnsiDisableMouseDragTracking(FOut);
    amMouseFull:  AnsiDisableMouseTracking(FOut);
  else
    ;
  end;
  if AAlternateScrollKeys then
    AnsiDisableAlternateScroll(FOut);
  AnsiLeaveAltScreen(FOut);
  ResetStyleCache;
end;

procedure TAnsiBackend.MoveTo(AX, AY: Word);
begin
  AnsiMoveTo(FOut, AX, AY);
end;

procedure TAnsiBackend.DrawPatches(const APatches: TDiffEntries);
begin
  DrawPatchesN(APatches, System.Length(APatches));
end;

procedure TAnsiBackend.DrawPatchesN(const APatches: TDiffEntries; ACount: Integer);
var
  LI: Integer;
  LCurX, LCurY: Integer;
  LGlyphLen: Integer;
begin
  if ACount = 0 then Exit;
  LCurX := -1;
  LCurY := -1;
  for LI := 0 to ACount - 1 do
  begin
    if (APatches[LI].X <> LCurX) or (APatches[LI].Y <> LCurY) then
    begin
      AnsiMoveTo(FOut, APatches[LI].X, APatches[LI].Y);
      LCurX := APatches[LI].X;
      LCurY := APatches[LI].Y;
    end;

    if (not FLastInit) or
       (not ColorEquals(APatches[LI].Cell.Fg, FLastFg)) or
       (not ColorEquals(APatches[LI].Cell.Bg, FLastBg)) or
       (not ColorEquals(APatches[LI].Cell.Ul, FLastUl)) or
       (APatches[LI].Cell.Modifier <> FLastModifier) then
    begin
      AnsiSgrReset(FOut);
      if (APatches[LI].Cell.Fg.Kind = ckIndexed) or (APatches[LI].Cell.Fg.Kind = ckRgb) then
        AnsiSgrFg(FOut, APatches[LI].Cell.Fg);
      if (APatches[LI].Cell.Bg.Kind = ckIndexed) or (APatches[LI].Cell.Bg.Kind = ckRgb) then
        AnsiSgrBg(FOut, APatches[LI].Cell.Bg);
      if APatches[LI].Cell.Modifier <> [] then
        AnsiSgrModifierAdd(FOut, APatches[LI].Cell.Modifier);
      FLastFg := APatches[LI].Cell.Fg;
      FLastBg := APatches[LI].Cell.Bg;
      FLastUl := APatches[LI].Cell.Ul;
      FLastModifier := APatches[LI].Cell.Modifier;
      FLastInit := True;
    end;

    LGlyphLen := APatches[LI].Cell.Glyph.Len;
    if LGlyphLen = 0 then
      FOut.AppendByte(Ord(' '))
    else if LGlyphLen = 1 then
      FOut.AppendByte(APatches[LI].Cell.Glyph.Bytes[0])
    else
      FOut.AppendBytes(PAnsiChar(@APatches[LI].Cell.Glyph.Bytes[0]), LGlyphLen);

    if APatches[LI].Cell.Width > 1 then
      Inc(LCurX, APatches[LI].Cell.Width)
    else
      Inc(LCurX);
  end;
end;

function TAnsiBackend.Flush: Boolean;
var
  LLen: Integer;
begin
  LLen := Integer(FOut.Len);
  if LLen = 0 then Exit(True);
  Result := platform_console_write(FFd, Pointer(FOut.AsView.Data), LLen) = LLen;
  FOut.Clear;
end;

procedure TAnsiBackend.AppendRawBytes(const AData; ALen: Integer);
begin
  FOut.AppendBytes(PAnsiChar(@AData), ALen);
end;

function TAnsiBackend.PendingLength: Integer;
begin
  Result := Integer(FOut.Len);
end;

function TAnsiBackend.PendingBytes: PByte;
begin
  Result := PByte(FOut.AsView.Data);
end;

procedure TAnsiBackend.DiscardPending;
begin
  FOut.Clear;
  ResetStyleCache;
end;

end.
