unit nextpas.core.tui.overlay;

{**
 * @desc 覆盖缓冲区——位于 base buffer 之上的稀疏层。
 *
 * 设计：
 *   - 内部只存被显式写入（SetString/SetCell/SetStyle）的 cell，未写位置
 *     "透明"——merge 时透传 base cell。
 *   - MergeInto(base, dest)：把标记过的 cell 覆盖到 dest，其余透传。
 *   - Clear 把覆盖层重置为全透明（零成本 FillChar）。
 *   - 失效：消费方写入后置 FDirty，终端据此决定是否重新 merge。
 *
 * 性能：
 *   - 用全尺寸 `array of TCell`（同 base）+ 并行 `array of Boolean` 标记
 *     哪些 cell 被设置。
 *   - Merge 单遍：mark[i] 则 dest[i]:=overlay[i] 否则保持 base。
 *   - Clear 是 FillChar(marks, N, 0)。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer;

type
  TOverlayBuffer = class
  private
    FArea: TRect;
    FCells: array of TCell;
    FMarks: array of Boolean;
    FDirty: Boolean;
    function IndexOf(AX, AY: Integer): Integer; inline;
  public
    constructor Create(const AArea: TRect);

    property Area: TRect read FArea;
    property Dirty: Boolean read FDirty;

    { 在 (AX,AY) 写一个 cell，并在覆盖层标记为"已设置"。 }
    procedure SetCell(AX, AY: Integer; const ACell: TCell);

    { 写字符串到覆盖层（语义同 TBuffer.SetString）。 }
    procedure SetString(AX, AY: Integer; const AStr: AnsiString; const AStyle: TStyle);

    { 用样式标记矩形为"已设置"（以带样式空格填充）。 }
    procedure SetStyle(const A: TRect; const AStyle: TStyle);

    { 清空整个覆盖层（所有 cell 变透明）。 }
    procedure Clear;

    { 调整到新区域，清空所有内容。 }
    procedure Resize(const ANewArea: TRect);

    { 把 base + overlay 合并到 Dest。Dest 须与 base 同尺寸。
      只在标记处覆盖 overlay cell；base cell 透传。 }
    procedure MergeInto(ABase, ADest: TBuffer);

    { 脏标记（消费方写入覆盖层后调用）。 }
    procedure MarkDirty; inline;
    procedure ClearDirty; inline;
  end;

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.width,
  nextpas.core.text.grapheme;

type
  TGraphemeAdvance = record
    ByteLen: Integer;
    Width: Integer;
    Codepoint: UInt32;
  end;

function GraphemeAt(const ABuf; ALen, AOffset: Integer): TGraphemeAdvance; inline;
var LGR: TGraphemeResult;
begin
  LGR := GraphemeNext(@PByte(@ABuf)[AOffset], ALen - AOffset);
  Result.ByteLen := LGR.ByteLen;
  Result.Width := LGR.Width;
  Result.Codepoint := $FFFD;
end;

{ TOverlayBuffer }

constructor TOverlayBuffer.Create(const AArea: TRect);
var
  LN: Integer;
begin
  inherited Create;
  FArea := AArea;
  LN := AArea.Area;
  SetLength(FCells, LN);
  SetLength(FMarks, LN);
  Clear;
end;

function TOverlayBuffer.IndexOf(AX, AY: Integer): Integer;
begin
  Result := (AY - FArea.Y) * FArea.Width + (AX - FArea.X);
end;

procedure TOverlayBuffer.SetCell(AX, AY: Integer; const ACell: TCell);
var
  LIdx: Integer;
begin
  if (AX < FArea.X) or (AX >= FArea.X + FArea.Width) or
     (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  LIdx := IndexOf(AX, AY);
  FCells[LIdx] := ACell;
  FMarks[LIdx] := True;
  FDirty := True;
end;

procedure TOverlayBuffer.SetString(AX, AY: Integer; const AStr: AnsiString;
  const AStyle: TStyle);
var
  LI, LCursor, LGLen: Integer;
  LAdv: TGraphemeAdvance;
  LCell: TCell;
  LAscii: Boolean;
begin
  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  if AX >= FArea.X + FArea.Width then Exit;
  if AX < FArea.X then AX := FArea.X;

  LGLen := System.Length(AStr);
  if LGLen = 0 then Exit;

  LAscii := True;
  for LI := 1 to LGLen do
    if Byte(AStr[LI]) >= $80 then begin LAscii := False; Break; end;

  LCursor := AX;
  if LAscii then
  begin
    for LI := 1 to LGLen do
    begin
      if LCursor >= FArea.X + FArea.Width then Break;
      if Byte(AStr[LI]) < 32 then Continue;
      LCell := CELL_EMPTY;
      CellSetSymbolAscii(LCell, AStr[LI]);
      CellApplyStyle(LCell, AStyle);
      SetCell(LCursor, AY, LCell);
      Inc(LCursor);
    end;
  end
  else
  begin
    LI := 0;
    while LI < LGLen do
    begin
      if LCursor >= FArea.X + FArea.Width then Break;
      LAdv := GraphemeAt(AStr[1], LGLen, LI);
      if LAdv.Width = 0 then begin Inc(LI, LAdv.ByteLen); Continue; end;
      if LCursor + LAdv.Width > FArea.X + FArea.Width then Break;
      LCell := CELL_EMPTY;
      CellSetSymbolBytes(LCell, PByte(@AStr[1])[LI], LAdv.ByteLen, LAdv.Width);
      CellApplyStyle(LCell, AStyle);
      SetCell(LCursor, AY, LCell);
      if LAdv.Width = 2 then
      begin
        LCell := CELL_EMPTY; LCell.Width := 0; LCell.Skip := True;
        SetCell(LCursor + 1, AY, LCell);
      end;
      Inc(LCursor, LAdv.Width);
      Inc(LI, LAdv.ByteLen);
    end;
  end;
end;

procedure TOverlayBuffer.SetStyle(const A: TRect; const AStyle: TStyle);
var
  LClip: TRect;
  LX, LY, LIdx: Integer;
  LCell: TCell;
begin
  LClip := FArea.Intersection(A);
  if LClip.IsEmpty then Exit;
  for LY := LClip.Top to LClip.Bottom - 1 do
    for LX := LClip.Left to LClip.Right - 1 do
    begin
      LIdx := IndexOf(LX, LY);
      if FMarks[LIdx] then
        CellApplyStyle(FCells[LIdx], AStyle)
      else
      begin
        LCell := CELL_EMPTY;
        CellApplyStyle(LCell, AStyle);
        FCells[LIdx] := LCell;
        FMarks[LIdx] := True;
      end;
    end;
  FDirty := True;
end;

procedure TOverlayBuffer.Clear;
begin
  if System.Length(FMarks) > 0 then
    FillChar(FMarks[0], System.Length(FMarks) * SizeOf(Boolean), 0);
  FDirty := True;
end;

procedure TOverlayBuffer.Resize(const ANewArea: TRect);
var
  LN: Integer;
begin
  FArea := ANewArea;
  LN := ANewArea.Area;
  SetLength(FCells, LN);
  SetLength(FMarks, LN);
  Clear;
end;

procedure TOverlayBuffer.MergeInto(ABase, ADest: TBuffer);
var
  LI, LTotal: Integer;
  LDstCell: PCell;
begin
  Assert((ABase.Area.X = ADest.Area.X) and (ABase.Area.Y = ADest.Area.Y)
    and (ABase.Area.Width = ADest.Area.Width) and (ABase.Area.Height = ADest.Area.Height),
    'MergeInto: Base 与 Dest 必须同 Area');
  LTotal := System.Length(FMarks);
  if LTotal = 0 then Exit;
  { Dest 应已是 Base 的拷贝或刚从 Base 填充。此处只覆盖标记过的位置。 }
  for LI := 0 to LTotal - 1 do
  begin
    if FMarks[LI] then
    begin
      LDstCell := ADest.CellAt(
        FArea.X + (LI mod FArea.Width),
        FArea.Y + (LI div FArea.Width));
      if LDstCell <> nil then
        LDstCell^ := FCells[LI];
    end;
  end;
end;

procedure TOverlayBuffer.MarkDirty;
begin
  FDirty := True;
end;

procedure TOverlayBuffer.ClearDirty;
begin
  FDirty := False;
end;

end.
