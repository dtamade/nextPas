unit nextpas.core.tui.buffer;

{**
 * @desc 单元格缓冲区（对齐 ratatui::buffer::Buffer）。
 *
 * 存储：`array of TCell`，按 (Y - Area.Y) * Area.Width + (X - Area.X) 索引。
 * 单块连续分配，无嵌套数组、无逐行分配。热路径（CellAt / SetString / Diff）
 * 线性遍历数组，经 PCell 指针解引用——零拷贝、逐 cell 零分配。
 *
 * Diff 精确对齐 ratatui 0.29：两个计数器 ToSkip 与 Invalidated 跨列传播
 * 宽字形状态，确保渲染层永不发出宽度 2 grapheme 的尾列。
 *
 * @note TBuffer 是 class（引用语义）：widget 的 Render(const AArea; ABuffer)
 *       按值传对象引用，写入直达原 buffer。TTerminal 持有 prev/curr/overlay/
 *       merged 四个 buffer，EndFrame 后交换 prev/merged 引用（O(1)）。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}
{$packset 2}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.modifier,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.image_cap;

type
  TDiffEntry = packed record
    X, Y: Word;
    Cell: TCell;
  end;
  TDiffEntries = array of TDiffEntry;

  TImagePlacement = record
    Hash: QWord;
    Area: TRect;
    DataPtr: Pointer;
    DataLen: Integer;
    PixelWidth: Integer;
    PixelHeight: Integer;
  end;

  TScaledPixelBuf = array of Byte;

  TBufferLines = array of AnsiString;

  TBuffer = class
  private
    FArea: TRect;
    FContent: array of TCell;
    FDirtyRows: QWord;
    FImagePlacements: array of TImagePlacement;
    FImagePlacementCount: Integer;
    FImageProtocol: TImageProtocol;
    function IndexOfPos(AX, AY: Integer): Integer; inline;
    procedure MarkRowDirty(ARow: Integer); inline;
  public
    constructor CreateEmpty(const AArea: TRect);
    constructor CreateFilled(const AArea: TRect; const ACell: TCell);

    property Area: TRect read FArea;
    function Width: Word; inline;
    function Height: Word; inline;
    function Length_: Integer; inline;       { cell 数量 }
    function ContentPtr: PCell; inline;

    { 按坐标读写。(AX,AY) 在 Area 外返回 nil。 }
    function CellAt(AX, AY: Integer): PCell;

    { 从 (AX,AY) 起写 UTF-8 / ASCII 串，受右边界与可选 AMaxWidth（列）约束。
      样式经 CellApplyStyle 应用到每个写入 cell。返回实际写入列数。 }
    function SetString(AX, AY: Integer; const AStr: AnsiString;
      const AStyle: TStyle): Integer;
    function SetStringN(AX, AY: Integer; const AStr: AnsiString; AMaxWidth: Integer;
      const AStyle: TStyle): Integer;
    function SetStringP(AX, AY: Integer; AStr: PAnsiChar; ALen, AMaxWidth: Integer;
      const AStyle: TStyle): Integer;

    { 对 A 与 Area 交集内每个 cell 应用样式。 }
    procedure SetStyle(const A: TRect; const AStyle: TStyle);

    { 用单字符 cell 与样式填充矩形区域。 }
    procedure FillRect(const A: TRect; ACh: AnsiChar; const AStyle: TStyle);

    { 把矩形区域内每个 cell 重置为 CELL_EMPTY。 }
    procedure ClearRect(const A: TRect);

    { 把每个 cell 重置为 CELL_EMPTY。 }
    procedure Reset;

    { 调整底层区域为 ANewArea。重叠区 cell 保留，其余填 CELL_EMPTY。 }
    procedure Resize(const ANewArea: TRect);

    { 计算 Self(prev) 与 ANext(curr) 的差异。输出 append-only Patches，
      供 ANSI 后端回放。仅一次 SetLength。 }
    procedure Diff(const ANext: TBuffer; out APatches: TDiffEntries);

    { 同 Diff，但复用 Patches 数组（只增不减）。返回有效条目数。
      热路径调用方应优先用此版本避免每帧分配。 }
    function DiffInto(const ANext: TBuffer; var APatches: TDiffEntries): Integer;

    { 测试辅助——勿在生产代码调用。 }
    function RowAsString(AY: Integer): AnsiString;
    function AsLines: TBufferLines;

    { 终端检测到的本帧图像协议（由 TTerminal 设置）。 }
    property ImageProtocol: TImageProtocol read FImageProtocol write FImageProtocol;

    { 图像协议支持的占位声明。DataPtr 须保持有效直到 EndFrame 完成
      （调用方拥有数据）。 }
    procedure PlaceImage(AHash: QWord; const AImgArea: TRect;
      ADataPtr: Pointer; ADataLen: Integer; APixelWidth, APixelHeight: Integer);
    function ImagePlacementCount: Integer; inline;
    function ImagePlacementAt(AIndex: Integer): TImagePlacement; inline;
  end;

procedure ScaleRgbaPixels(ASrc: PByte; ASrcW, ASrcH, ADstW, ADstH: Integer;
  var ADst: TScaledPixelBuf);

implementation

uses
  nextpas.core.text.utf8,
  nextpas.core.text.width;

type
  { 单个 grapheme 解码结果（byte 长度 + 显示宽度 + 码点） }
  TGraphemeAdvance = record
    ByteLen: Integer;     { 1..4，非法时 1（跳过一字节） }
    Width: Integer;       { 0 / 1 / 2 }
    Codepoint: UInt32;
  end;

{ 解码 ABuf+AOffset 处的下一个 UTF-8 grapheme（码点级）。
  非法字节返回 ByteLen=1 / Width=1 / Codepoint=$FFFD，调用方可继续前进。 }
function GraphemeAt(const ABuf; ALen, AOffset: Integer): TGraphemeAdvance; inline;
var
  LDec: TUTF8DecodeResult;
  LPtr: PByte;
begin
  LPtr := PByte(@ABuf);
  LDec := UTF8Decode(@LPtr[AOffset], ALen - AOffset);
  if LDec.ByteLen = 0 then
  begin
    { 非法/截断：跳过一字节，按宽度 1 计 }
    Result.ByteLen := 1;
    Result.Width := 1;
    Result.Codepoint := $FFFD;
  end
  else
  begin
    Result.ByteLen := LDec.ByteLen;
    Result.Codepoint := LDec.CodePoint;
    Result.Width := CodepointWidth(LDec.CodePoint);
  end;
end;

{ TBuffer }

constructor TBuffer.CreateEmpty(const AArea: TRect);
begin
  inherited Create;
  FArea := AArea;
  FDirtyRows := QWord(-1);
  SetLength(FContent, AArea.Area);
  Reset;
end;

constructor TBuffer.CreateFilled(const AArea: TRect; const ACell: TCell);
var
  LIdx, LTotal: Integer;
begin
  inherited Create;
  FArea := AArea;
  FDirtyRows := QWord(-1);
  LTotal := AArea.Area;
  SetLength(FContent, LTotal);
  for LIdx := 0 to LTotal - 1 do
    FContent[LIdx] := ACell;
end;

function TBuffer.Width: Word;
begin
  Result := FArea.Width;
end;

function TBuffer.Height: Word;
begin
  Result := FArea.Height;
end;

function TBuffer.Length_: Integer;
begin
  Result := System.Length(FContent);
end;

function TBuffer.ContentPtr: PCell;
begin
  if System.Length(FContent) = 0 then
    Result := nil
  else
    Result := @FContent[0];
end;

function TBuffer.IndexOfPos(AX, AY: Integer): Integer;
begin
  Result := (AY - FArea.Y) * FArea.Width + (AX - FArea.X);
end;

procedure TBuffer.MarkRowDirty(ARow: Integer);
begin
  if ARow < 64 then
    FDirtyRows := FDirtyRows or (QWord(1) shl ARow);
end;

function TBuffer.CellAt(AX, AY: Integer): PCell;
begin
  if (AX < FArea.X) or (AX >= FArea.X + FArea.Width) or
     (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then
    Exit(nil);
  Result := @FContent[IndexOfPos(AX, AY)];
end;

function TBuffer.SetString(AX, AY: Integer; const AStr: AnsiString;
  const AStyle: TStyle): Integer;
begin
  Result := SetStringN(AX, AY, AStr, MaxInt, AStyle);
end;

function TBuffer.SetStringN(AX, AY: Integer; const AStr: AnsiString;
  AMaxWidth: Integer; const AStyle: TStyle): Integer;
var
  LRight, LRemaining, LI, LCursor, LGLen: Integer;
  LCP: PCell;
  LAdv: TGraphemeAdvance;
  LAscii: Boolean;
  LByte: Byte;
begin
  Result := 0;
  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  if AX >= FArea.X + FArea.Width then Exit;
  if AX < FArea.X then AX := FArea.X;
  MarkRowDirty(AY - FArea.Y);

  LRight := FArea.X + FArea.Width;
  LRemaining := LRight - AX;
  if LRemaining > AMaxWidth then LRemaining := AMaxWidth;
  if LRemaining <= 0 then Exit;
  LGLen := System.Length(AStr);
  if LGLen = 0 then Exit;

  { 热 ASCII 路径——多数 UI 串（状态栏、英文）为纯 ASCII，保留字节循环。 }
  LAscii := True;
  for LI := 1 to LGLen do
    if Byte(AStr[LI]) >= $80 then
    begin
      LAscii := False;
      Break;
    end;

  LCursor := AX;
  if LAscii then
  begin
    for LI := 1 to LGLen do
    begin
      if LRemaining = 0 then Break;
      LByte := Byte(AStr[LI]);
      if LByte < 32 then Continue;        { 丢弃控制字符（ratatui 对齐） }
      LCP := @FContent[IndexOfPos(LCursor, AY)];
      CellSetSymbolAscii(LCP^, AStr[LI]);
      CellApplyStyle(LCP^, AStyle);
      Inc(LCursor);
      Inc(Result);
      Dec(LRemaining);
    end;
    Exit;
  end;

  { UTF-8 grapheme 路径。逐码点解码。宽度 2 簇占两个 cell：前导 cell 携带
    glyph 字节且 Width=2；尾随 cell 重置为 CELL_EMPTY、Width=0、Skip=True，
    使 diff/render 层留空。 }
  LI := 0;
  while LI < LGLen do
  begin
    if LRemaining = 0 then Break;
    LAdv := GraphemeAt(AStr[1], LGLen, LI);

    if LAdv.Width = 0 then
    begin
      Inc(LI, LAdv.ByteLen);
      Continue;
    end;

    if LAdv.Width > LRemaining then Break;   { 宽字形空间不足 }

    LCP := @FContent[IndexOfPos(LCursor, AY)];
    CellSetSymbolBytes(LCP^, PByte(@AStr[1])[LI], LAdv.ByteLen, LAdv.Width);
    CellApplyStyle(LCP^, AStyle);

    if LAdv.Width = 2 then
    begin
      LCP := @FContent[IndexOfPos(LCursor + 1, AY)];
      CellReset(LCP^);
      LCP^.Width := 0;
      LCP^.Skip := True;
    end;

    Inc(LCursor, LAdv.Width);
    Inc(Result, LAdv.Width);
    Dec(LRemaining, LAdv.Width);
    Inc(LI, LAdv.ByteLen);
  end;
end;

function TBuffer.SetStringP(AX, AY: Integer; AStr: PAnsiChar; ALen, AMaxWidth: Integer;
  const AStyle: TStyle): Integer;
var
  LRight, LRemaining, LI, LCursor: Integer;
  LCP: PCell;
  LByte: Byte;
  LAdv: TGraphemeAdvance;
  LAscii: Boolean;
begin
  Result := 0;
  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  if AX >= FArea.X + FArea.Width then Exit;
  if AX < FArea.X then AX := FArea.X;
  LRight := FArea.X + FArea.Width;
  LRemaining := LRight - AX;
  if LRemaining > AMaxWidth then LRemaining := AMaxWidth;
  if (LRemaining <= 0) or (ALen <= 0) then Exit;

  LAscii := True;
  for LI := 0 to ALen - 1 do
    if Byte(AStr[LI]) >= $80 then begin LAscii := False; Break; end;

  LCursor := AX;
  if LAscii then
  begin
    for LI := 0 to ALen - 1 do
    begin
      if LRemaining = 0 then Break;
      LByte := Byte(AStr[LI]);
      if LByte < 32 then Continue;
      LCP := @FContent[IndexOfPos(LCursor, AY)];
      CellSetSymbolAscii(LCP^, AStr[LI]);
      CellApplyStyle(LCP^, AStyle);
      Inc(LCursor);
      Inc(Result);
      Dec(LRemaining);
    end;
    Exit;
  end;

  LI := 0;
  while LI < ALen do
  begin
    if LRemaining = 0 then Break;
    LAdv := GraphemeAt(AStr^, ALen, LI);
    if LAdv.Width = 0 then begin Inc(LI, LAdv.ByteLen); Continue; end;
    if LAdv.Width > LRemaining then Break;
    LCP := @FContent[IndexOfPos(LCursor, AY)];
    CellSetSymbolBytes(LCP^, PByte(AStr)[LI], LAdv.ByteLen, LAdv.Width);
    CellApplyStyle(LCP^, AStyle);
    if LAdv.Width = 2 then
    begin
      LCP := @FContent[IndexOfPos(LCursor + 1, AY)];
      CellReset(LCP^);
      LCP^.Width := 0;
      LCP^.Skip := True;
    end;
    Inc(LCursor, LAdv.Width);
    Inc(Result, LAdv.Width);
    Dec(LRemaining, LAdv.Width);
    Inc(LI, LAdv.ByteLen);
  end;
end;

procedure TBuffer.SetStyle(const A: TRect; const AStyle: TStyle);
var
  LClip: TRect;
  LX, LY: Integer;
  LCP: PCell;
begin
  LClip := FArea.Intersection(A);
  if LClip.IsEmpty then Exit;
  for LY := LClip.Top to LClip.Bottom - 1 do
  begin
    MarkRowDirty(LY - FArea.Y);
    for LX := LClip.Left to LClip.Right - 1 do
    begin
      LCP := @FContent[IndexOfPos(LX, LY)];
      CellApplyStyle(LCP^, AStyle);
    end;
  end;
end;

procedure TBuffer.FillRect(const A: TRect; ACh: AnsiChar; const AStyle: TStyle);
var
  LClip: TRect;
  LX, LY: Integer;
  LCP: PCell;
  LCell: TCell;
begin
  LClip := FArea.Intersection(A);
  if LClip.IsEmpty then Exit;
  LCell := CELL_EMPTY;
  CellSetSymbolAscii(LCell, ACh);
  CellApplyStyle(LCell, AStyle);
  for LY := LClip.Top to LClip.Bottom - 1 do
  begin
    MarkRowDirty(LY - FArea.Y);
    for LX := LClip.Left to LClip.Right - 1 do
    begin
      LCP := @FContent[IndexOfPos(LX, LY)];
      LCP^ := LCell;
    end;
  end;
end;

procedure TBuffer.ClearRect(const A: TRect);
var
  LClip: TRect;
  LX, LY: Integer;
  LCP: PCell;
begin
  LClip := FArea.Intersection(A);
  if LClip.IsEmpty then Exit;
  for LY := LClip.Top to LClip.Bottom - 1 do
  begin
    MarkRowDirty(LY - FArea.Y);
    for LX := LClip.Left to LClip.Right - 1 do
    begin
      LCP := @FContent[IndexOfPos(LX, LY)];
      LCP^ := CELL_EMPTY;
    end;
  end;
end;

procedure TBuffer.Reset;
var
  LI, LTotal: Integer;
  LDirty: TCell;
begin
  LTotal := System.Length(FContent);
  if LTotal = 0 then Exit;
  { 用一个与 CELL_EMPTY 不同的 cell，使 reset 后（如终端 resize）Diff 必产补丁。 }
  LDirty := CELL_EMPTY;
  LDirty.Glyph.Len := 0;  { 正常渲染不可能 → 保证 diff }
  FContent[0] := LDirty;
  LI := 1;
  while LI + LI <= LTotal do
  begin
    Move(FContent[0], FContent[LI], LI * SizeOf(TCell));
    LI := LI + LI;
  end;
  if LI < LTotal then
    Move(FContent[0], FContent[LI], (LTotal - LI) * SizeOf(TCell));
  FImagePlacementCount := 0;
  FDirtyRows := QWord(-1);
end;

procedure TBuffer.Resize(const ANewArea: TRect);
var
  LOld: array of TCell;
  LOldArea: TRect;
  LX, LY, LIdx: Integer;
  LSrc: PCell;
begin
  if RectEquals(ANewArea, FArea) then Exit;

  LOld := FContent;
  LOldArea := FArea;

  FArea := ANewArea;
  SetLength(FContent, ANewArea.Area);
  { 先填充新缓冲。 }
  for LIdx := 0 to System.Length(FContent) - 1 do
    FContent[LIdx] := CELL_EMPTY;

  { 从 Old 拷贝重叠区。 }
  for LY := LOldArea.Top to LOldArea.Bottom - 1 do
    for LX := LOldArea.Left to LOldArea.Right - 1 do
    begin
      if (LX < ANewArea.X) or (LX >= ANewArea.X + ANewArea.Width) then Continue;
      if (LY < ANewArea.Y) or (LY >= ANewArea.Y + ANewArea.Height) then Continue;
      LSrc := @LOld[(LY - LOldArea.Y) * LOldArea.Width + (LX - LOldArea.X)];
      FContent[(LY - ANewArea.Y) * ANewArea.Width + (LX - ANewArea.X)] := LSrc^;
    end;
end;

procedure TBuffer.Diff(const ANext: TBuffer; out APatches: TDiffEntries);
var
  LTotal, LI, LOutCount, LAffectedWidth: Integer;
  LToSkip, LInvalidated: Integer;
  LPrev, LCurr: PCell;
  LPrevBase, LCurrBase: PCell;
  LPrevRow, LCurrRow: PCell;
  LDiffers: Boolean;
  LPosX, LPosY: Word;
  LW, LRow, LCol, LRowBytes: Integer;
{$PUSH}{$R-}{$Q-}
begin
  if (System.Length(FContent) = 0) or (System.Length(ANext.FContent) = 0) then
  begin
    SetLength(APatches, 0);
    Exit;
  end;

  if (ANext.FArea.Width <> FArea.Width) or
     (ANext.FArea.Height <> FArea.Height) then
  begin
    LTotal := System.Length(ANext.FContent);
    SetLength(APatches, LTotal);
    LPosX := ANext.FArea.X;
    LPosY := ANext.FArea.Y;
    LW := ANext.FArea.Width;
    for LI := 0 to LTotal - 1 do
    begin
      APatches[LI].X := LPosX;
      APatches[LI].Y := LPosY;
      APatches[LI].Cell := ANext.FContent[LI];
      Inc(LPosX);
      if LPosX >= ANext.FArea.X + LW then
      begin
        LPosX := ANext.FArea.X;
        Inc(LPosY);
      end;
    end;
    Exit;
  end;

  LTotal := System.Length(FContent);
  SetLength(APatches, LTotal);
  LOutCount := 0;
  LToSkip := 0;
  LInvalidated := 0;
  LW := FArea.Width;
  LRowBytes := LW * SizeOf(TCell);
  LPrevBase := @FContent[0];
  LCurrBase := @ANext.FContent[0];

  for LRow := 0 to FArea.Height - 1 do
  begin
    LPrevRow := LPrevBase + (LRow * LW);
    LCurrRow := LCurrBase + (LRow * LW);

    if (LInvalidated = 0) and (LToSkip = 0) then
    begin
      if (LRow < 64) and ((ANext.FDirtyRows and (QWord(1) shl LRow)) = 0) then
        Continue;
      if CompareByte(LPrevRow^, LCurrRow^, LRowBytes) = 0 then
        Continue;
    end;

    LPosY := FArea.Y + LRow;
    for LCol := 0 to LW - 1 do
    begin
      LPosX := FArea.X + LCol;
      LPrev := LPrevRow + LCol;
      LCurr := LCurrRow + LCol;

      LDiffers := (PQWord(LPrev)[0] <> PQWord(LCurr)[0]) or
                  (PQWord(LPrev)[1] <> PQWord(LCurr)[1]) or
                  (PQWord(LPrev)[2] <> PQWord(LCurr)[2]) or
                  (PQWord(LPrev)[3] <> PQWord(LCurr)[3]) or
                  (PQWord(LPrev)[4] <> PQWord(LCurr)[4]);

      if (not LCurr^.Skip) and (LDiffers or (LInvalidated > 0)) and (LToSkip = 0) then
      begin
        APatches[LOutCount].X := LPosX;
        APatches[LOutCount].Y := LPosY;
        APatches[LOutCount].Cell := LCurr^;
        Inc(LOutCount);
      end;

      if LToSkip > 0 then
        Dec(LToSkip)
      else
        LToSkip := LCurr^.Width - 1;
      if LToSkip < 0 then LToSkip := 0;

      LAffectedWidth := LCurr^.Width;
      if LPrev^.Width > LAffectedWidth then LAffectedWidth := LPrev^.Width;
      if LAffectedWidth > LInvalidated then LInvalidated := LAffectedWidth;
      if LInvalidated > 0 then Dec(LInvalidated);
    end;
  end;

  SetLength(APatches, LOutCount);
{$POP}
end;

function TBuffer.DiffInto(const ANext: TBuffer; var APatches: TDiffEntries): Integer;
var
  LTotal, LOutCount, LAffectedWidth: Integer;
  LToSkip, LInvalidated: Integer;
  LPrev, LCurr: PCell;
  LPrevBase, LCurrBase: PCell;
  LPrevRow, LCurrRow: PCell;
  LDiffers: Boolean;
  LPosX, LPosY: Word;
  LW, LRow, LCol, LRowBytes: Integer;
{$PUSH}{$R-}{$Q-}
begin
  if (System.Length(FContent) = 0) or (System.Length(ANext.FContent) = 0) then
  begin
    Result := 0;
    Exit;
  end;

  LTotal := System.Length(FContent);
  if (ANext.FArea.Width <> FArea.Width) or
     (ANext.FArea.Height <> FArea.Height) then
    LTotal := System.Length(ANext.FContent);

  if System.Length(APatches) < LTotal then
    SetLength(APatches, LTotal);

  if (ANext.FArea.Width <> FArea.Width) or
     (ANext.FArea.Height <> FArea.Height) then
  begin
    LPosX := ANext.FArea.X;
    LPosY := ANext.FArea.Y;
    LW := ANext.FArea.Width;
    for LCol := 0 to LTotal - 1 do
    begin
      APatches[LCol].X := LPosX;
      APatches[LCol].Y := LPosY;
      APatches[LCol].Cell := ANext.FContent[LCol];
      Inc(LPosX);
      if LPosX >= ANext.FArea.X + LW then
      begin
        LPosX := ANext.FArea.X;
        Inc(LPosY);
      end;
    end;
    Result := LTotal;
    Exit;
  end;

  LOutCount := 0;
  LToSkip := 0;
  LInvalidated := 0;
  LW := FArea.Width;
  LRowBytes := LW * SizeOf(TCell);
  LPrevBase := @FContent[0];
  LCurrBase := @ANext.FContent[0];

  for LRow := 0 to FArea.Height - 1 do
  begin
    LPrevRow := LPrevBase + (LRow * LW);
    LCurrRow := LCurrBase + (LRow * LW);

    if (LInvalidated = 0) and (LToSkip = 0) then
    begin
      if (LRow < 64) and ((ANext.FDirtyRows and (QWord(1) shl LRow)) = 0) then
        Continue;
      if CompareByte(LPrevRow^, LCurrRow^, LRowBytes) = 0 then
        Continue;
    end;

    LPosY := FArea.Y + LRow;
    for LCol := 0 to LW - 1 do
    begin
      LPosX := FArea.X + LCol;
      LPrev := LPrevRow + LCol;
      LCurr := LCurrRow + LCol;

      LDiffers := (PQWord(LPrev)[0] <> PQWord(LCurr)[0]) or
                  (PQWord(LPrev)[1] <> PQWord(LCurr)[1]) or
                  (PQWord(LPrev)[2] <> PQWord(LCurr)[2]) or
                  (PQWord(LPrev)[3] <> PQWord(LCurr)[3]) or
                  (PQWord(LPrev)[4] <> PQWord(LCurr)[4]);

      if (not LCurr^.Skip) and (LDiffers or (LInvalidated > 0)) and (LToSkip = 0) then
      begin
        APatches[LOutCount].X := LPosX;
        APatches[LOutCount].Y := LPosY;
        APatches[LOutCount].Cell := LCurr^;
        Inc(LOutCount);
      end;

      if LToSkip > 0 then
        Dec(LToSkip)
      else
        LToSkip := LCurr^.Width - 1;
      if LToSkip < 0 then LToSkip := 0;

      LAffectedWidth := LCurr^.Width;
      if LPrev^.Width > LAffectedWidth then LAffectedWidth := LPrev^.Width;
      if LAffectedWidth > LInvalidated then LInvalidated := LAffectedWidth;
      if LInvalidated > 0 then Dec(LInvalidated);
    end;
  end;

  Result := LOutCount;
{$POP}
end;

function TBuffer.RowAsString(AY: Integer): AnsiString;
var
  LX, LIdx, LOutByte, LGlyphLen, LTotalBytes: Integer;
  LCP: PCell;
begin
  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit('');

  { 两遍：先量度再一次性物化。即便在冷/诊断路径也不做字符串拼接，模式保持
    示范性。Width=0 哨兵 cell（宽字形尾列）跳过——前导 cell 已提供多字节 glyph。 }
  LTotalBytes := 0;
  for LX := FArea.X to FArea.X + FArea.Width - 1 do
  begin
    LIdx := IndexOfPos(LX, AY);
    LCP := @FContent[LIdx];
    if LCP^.Width = 0 then
      Continue                          { CJK 尾列哨兵 }
    else if LCP^.Glyph.Len = 0 then
      Inc(LTotalBytes)                  { 空 cell 渲染为一个空格 }
    else
      Inc(LTotalBytes, LCP^.Glyph.Len);
  end;

  SetLength(Result, LTotalBytes);
  LOutByte := 1;                         { AnsiString 1-indexed }
  for LX := FArea.X to FArea.X + FArea.Width - 1 do
  begin
    LIdx := IndexOfPos(LX, AY);
    LCP := @FContent[LIdx];
    if LCP^.Width = 0 then
      Continue;
    LGlyphLen := LCP^.Glyph.Len;
    if LGlyphLen = 0 then
    begin
      Result[LOutByte] := ' ';
      Inc(LOutByte);
    end
    else
    begin
      Move(LCP^.Glyph.Bytes[0], Result[LOutByte], LGlyphLen);
      Inc(LOutByte, LGlyphLen);
    end;
  end;
end;

function TBuffer.AsLines: TBufferLines;
var
  LY: Integer;
begin
  Result := nil;
  SetLength(Result, FArea.Height);
  for LY := 0 to FArea.Height - 1 do
    Result[LY] := RowAsString(FArea.Y + LY);
end;

procedure TBuffer.PlaceImage(AHash: QWord; const AImgArea: TRect;
  ADataPtr: Pointer; ADataLen: Integer; APixelWidth, APixelHeight: Integer);
var
  LCap: Integer;
begin
  LCap := System.Length(FImagePlacements);
  if FImagePlacementCount >= LCap then
  begin
    if LCap = 0 then LCap := 4 else LCap := LCap * 2;
    SetLength(FImagePlacements, LCap);
  end;
  FImagePlacements[FImagePlacementCount].Hash := AHash;
  FImagePlacements[FImagePlacementCount].Area := AImgArea;
  FImagePlacements[FImagePlacementCount].DataPtr := ADataPtr;
  FImagePlacements[FImagePlacementCount].DataLen := ADataLen;
  FImagePlacements[FImagePlacementCount].PixelWidth := APixelWidth;
  FImagePlacements[FImagePlacementCount].PixelHeight := APixelHeight;
  Inc(FImagePlacementCount);
end;

function TBuffer.ImagePlacementCount: Integer;
begin
  Result := FImagePlacementCount;
end;

function TBuffer.ImagePlacementAt(AIndex: Integer): TImagePlacement;
begin
  Result := FImagePlacements[AIndex];
end;

procedure ScaleRgbaPixels(ASrc: PByte; ASrcW, ASrcH, ADstW, ADstH: Integer;
  var ADst: TScaledPixelBuf);
var
  LX, LY, LSrcX, LSrcY, LSrcOff, LDstOff: Integer;
begin
  SetLength(ADst, ADstW * ADstH * 4);
  for LY := 0 to ADstH - 1 do
  begin
    LSrcY := LY * ASrcH div ADstH;
    for LX := 0 to ADstW - 1 do
    begin
      LSrcX := LX * ASrcW div ADstW;
      LSrcOff := (LSrcY * ASrcW + LSrcX) * 4;
      LDstOff := (LY * ADstW + LX) * 4;
      ADst[LDstOff] := ASrc[LSrcOff];
      ADst[LDstOff + 1] := ASrc[LSrcOff + 1];
      ADst[LDstOff + 2] := ASrc[LSrcOff + 2];
      ADst[LDstOff + 3] := ASrc[LSrcOff + 3];
    end;
  end;
end;

end.
