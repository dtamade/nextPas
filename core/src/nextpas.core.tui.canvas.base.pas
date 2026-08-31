unit nextpas.core.tui.canvas.base;

{**
 * @desc 字符像素画布文档模型。
 *
 * 每个终端格 = 一个像素（TCanvasCell：字形码点 + 前景色 + 背景色）。
 * 多层文档：层数 1..CANVAS_MAX_LAYERS，索引 0 = 底层（先绘制）。
 * 所有写路径自动累积脏矩形，供视图按行增量重绘。
 *
 * 语义约定：
 *   - Ch = 0 表示"未画"格，渲染时输出无样式空格；
 *   - Ch = 32（空格）表示显式绘制的背景色空格（覆盖下层）。
 *
 * 内存布局：TCanvasCell 为 12 字节纯值记录（4 字节 Ch + 两个 4 字节 TColor），
 * 不含托管字段，因此整块 FillChar 清零即得 CANVAS_CELL_EMPTY，也可整体 Move。
 * 该布局由编译期断言保护（SizeOf(TColor) = 4，见 nextpas.core.tui.color）。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

uses
  nextpas.core.tui.color;

type
  TCanvasCell = packed record
    Ch: LongWord;
    Fg, Bg: TColor;
  end;

  PCanvasCell = ^TCanvasCell;

  TCanvasLayer = record
    Name: AnsiString;
    Visible: Boolean;
    Cells: array of TCanvasCell;
  end;

  TCanvasDoc = class
  private
    FWidth: Integer;
    FHeight: Integer;
    FLayers: array of TCanvasLayer;
    FActive: Integer;
    FDirtyX0, FDirtyY0, FDirtyX1, FDirtyY1: Integer;
    FDirtyValid: Boolean;
    function LayerBase(ALayer: Integer): PCanvasCell;
  public
    constructor Create(AWidth, AHeight: Integer);
    destructor Destroy; override;

    property Width: Integer read FWidth;
    property Height: Integer read FHeight;

    function LayerCount: Integer;
    procedure SetActive(AIndex: Integer);
    property ActiveIndex: Integer read FActive write SetActive;

    function LayerName(AIndex: Integer): AnsiString;
    procedure SetLayerName(AIndex: Integer; const AName: AnsiString);
    function LayerVisible(AIndex: Integer): Boolean;
    procedure SetLayerVisible(AIndex: Integer; AVisible: Boolean);
    procedure ToggleLayerVisible(AIndex: Integer);

    { 追加新层到最上层（索引末尾）；返回新层索引，成功时置为新活动层。
      层数达到上限返回 -1；清撤销栈由调用方负责。 }
    function NewLayer(const AName: AnsiString): Integer;
    { 删除层。仅剩 1 层时返回 False（拒绝）。索引其后各层前移。 }
    function DeleteLayer(AIndex: Integer): Boolean;
    { 重排层：把 AIndex 层沿索引方向移动 ADelta 格（越界截断）。
      返回移动后的新索引；无法移动（索引非法/ADelta=0/已到边界）返回 -1。
      活动层跟随其内容移动，保持活动内容不变。 }
    function MoveLayer(AIndex, ADelta: Integer): Integer;
    procedure ClearLayer(AIndex: Integer);
    procedure ClearAll;
    { 保留左上重叠区，新区域填 CANVAS_CELL_EMPTY；全量置脏。 }
    procedure Resize(ANewW, ANewH: Integer);

    { 越界/非法层 → CANVAS_CELL_EMPTY / nil。热路径用 CellPtr/RowPtr。 }
    function GetCell(ALayer, AX, AY: Integer): TCanvasCell;
    function CellPtr(ALayer, AX, AY: Integer): PCanvasCell;
    function RowPtr(ALayer, AY: Integer): PCanvasCell;
    procedure SetCell(ALayer, AX, AY: Integer; const ACell: TCanvasCell);

    { 脏矩形：写路径自动累积；视图每帧消费一次。区间闭合。 }
    procedure MarkDirtyRect(AX0, AY0, AX1, AY1: Integer);
    procedure MarkAllDirty;
    function IsDirty: Boolean;
    function ConsumeDirtyRect(out AX0, AY0, AX1, AY1: Integer): Boolean;
    procedure ClearDirty;
  end;

const
  CANVAS_CELL_EMPTY: TCanvasCell = (
    Ch: 0;
    Fg: (Kind: ckUnset; Index: 0);
    Bg: (Kind: ckUnset; Index: 0));

  CANVAS_MAX_LAYERS = 32;

  { 新建文档首个图层的默认名（core 保持语言中立，调用方可自行改名）。 }
  CANVAS_DEFAULT_LAYER_NAME: AnsiString = 'Layer 1';

function CanvasCellEquals(const A, B: TCanvasCell): Boolean;
function CanvasMakeCell(ACh: LongWord; const AFg, ABg: TColor): TCanvasCell;

implementation

function CanvasCellEquals(const A, B: TCanvasCell): Boolean;
begin
  Result := (A.Ch = B.Ch)
    and ColorEquals(A.Fg, B.Fg)
    and ColorEquals(A.Bg, B.Bg);
end;

function CanvasMakeCell(ACh: LongWord; const AFg, ABg: TColor): TCanvasCell;
begin
  Result.Ch := ACh;
  Result.Fg := AFg;
  Result.Bg := ABg;
end;

{ TCanvasDoc }

constructor TCanvasDoc.Create(AWidth, AHeight: Integer);
begin
  inherited Create;
  if AWidth < 1 then AWidth := 1;
  if AHeight < 1 then AHeight := 1;
  FWidth := AWidth;
  FHeight := AHeight;
  FActive := 0;
  FDirtyValid := False;
  SetLength(FLayers, 1);
  FLayers[0].Name := CANVAS_DEFAULT_LAYER_NAME;
  FLayers[0].Visible := True;
  SetLength(FLayers[0].Cells, FWidth * FHeight);
  FillChar(FLayers[0].Cells[0], Length(FLayers[0].Cells) * SizeOf(TCanvasCell), 0);
  MarkAllDirty;
end;

destructor TCanvasDoc.Destroy;
begin
  inherited Destroy;
end;

function TCanvasDoc.LayerCount: Integer;
begin
  Result := Length(FLayers);
end;

function TCanvasDoc.LayerBase(ALayer: Integer): PCanvasCell;
begin
  if (ALayer >= 0) and (ALayer < Length(FLayers)) and (Length(FLayers[ALayer].Cells) > 0) then
    Result := @FLayers[ALayer].Cells[0]
  else
    Result := nil;
end;

procedure TCanvasDoc.SetActive(AIndex: Integer);
begin
  if (AIndex >= 0) and (AIndex < Length(FLayers)) then
    FActive := AIndex;
end;

function TCanvasDoc.LayerName(AIndex: Integer): AnsiString;
begin
  if (AIndex >= 0) and (AIndex < Length(FLayers)) then
    Result := FLayers[AIndex].Name
  else
    Result := '';
end;

procedure TCanvasDoc.SetLayerName(AIndex: Integer; const AName: AnsiString);
begin
  if (AIndex >= 0) and (AIndex < Length(FLayers)) then
    FLayers[AIndex].Name := AName;
end;

function TCanvasDoc.LayerVisible(AIndex: Integer): Boolean;
begin
  if (AIndex >= 0) and (AIndex < Length(FLayers)) then
    Result := FLayers[AIndex].Visible
  else
    Result := False;
end;

procedure TCanvasDoc.SetLayerVisible(AIndex: Integer; AVisible: Boolean);
begin
  if (AIndex >= 0) and (AIndex < Length(FLayers)) then
  begin
    FLayers[AIndex].Visible := AVisible;
    MarkAllDirty;
  end;
end;

procedure TCanvasDoc.ToggleLayerVisible(AIndex: Integer);
begin
  SetLayerVisible(AIndex, not LayerVisible(AIndex));
end;

function TCanvasDoc.NewLayer(const AName: AnsiString): Integer;
begin
  if Length(FLayers) >= CANVAS_MAX_LAYERS then
    Exit(-1);
  SetLength(FLayers, Length(FLayers) + 1);
  FLayers[High(FLayers)].Name := AName;
  FLayers[High(FLayers)].Visible := True;
  SetLength(FLayers[High(FLayers)].Cells, FWidth * FHeight);
  FillChar(FLayers[High(FLayers)].Cells[0],
    Length(FLayers[High(FLayers)].Cells) * SizeOf(TCanvasCell), 0);
  Result := High(FLayers);
  FActive := Result;
  MarkAllDirty;
end;

function TCanvasDoc.DeleteLayer(AIndex: Integer): Boolean;
var
  I: Integer;
begin
  if (AIndex < 0) or (AIndex >= Length(FLayers)) or (Length(FLayers) <= 1) then
    Exit(False);
  for I := AIndex to High(FLayers) - 1 do
    FLayers[I] := FLayers[I + 1];
  SetLength(FLayers, Length(FLayers) - 1);
  if FActive >= Length(FLayers) then
    FActive := Length(FLayers) - 1;
  MarkAllDirty;
  Result := True;
end;

function TCanvasDoc.MoveLayer(AIndex, ADelta: Integer): Integer;
var
  Target, Step, Nxt: Integer;
  Tmp: TCanvasLayer;
begin
  if (AIndex < 0) or (AIndex >= Length(FLayers)) or (ADelta = 0) then
    Exit(-1);
  Target := AIndex + ADelta;
  if Target < 0 then
    Target := 0;
  if Target > High(FLayers) then
    Target := High(FLayers);
  if Target = AIndex then
    Exit(-1);
  { 相邻交换到目标位；记录数组整体换位（动态数组按引用换）。
    活动层若被交换波及则跟随内容，保证活动内容不漂移。 }
  if ADelta > 0 then
    Step := 1
  else
    Step := -1;
  while AIndex <> Target do
  begin
    Nxt := AIndex + Step;
    Tmp := FLayers[AIndex];
    FLayers[AIndex] := FLayers[Nxt];
    FLayers[Nxt] := Tmp;
    if FActive = AIndex then
      FActive := Nxt
    else if FActive = Nxt then
      FActive := AIndex;
    AIndex := Nxt;
  end;
  MarkAllDirty;
  Result := Target;
end;

procedure TCanvasDoc.ClearLayer(AIndex: Integer);
begin
  if (AIndex < 0) or (AIndex >= Length(FLayers)) then
    Exit;
  FillChar(FLayers[AIndex].Cells[0], Length(FLayers[AIndex].Cells) * SizeOf(TCanvasCell), 0);
  MarkAllDirty;
end;

procedure TCanvasDoc.ClearAll;
var
  I: Integer;
begin
  for I := 0 to High(FLayers) do
    FillChar(FLayers[I].Cells[0], Length(FLayers[I].Cells) * SizeOf(TCanvasCell), 0);
  MarkAllDirty;
end;

procedure TCanvasDoc.Resize(ANewW, ANewH: Integer);
var
  I, X, Y: Integer;
  LNewCells: array of TCanvasCell;
begin
  { FPC 同长 SetLength 在数组仍被共享引用时切出新数组（实测），
    各层因此互不别名；此语义由多层 Resize 测试守护。 }
  if ANewW < 1 then ANewW := 1;
  if ANewH < 1 then ANewH := 1;
  if (ANewW = FWidth) and (ANewH = FHeight) then
    Exit;
  for I := 0 to High(FLayers) do
  begin
    { 每层独立分配，避免各层共享同一数组（别名化） }
    SetLength(LNewCells, ANewW * ANewH);
    FillChar(LNewCells[0], Length(LNewCells) * SizeOf(TCanvasCell), 0);
    for Y := 0 to FHeight - 1 do
    begin
      if Y >= ANewH then
        Break;
      for X := 0 to FWidth - 1 do
      begin
        if X >= ANewW then
          Break;
        LNewCells[Y * ANewW + X] := FLayers[I].Cells[Y * FWidth + X];
      end;
    end;
    FLayers[I].Cells := LNewCells;
  end;
  FWidth := ANewW;
  FHeight := ANewH;
  MarkAllDirty;
end;

function TCanvasDoc.GetCell(ALayer, AX, AY: Integer): TCanvasCell;
var
  P: PCanvasCell;
begin
  P := CellPtr(ALayer, AX, AY);
  if P <> nil then
    Result := P^
  else
    Result := CANVAS_CELL_EMPTY;
end;

function TCanvasDoc.CellPtr(ALayer, AX, AY: Integer): PCanvasCell;
begin
  if (AX < 0) or (AY < 0) or (AX >= FWidth) or (AY >= FHeight) then
    Exit(nil);
  Result := LayerBase(ALayer);
  if Result = nil then
    Exit(nil);
  Inc(Result, AY * FWidth + AX);
end;

function TCanvasDoc.RowPtr(ALayer, AY: Integer): PCanvasCell;
begin
  if (AY < 0) or (AY >= FHeight) then
    Exit(nil);
  Result := LayerBase(ALayer);
  if Result = nil then
    Exit(nil);
  Inc(Result, AY * FWidth);
end;

procedure TCanvasDoc.SetCell(ALayer, AX, AY: Integer; const ACell: TCanvasCell);
var
  P: PCanvasCell;
begin
  P := CellPtr(ALayer, AX, AY);
  if P = nil then
    Exit;
  P^ := ACell;
  MarkDirtyRect(AX, AY, AX, AY);
end;

procedure TCanvasDoc.MarkDirtyRect(AX0, AY0, AX1, AY1: Integer);
begin
  if AX1 < AX0 then
    AX1 := AX0;
  if AY1 < AY0 then
    AY1 := AY0;
  if FDirtyValid then
  begin
    if AX0 < FDirtyX0 then FDirtyX0 := AX0;
    if AY0 < FDirtyY0 then FDirtyY0 := AY0;
    if AX1 > FDirtyX1 then FDirtyX1 := AX1;
    if AY1 > FDirtyY1 then FDirtyY1 := AY1;
  end
  else
  begin
    FDirtyX0 := AX0; FDirtyY0 := AY0;
    FDirtyX1 := AX1; FDirtyY1 := AY1;
    FDirtyValid := True;
  end;
end;

procedure TCanvasDoc.MarkAllDirty;
begin
  MarkDirtyRect(0, 0, FWidth - 1, FHeight - 1);
end;

function TCanvasDoc.IsDirty: Boolean;
begin
  Result := FDirtyValid;
end;

function TCanvasDoc.ConsumeDirtyRect(out AX0, AY0, AX1, AY1: Integer): Boolean;
begin
  Result := FDirtyValid;
  if Result then
  begin
    AX0 := FDirtyX0; AY0 := FDirtyY0;
    AX1 := FDirtyX1; AY1 := FDirtyY1;
    FDirtyValid := False;
  end;
end;

procedure TCanvasDoc.ClearDirty;
begin
  FDirtyValid := False;
end;

end.