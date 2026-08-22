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
  nextpas.core.mem.intf,
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

  { OSC 8 超链接 span（刀 21）：输出层 overlay——渲染方在真实重渲时扫描
    buffer 收集链接区间，设到 TTerminal；TAnsiBackend 绘制命中 cell 时
    包裹 `ESC]8;;url BEL` 开 / `ESC]8;;BEL` 关。Id <> 0 时开序列带
    `id=Id`（同 URL 多段共享 id 实现 hover 连续，grok osc8.rs）。
    不参与 TCell（40 字节 QWord 比较约束），靠「链接样式（下划线/色）
    画进 cell」让 diff 输出自然携带链接重写。 }
  TTuiLinkSpan = record
    Y: Word;
    ColStart: Word;   { 起始列（含）}
    ColEnd: Word;     { 结束列（不含）}
    Id: Cardinal;
    Url: AnsiString;
  end;
  TTuiLinkOverlay = array of TTuiLinkSpan;

  TImagePlacement = record
    Hash: QWord;
    Area: TRect;
    DataPtr: Pointer;
    DataLen: Integer;
    PixelWidth: Integer;
    PixelHeight: Integer;
    { True = 原始编码图流（kitty f=100，终端自解码，不做 RGBA 缩放）；
      False = 调用方已解码的 RGBA 像素（f=32）。 }
    Encoded: Boolean;
    { 刀 60 source-crop：kitty 源矩形裁剪（像素坐标）。SrcW/SrcH > 0
      时放置命令发射 x/y/w/h 键——部分可见块只显示可见带；
      全 0 = 整图放置（既有行为零回归）。 }
    SrcX: Integer;
    SrcY: Integer;
    SrcW: Integer;
    SrcH: Integer;
  end;

  TScaledPixelBuf = array of Byte;

  TBufferLines = array of AnsiString;

  TBuffer = class
  private
    FArea: TRect;
    FContent: array of TCell;       { nil-allocator path (managed dynarray) }
    FContentPtr: PCell;             { non-nil allocator path }
    FContentCount: Integer;
    FAllocator: IAllocator;
    FDirtyRows: QWord;
    FImagePlacements: array of TImagePlacement;
    FImagePlacementCount: Integer;
    FImageProtocol: TImageProtocol;
    function ContentBase: PCell; inline;
    function ContentLen: Integer; inline;
    function IndexOfPos(AX, AY: Integer): Integer; inline;
    procedure MarkRowDirty(ARow: Integer); inline;
    procedure NormalizeWideGlyphBoundaries;
    procedure ClearWideOverlapCell(AX, AY: Integer); inline;
    procedure PrepareWriteSpan(AX, AY, AWidth: Integer); inline;
    procedure FreeOwnedContent;
    procedure AllocContent(ACount: Integer);
  public
    constructor CreateEmpty(const AArea: TRect; const AAllocator: IAllocator = nil);
    constructor CreateFilled(const AArea: TRect; const ACell: TCell;
      const AAllocator: IAllocator = nil);
    destructor Destroy; override;

    property Area: TRect read FArea;
    function Width: Word; inline;
    function Height: Word; inline;
    function Length_: Integer; inline;       { cell 数量 }
    function ContentPtr: PCell; inline;

    { 按坐标读写。(AX,AY) 在 Area 外返回 nil。 }
    function CellAt(AX, AY: Integer): PCell;

    { 从 (AX,AY) 起写 UTF-8 / ASCII 串，受左右边界与可选 AMaxWidth（列）约束。
      样式经 CellApplyStyle 应用到每个写入 cell。返回实际写入列数。 }
    function SetString(AX, AY: Integer; const AStr: AnsiString;
      const AStyle: TStyle): Integer;
    function SetStringN(AX, AY: Integer; const AStr: AnsiString; AMaxWidth: Integer;
      const AStyle: TStyle): Integer;
    function SetStringP(AX, AY: Integer; AStr: PAnsiChar; ALen, AMaxWidth: Integer;
      const AStyle: TStyle): Integer;

    { 从 (AX,AY) 起把 AStr 重复填充 AWidth 列(按字素推进,超宽安全截断;
      与 SetStringN 的「写一次截断」互补,画横线/分隔线热路径零堆分配)。 }
    function FillH(AX, AY: Integer; const AStr: AnsiString; AWidth: Integer;
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
    property DirtyRows: QWord read FDirtyRows write FDirtyRows;

    { 图像协议支持的占位声明。DataPtr 须保持有效直到 EndFrame 完成
      （调用方拥有数据）。 }
    procedure PlaceImage(AHash: QWord; const AImgArea: TRect;
      ADataPtr: Pointer; ADataLen: Integer; APixelWidth, APixelHeight: Integer);
    { 原始编码图流（如 PNG 字节）：终端按占位矩形拉伸显示，传输用
      kitty f=100 直传（终端自解码）。仅 ipKitty 协议输出；
      sixel/half-block 无终端解码能力，调用方应自行降级。 }
    procedure PlaceImageEncoded(AHash: QWord; const AImgArea: TRect;
      ADataPtr: Pointer; ADataLen: Integer; APixelWidth, APixelHeight: Integer;
      ASrcX: Integer = 0; ASrcY: Integer = 0; ASrcW: Integer = 0;
      ASrcH: Integer = 0);
    function ImagePlacementCount: Integer; inline;
    function ImagePlacementAt(AIndex: Integer): TImagePlacement; inline;
  end;

procedure ScaleRgbaPixels(ASrc: PByte; ASrcW, ASrcH, ADstW, ADstH: Integer;
  var ADst: TScaledPixelBuf);

implementation

uses
  nextpas.core.base,
  nextpas.core.text.utf8,
  nextpas.core.text.width,
  nextpas.core.text.grapheme;

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
  LGR: TGraphemeResult;
begin
  LGR := GraphemeNext(@PByte(@ABuf)[AOffset], ALen - AOffset);
  Result.ByteLen := LGR.ByteLen;
  Result.Width := LGR.Width;
  Result.Codepoint := $FFFD;
end;

{ TBuffer }

function TBuffer.ContentBase: PCell;
begin
  if FAllocator <> nil then
    Result := FContentPtr
  else if System.Length(FContent) = 0 then
    Result := nil
  else
    Result := @FContent[0];
end;

function TBuffer.ContentLen: Integer;
begin
  if FAllocator <> nil then
    Result := FContentCount
  else
    Result := System.Length(FContent);
end;

procedure TBuffer.FreeOwnedContent;
begin
  if FAllocator <> nil then
  begin
    { Keep IAllocator.FreeMem so inject/tracking observes free. }
    if FContentPtr <> nil then
    begin
      FAllocator.FreeMem(FContentPtr);
      FContentPtr := nil;
    end;
    FContentCount := 0;
  end
  else
    SetLength(FContent, 0);
end;

procedure TBuffer.AllocContent(ACount: Integer);
var
  LBytes: SizeUInt;
begin
  if FAllocator <> nil then
  begin
    FreeOwnedContent;
    FContentCount := ACount;
    if ACount <= 0 then
    begin
      FContentPtr := nil;
      Exit;
    end;
    LBytes := SizeUInt(ACount) * SizeOf(TCell);
    FContentPtr := PCell(FAllocator.GetMem(LBytes));
    if FContentPtr = nil then
    begin
      FContentCount := 0;
      raise EOutOfMemory.Create('TBuffer allocation failed');
    end;
  end
  else
  begin
    FContentPtr := nil;
    FContentCount := 0;
    SetLength(FContent, ACount);
  end;
end;

constructor TBuffer.CreateEmpty(const AArea: TRect; const AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
  FContentPtr := nil;
  FContentCount := 0;
  FArea := AArea;
  FDirtyRows := QWord(-1);
  AllocContent(AArea.Area);
  Reset;
end;

constructor TBuffer.CreateFilled(const AArea: TRect; const ACell: TCell;
  const AAllocator: IAllocator);
var
  LIdx, LTotal: Integer;
  LBase: PCell;
begin
  inherited Create;
  FAllocator := AAllocator;
  FContentPtr := nil;
  FContentCount := 0;
  FArea := AArea;
  FDirtyRows := QWord(-1);
  LTotal := AArea.Area;
  AllocContent(LTotal);
  LBase := ContentBase;
  if LBase <> nil then
    for LIdx := 0 to LTotal - 1 do
      LBase[LIdx] := ACell;
end;

destructor TBuffer.Destroy;
begin
  FreeOwnedContent;
  FAllocator := nil;
  inherited Destroy;
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
  Result := ContentLen;
end;

function TBuffer.ContentPtr: PCell;
begin
  Result := ContentBase;
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

procedure TBuffer.NormalizeWideGlyphBoundaries;
var
  LRow, LCol, LWidth, LIndex: Integer;
  LCell, LNext, LPrev: PCell;
begin
  LWidth := FArea.Width;
  if (LWidth <= 0) or (FArea.Height <= 0) then
    Exit;

  for LRow := 0 to FArea.Height - 1 do
  begin
    for LCol := 0 to LWidth - 1 do
    begin
      LIndex := (LRow * LWidth) + LCol;
      LCell := (ContentBase + (LIndex));

      if LCell^.Skip and (LCell^.Width = 0) then
      begin
        if LCol = 0 then
          CellReset(LCell^)
        else
        begin
          LPrev := (ContentBase + (LIndex - 1));
          if (LPrev^.Width <> 2) or LPrev^.Skip then
            CellReset(LCell^);
        end;
      end
      else if (LCell^.Width = 2) and (not LCell^.Skip) then
      begin
        if LCol + 1 >= LWidth then
          CellReset(LCell^)
        else
        begin
          LNext := (ContentBase + (LIndex + 1));
          if (not LNext^.Skip) or (LNext^.Width <> 0) then
            CellReset(LCell^);
        end;
      end;
    end;
  end;
end;

procedure TBuffer.ClearWideOverlapCell(AX, AY: Integer);
var
  LCell, LPeer: PCell;
begin
  LCell := (ContentBase + (IndexOfPos(AX, AY)));

  if LCell^.Skip and (LCell^.Width = 0) then
  begin
    if AX > FArea.X then
    begin
      LPeer := (ContentBase + (IndexOfPos(AX - 1, AY)));
      if (LPeer^.Width = 2) and (not LPeer^.Skip) then
        CellReset(LPeer^);
    end;
  end
  else if (LCell^.Width = 2) and (not LCell^.Skip) then
  begin
    if AX + 1 < FArea.X + FArea.Width then
    begin
      LPeer := (ContentBase + (IndexOfPos(AX + 1, AY)));
      CellReset(LPeer^);
    end;
  end;

  CellReset(LCell^);
end;

procedure TBuffer.PrepareWriteSpan(AX, AY, AWidth: Integer);
var
  LX: Integer;
  LCell: PCell;
begin
  for LX := AX to AX + AWidth - 1 do
  begin
    LCell := (ContentBase + (IndexOfPos(LX, AY)));
    if LCell^.Skip or (LCell^.Width <> 1) then
      ClearWideOverlapCell(LX, AY);
  end;
end;

function TBuffer.CellAt(AX, AY: Integer): PCell;
begin
  if (AX < FArea.X) or (AX >= FArea.X + FArea.Width) or
     (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then
    Exit(nil);
  Result := (ContentBase + (IndexOfPos(AX, AY)));
end;

function TBuffer.SetString(AX, AY: Integer; const AStr: AnsiString;
  const AStyle: TStyle): Integer;
begin
  Result := SetStringN(AX, AY, AStr, MaxInt, AStyle);
end;

function TBuffer.SetStringN(AX, AY: Integer; const AStr: AnsiString;
  AMaxWidth: Integer; const AStyle: TStyle): Integer;
begin
  Result := SetStringP(AX, AY, PAnsiChar(AStr), System.Length(AStr), AMaxWidth, AStyle);
end;

function TBuffer.SetStringP(AX, AY: Integer; AStr: PAnsiChar; ALen, AMaxWidth: Integer;
  const AStyle: TStyle): Integer;
var
  LLeft, LRight, LRemaining, LHidden, LVisibleTail, LI, LCursor, LX: Integer;
  LCP: PCell;
  LByte: Byte;
  LAdv: TGraphemeAdvance;
  LAscii: Boolean;
begin
  Result := 0;
  LLeft := Integer(FArea.X);
  LRight := LLeft + Integer(FArea.Width);

  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  if AX >= LRight then Exit;
  if (AStr = nil) or (ALen <= 0) or (AMaxWidth <= 0) then Exit;

  LCursor := AX;
  LHidden := 0;
  if LCursor < LLeft then
  begin
    LHidden := LLeft - LCursor;
    LCursor := LLeft;
  end;

  MarkRowDirty(AY - FArea.Y);
  LRemaining := LRight - LCursor;
  if LRemaining > AMaxWidth then LRemaining := AMaxWidth;
  if LRemaining <= 0 then Exit;

  LAscii := True;
  for LI := 0 to ALen - 1 do
    if Byte(AStr[LI]) >= $80 then begin LAscii := False; Break; end;

  if LAscii then
  begin
    for LI := 0 to ALen - 1 do
    begin
      LByte := Byte(AStr[LI]);
      if LByte < 32 then Continue;
      if LHidden > 0 then
      begin
        Dec(LHidden);
        Continue;
      end;
      if LRemaining = 0 then Break;
      PrepareWriteSpan(LCursor, AY, 1);
      LCP := (ContentBase + (IndexOfPos(LCursor, AY)));
      CellSetSymbolAscii(LCP^, AnsiChar(LByte));
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
    LAdv := GraphemeAt(AStr^, ALen, LI);
    if LAdv.Width = 0 then begin Inc(LI, LAdv.ByteLen); Continue; end;
    if LHidden > 0 then
    begin
      if LAdv.Width <= LHidden then
      begin
        Dec(LHidden, LAdv.Width);
        Inc(LI, LAdv.ByteLen);
        Continue;
      end;

      LVisibleTail := LAdv.Width - LHidden;
      if LVisibleTail > LRemaining then
        LVisibleTail := LRemaining;
      PrepareWriteSpan(LCursor, AY, LVisibleTail);
      for LX := LCursor to LCursor + LVisibleTail - 1 do
      begin
        LCP := (ContentBase + (IndexOfPos(LX, AY)));
        CellReset(LCP^);
      end;
      Inc(LCursor, LVisibleTail);
      Inc(Result, LVisibleTail);
      Dec(LRemaining, LVisibleTail);
      LHidden := 0;
      Inc(LI, LAdv.ByteLen);
      Continue;
    end;

    if LRemaining = 0 then Break;
    if LAdv.Width > LRemaining then Break;
    PrepareWriteSpan(LCursor, AY, LAdv.Width);
    LCP := (ContentBase + (IndexOfPos(LCursor, AY)));
    CellSetSymbolBytes(LCP^, PByte(AStr)[LI], LAdv.ByteLen, LAdv.Width);
    CellApplyStyle(LCP^, AStyle);
    if LAdv.Width = 2 then
    begin
      LCP := (ContentBase + (IndexOfPos(LCursor + 1, AY)));
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

{ 把 AStr 重复填充 AWidth 列(按字素推进,越界/超宽安全截断)。
  与 SetStringN「写一次截断」互补:画横线/分隔线等重复段,
  热路径零堆分配(常量串复用,逐格直写) }
function TBuffer.FillH(AX, AY: Integer; const AStr: AnsiString; AWidth: Integer;
  const AStyle: TStyle): Integer;
var
  LLeft, LRight, LRemaining, LHidden, LI, LCursor: Integer;
  LCP: PCell;
  LAdv: TGraphemeAdvance;
  LData: PAnsiChar;
begin
  Result := 0;
  LLeft := Integer(FArea.X);
  LRight := LLeft + Integer(FArea.Width);
  if (AY < FArea.Y) or (AY >= FArea.Y + FArea.Height) then Exit;
  if AX >= LRight then Exit;
  if (Length(AStr) = 0) or (AWidth <= 0) then Exit;

  LData := PAnsiChar(AStr);
  LCursor := AX;
  LHidden := 0;
  if LCursor < LLeft then
  begin
    LHidden := LLeft - LCursor;
    LCursor := LLeft;
  end;

  MarkRowDirty(AY - FArea.Y);
  LRemaining := LRight - LCursor;
  if LRemaining > AWidth then LRemaining := AWidth;
  if LRemaining <= 0 then Exit;

  LI := 0;
  while LRemaining > 0 do
  begin
    if LI >= Length(AStr) then LI := 0;   { 串尾回绕重复填充 }
    LAdv := GraphemeAt(LData^, Length(AStr), LI);
    if LAdv.Width = 0 then
    begin
      Inc(LI, LAdv.ByteLen);
      Continue;
    end;
    if LHidden > 0 then
    begin
      if LAdv.Width <= LHidden then
      begin
        Dec(LHidden, LAdv.Width);
        Inc(LI, LAdv.ByteLen);
        Continue;
      end;
      { 字素横跨左裁剪边:丢弃头残段,整字素从可见起点完整写出 }
      LHidden := 0;
    end;
    if LAdv.Width > LRemaining then Break;   { 放不下:整体停止 }
    PrepareWriteSpan(LCursor, AY, LAdv.Width);
    LCP := (ContentBase + (IndexOfPos(LCursor, AY)));
    CellSetSymbolBytes(LCP^, PByte(AStr)[LI], LAdv.ByteLen, LAdv.Width);
    CellApplyStyle(LCP^, AStyle);
    if LAdv.Width = 2 then
    begin
      LCP := (ContentBase + (IndexOfPos(LCursor + 1, AY)));
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
      LCP := (ContentBase + (IndexOfPos(LX, LY)));
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
      PrepareWriteSpan(LX, LY, 1);
      LCP := (ContentBase + (IndexOfPos(LX, LY)));
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
      PrepareWriteSpan(LX, LY, 1);
      LCP := (ContentBase + (IndexOfPos(LX, LY)));
      LCP^ := CELL_EMPTY;
    end;
  end;
end;

procedure TBuffer.Reset;
var
  LI, LTotal: Integer;
  LDirty: TCell;
begin
  LTotal := ContentLen;
  if LTotal = 0 then Exit;
  { 用一个与 CELL_EMPTY 不同的 cell，使 reset 后（如终端 resize）Diff 必产补丁。 }
  LDirty := CELL_EMPTY;
  LDirty.Glyph.Len := 0;  { 正常渲染不可能 → 保证 diff }
  ContentBase[0] := LDirty;
  LI := 1;
  while LI + LI <= LTotal do
  begin
    Move(ContentBase[0], ContentBase[LI], LI * SizeOf(TCell));
    LI := LI + LI;
  end;
  if LI < LTotal then
    Move(ContentBase[0], ContentBase[LI], (LTotal - LI) * SizeOf(TCell));
  FImagePlacementCount := 0;
  FDirtyRows := QWord(-1);
end;

procedure TBuffer.Resize(const ANewArea: TRect);
var
  LOldDyn: array of TCell;
  LOldPtr: PCell;
  LOldArea: TRect;
  LNewBase: PCell;
  LX, LY, LIdx: Integer;
  LSrc: PCell;
begin
  LOldDyn := nil;
  if RectEquals(ANewArea, FArea) then Exit;

  LOldArea := FArea;
  LOldPtr := nil;
  if FAllocator <> nil then
  begin
    LOldPtr := FContentPtr;
    FContentPtr := nil;
    FContentCount := 0;
  end
  else
    LOldDyn := FContent;

  FArea := ANewArea;
  AllocContent(ANewArea.Area);
  LNewBase := ContentBase;
  { 先填充新缓冲。 }
  if LNewBase <> nil then
    for LIdx := 0 to ContentLen - 1 do
      LNewBase[LIdx] := CELL_EMPTY;

  { 从 Old 拷贝重叠区。 }
  for LY := LOldArea.Top to LOldArea.Bottom - 1 do
    for LX := LOldArea.Left to LOldArea.Right - 1 do
    begin
      if (LX < ANewArea.X) or (LX >= ANewArea.X + ANewArea.Width) then Continue;
      if (LY < ANewArea.Y) or (LY >= ANewArea.Y + ANewArea.Height) then Continue;
      if FAllocator <> nil then
      begin
        if LOldPtr = nil then Continue;
        LSrc := LOldPtr + ((LY - LOldArea.Y) * LOldArea.Width + (LX - LOldArea.X));
      end
      else
        LSrc := @LOldDyn[(LY - LOldArea.Y) * LOldArea.Width + (LX - LOldArea.X)];
      LNewBase[(LY - ANewArea.Y) * ANewArea.Width + (LX - ANewArea.X)] := LSrc^;
    end;

  if (FAllocator <> nil) and (LOldPtr <> nil) then
    FAllocator.FreeMem(LOldPtr); { inject path: observe Free via IAllocator }

  NormalizeWideGlyphBoundaries;
  FDirtyRows := QWord(-1);
end;

function BuildFullRedrawDiff(const ANext: TBuffer; var APatches: TDiffEntries): Integer;
var
  LTotal, LI, LOutCount, LW: Integer;
  LPosX, LPosY: Word;
begin
  LTotal := ANext.ContentLen;
  LOutCount := 0;
  LPosX := ANext.FArea.X;
  LPosY := ANext.FArea.Y;
  LW := ANext.FArea.Width;

  for LI := 0 to LTotal - 1 do
  begin
    if not ANext.ContentBase[LI].Skip then
    begin
      APatches[LOutCount].X := LPosX;
      APatches[LOutCount].Y := LPosY;
      APatches[LOutCount].Cell := ANext.ContentBase[LI];
      Inc(LOutCount);
    end;

    Inc(LPosX);
    if LPosX >= ANext.FArea.X + LW then
    begin
      LPosX := ANext.FArea.X;
      Inc(LPosY);
    end;
  end;

  Result := LOutCount;
end;

procedure TBuffer.Diff(const ANext: TBuffer; out APatches: TDiffEntries);
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
  if (ContentLen = 0) or (ANext.ContentLen = 0) then
  begin
    SetLength(APatches, 0);
    Exit;
  end;

  if not RectEquals(ANext.FArea, FArea) then
  begin
    LTotal := ANext.ContentLen;
    SetLength(APatches, LTotal);
    LOutCount := BuildFullRedrawDiff(ANext, APatches);
    SetLength(APatches, LOutCount);
    Exit;
  end;

  LTotal := ContentLen;
  SetLength(APatches, LTotal);
  LOutCount := 0;
  LToSkip := 0;
  LInvalidated := 0;
  LW := FArea.Width;
  LRowBytes := LW * SizeOf(TCell);
  LPrevBase := ContentBase;
  LCurrBase := ANext.ContentBase;

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
  if (ContentLen = 0) or (ANext.ContentLen = 0) then
  begin
    Result := 0;
    Exit;
  end;

  LTotal := ContentLen;
  if not RectEquals(ANext.FArea, FArea) then
    LTotal := ANext.ContentLen;

  if System.Length(APatches) < LTotal then
    SetLength(APatches, LTotal);

  if not RectEquals(ANext.FArea, FArea) then
  begin
    Result := BuildFullRedrawDiff(ANext, APatches);
    Exit;
  end;

  LOutCount := 0;
  LToSkip := 0;
  LInvalidated := 0;
  LW := FArea.Width;
  LRowBytes := LW * SizeOf(TCell);
  LPrevBase := ContentBase;
  LCurrBase := ANext.ContentBase;

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
    LCP := (ContentBase + (LIdx));
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
    LCP := (ContentBase + (LIdx));
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
  FImagePlacements[FImagePlacementCount].SrcX := 0;
  FImagePlacements[FImagePlacementCount].SrcY := 0;
  FImagePlacements[FImagePlacementCount].SrcW := 0;
  FImagePlacements[FImagePlacementCount].SrcH := 0;
  Inc(FImagePlacementCount);
end;

procedure TBuffer.PlaceImageEncoded(AHash: QWord; const AImgArea: TRect;
  ADataPtr: Pointer; ADataLen: Integer; APixelWidth, APixelHeight: Integer;
  ASrcX, ASrcY, ASrcW, ASrcH: Integer);
begin
  PlaceImage(AHash, AImgArea, ADataPtr, ADataLen, APixelWidth, APixelHeight);
  with FImagePlacements[FImagePlacementCount - 1] do
  begin
    Encoded := True;
    SrcX := ASrcX;
    SrcY := ASrcY;
    SrcW := ASrcW;
    SrcH := ASrcH;
  end;
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
