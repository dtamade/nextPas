{**
 * nextpas.core.tui.canvas.floodfill - 4-连通区域种子填充
 *
 * CanvasFloodFill4: 种子色取自文档当前格, 同色连通区域逐格替换为 AFill,
 * 每格经 TCanvasEditBuilder 记录增量, 可直接入撤销栈。
 * CanvasFloodFillScan4: 只读扫描同一连通区域, 不修改文档, 逐点回调输出
 * (供悬停预览等只读消费方复用, 与填充同一路径语义)。
 * 显式栈代替递归防爆栈; 格数上限 100000, 超限提前终止返回已处理数。
 *}

unit nextpas.core.tui.canvas.floodfill;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base,
  nextpas.core.tui.canvas.edit,
  nextpas.core.tui.canvas.raster;

const
  {** @desc 单次填充的最大格数(达到即截断, 结果不完整)。
      接口区导出供调用方辨识截断态(如 UI 提示"已达上限") *}
  FLOOD_FILL_LIMIT = 100000;

{** @desc 从 (AX,AY) 起把同色区域替换为 AFill, 经 builder 记录增量
    @return 填充格数; 种子越界、图层非法或种子与 AFill 同色返回 0(无变化) *}
function CanvasFloodFill4(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const AFill: TCanvasCell; ABuilder: TCanvasEditBuilder): Integer;

{** @desc 同上, 但填充限制在边界矩形 [ABX0..ABX1]x[ABY0..ABY1] 内
    (含端点; 选区限定填充等场景)。种子在边界外返回 0。
    边界自动与文档矩形求交。 *}
function CanvasFloodFill4In(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const AFill: TCanvasCell; ABuilder: TCanvasEditBuilder;
  ABX0, ABY0, ABX1, ABY1: Integer): Integer;

{** @desc 只读扫描 (AX,AY) 的同色连通区域, 不修改文档, 逐点回调 OnPoint
    @return 区域格数; 种子越界、图层非法或回调未设置返回 0 *}
function CanvasFloodFillScan4(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const OnPoint: TRasterPointProc): Integer;

{** @desc 同上, 但扫描限制在边界矩形内(选区限定预览等场景) *}
function CanvasFloodFillScan4In(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const OnPoint: TRasterPointProc;
  ABX0, ABY0, ABX1, ABY1: Integer): Integer;

implementation

type
  { 待处理格栈节点 }
  TFloodNode = packed record
    X, Y: Integer;
  end;

const
  FLOOD_STACK_INIT = 4096;

function CanvasFloodFill4(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const AFill: TCanvasCell; ABuilder: TCanvasEditBuilder): Integer;
begin
  Result := CanvasFloodFill4In(ADoc, ALayer, AX, AY, AFill, ABuilder,
    0, 0, ADoc.Width - 1, ADoc.Height - 1);
end;

function CanvasFloodFill4In(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const AFill: TCanvasCell; ABuilder: TCanvasEditBuilder;
  ABX0, ABY0, ABX1, ABY1: Integer): Integer;
var
  Stack: array of TFloodNode;
  SP: Integer;                 { 栈元素数 }
  BX0, BY0, BX1, BY1: Integer; { 与文档求交后的有效边界 }
  Seed: TCanvasCell;
  Node: TFloodNode;
  X, Y: Integer;
begin
  Result := 0;
  if (ADoc = nil) or (ABuilder = nil) then
    Exit;
  if (ALayer < 0) or (ALayer >= ADoc.LayerCount) then
    Exit;
  { 边界与文档矩形求交; 空交集即无填充 }
  if ABX0 < 0 then BX0 := 0 else BX0 := ABX0;
  if ABY0 < 0 then BY0 := 0 else BY0 := ABY0;
  if ABX1 > ADoc.Width - 1 then BX1 := ADoc.Width - 1 else BX1 := ABX1;
  if ABY1 > ADoc.Height - 1 then BY1 := ADoc.Height - 1 else BY1 := ABY1;
  if (BX0 > BX1) or (BY0 > BY1) then
    Exit;
  { 种子必须在边界内(选区外点击不填) }
  if (AX < BX0) or (AX > BX1) or (AY < BY0) or (AY > BY1) then
    Exit;
  Seed := ADoc.GetCell(ALayer, AX, AY);
  { 种子与填充色相同则无变化 }
  if CanvasCellEquals(Seed, AFill) then
    Exit;

  SetLength(Stack, FLOOD_STACK_INIT);
  SP := 0;
  Stack[SP].X := AX;
  Stack[SP].Y := AY;
  Inc(SP);

  while (SP > 0) and (Result < FLOOD_FILL_LIMIT) do
  begin
    Dec(SP);
    Node := Stack[SP];
    X := Node.X;
    Y := Node.Y;
    { 已被新色覆盖的重复入栈格直接跳过; 越界格只在入栈时裁掉 }
    if not CanvasCellEquals(ADoc.GetCell(ALayer, X, Y), Seed) then
      Continue;
    ABuilder.SetPixel(X, Y, AFill);
    Inc(Result);
    if SP + 4 > Length(Stack) then
      SetLength(Stack, Length(Stack) * 2);
    { 右 }
    if X + 1 <= BX1 then
    begin
      Stack[SP].X := X + 1;
      Stack[SP].Y := Y;
      Inc(SP);
    end;
    { 左 }
    if X - 1 >= BX0 then
    begin
      Stack[SP].X := X - 1;
      Stack[SP].Y := Y;
      Inc(SP);
    end;
    { 下 }
    if Y + 1 <= BY1 then
    begin
      Stack[SP].X := X;
      Stack[SP].Y := Y + 1;
      Inc(SP);
    end;
    { 上 }
    if Y - 1 >= BY0 then
    begin
      Stack[SP].X := X;
      Stack[SP].Y := Y - 1;
      Inc(SP);
    end;
  end;
end;

{ 只读扫描: 与 CanvasFloodFill4 同一区域语义(种子色/4 连通/上限),
  不修改文档——以 Visited 数组代替"写入变色"的去重职责,
  否则同格会被邻居反复入栈造成循环。 }
function CanvasFloodFillScan4(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const OnPoint: TRasterPointProc): Integer;
begin
  Result := CanvasFloodFillScan4In(ADoc, ALayer, AX, AY, OnPoint,
    0, 0, ADoc.Width - 1, ADoc.Height - 1);
end;

function CanvasFloodFillScan4In(ADoc: TCanvasDoc; ALayer, AX, AY: Integer;
  const OnPoint: TRasterPointProc;
  ABX0, ABY0, ABX1, ABY1: Integer): Integer;
var
  Stack: array of TFloodNode;
  Visited: array of Boolean;
  SP: Integer;                 { 栈元素数 }
  BX0, BY0, BX1, BY1: Integer; { 与文档求交后的有效边界 }
  Seed: TCanvasCell;
  Node: TFloodNode;
  X, Y: Integer;
begin
  Result := 0;
  if (ADoc = nil) or (not Assigned(OnPoint)) then
    Exit;
  if (ALayer < 0) or (ALayer >= ADoc.LayerCount) then
    Exit;
  { 边界与文档矩形求交; 空交集即无扫描 }
  if ABX0 < 0 then BX0 := 0 else BX0 := ABX0;
  if ABY0 < 0 then BY0 := 0 else BY0 := ABY0;
  if ABX1 > ADoc.Width - 1 then BX1 := ADoc.Width - 1 else BX1 := ABX1;
  if ABY1 > ADoc.Height - 1 then BY1 := ADoc.Height - 1 else BY1 := ABY1;
  if (BX0 > BX1) or (BY0 > BY1) then
    Exit;
  { 种子必须在边界内 }
  if (AX < BX0) or (AX > BX1) or (AY < BY0) or (AY > BY1) then
    Exit;
  Seed := ADoc.GetCell(ALayer, AX, AY);

  SetLength(Stack, FLOOD_STACK_INIT);
  SetLength(Visited, ADoc.Width * ADoc.Height);
  FillChar(Visited[0], Length(Visited), 0);
  SP := 0;
  Stack[SP].X := AX;
  Stack[SP].Y := AY;
  Inc(SP);

  while (SP > 0) and (Result < FLOOD_FILL_LIMIT) do
  begin
    Dec(SP);
    Node := Stack[SP];
    X := Node.X;
    Y := Node.Y;
    if Visited[Y * ADoc.Width + X] then
      Continue;
    if not CanvasCellEquals(ADoc.GetCell(ALayer, X, Y), Seed) then
      Continue;
    Visited[Y * ADoc.Width + X] := True;
    OnPoint(X, Y);
    Inc(Result);
    if SP + 4 > Length(Stack) then
      SetLength(Stack, Length(Stack) * 2);
    { 右 }
    if X + 1 <= BX1 then
    begin
      Stack[SP].X := X + 1;
      Stack[SP].Y := Y;
      Inc(SP);
    end;
    { 左 }
    if X - 1 >= BX0 then
    begin
      Stack[SP].X := X - 1;
      Stack[SP].Y := Y;
      Inc(SP);
    end;
    { 下 }
    if Y + 1 <= BY1 then
    begin
      Stack[SP].X := X;
      Stack[SP].Y := Y + 1;
      Inc(SP);
    end;
    { 上 }
    if Y - 1 >= BY0 then
    begin
      Stack[SP].X := X;
      Stack[SP].Y := Y - 1;
      Inc(SP);
    end;
  end;
end;

end.
