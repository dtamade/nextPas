unit nextpas.core.tui.canvas.edit;

{**
 * @desc 画布增量编辑与撤销/重做。
 *
 * TCanvasEditBuilder 写入文档的同时收集变更格（old→new），构成
 * TCanvasEditOp。撤销 = 逆序写 old；重做 = 正序写 new。允许同一格多次
 * 变更（逆序应用天然正确）。
 *
 * TCanvasUndoLog 维护双栈（undo/redo），默认上限 500 步，超出丢最旧。
 * TCanvasDelta / TCanvasEditOp 均含托管数组语义（TCanvasEditOp.Deltas），
 * 栈内元素搬运必须逐元素赋值（引用计数安全），禁止 Move 字节拷贝。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.canvas.base;

type
  TCanvasDelta = packed record
    X, Y: Integer;
    Old, New: TCanvasCell;
  end;

  TCanvasEditOp = record
    Layer: Integer;
    Deltas: array of TCanvasDelta;
    function Count: Integer;
  end;

  TCanvasUndoLog = class
  private
    FUndo: array of TCanvasEditOp;
    FRedo: array of TCanvasEditOp;
    FMaxSteps: Integer;
  public
    constructor Create(AMaxSteps: Integer = 500);
    { 压入新操作；清空 redo；超出上限丢最旧。 }
    procedure Push(const Op: TCanvasEditOp);
    function CanUndo: Boolean;
    function CanRedo: Boolean;
    { 弹出 undo → 移入 redo，返回操作（调用方 CanvasApplyOpInverse 到文档）。 }
    function Undo: TCanvasEditOp;
    function Redo: TCanvasEditOp;
    procedure Clear;
    function UndoCount: Integer;
    function RedoCount: Integer;
  end;

  { 收集增量。SetPixel 时旧值未变则忽略（不产生空增量）。 }
  TCanvasEditBuilder = class
  private
    FDoc: TCanvasDoc;
    FLayer: Integer;
    FDeltas: array of TCanvasDelta;
    FCount: Integer;
    procedure Grow;
  public
    constructor Create(ADoc: TCanvasDoc; ALayer: Integer);
    { 越界忽略；与旧值相同忽略。 }
    procedure SetPixel(AX, AY: Integer; const ACell: TCanvasCell);
    procedure Clear;
    function Count: Integer;
    function Empty: Boolean;
    function ToOp: TCanvasEditOp;
  end;

{ 应用到文档：写 New（正序）。 }
procedure CanvasApplyOp(ADoc: TCanvasDoc; const Op: TCanvasEditOp);
{ 逆应用到文档：写 Old（逆序）。 }
procedure CanvasApplyOpInverse(ADoc: TCanvasDoc; const Op: TCanvasEditOp);

implementation

{ TCanvasEditOp }

function TCanvasEditOp.Count: Integer;
begin
  Result := Length(Deltas);
end;

{ TCanvasUndoLog }

constructor TCanvasUndoLog.Create(AMaxSteps: Integer);
begin
  inherited Create;
  if AMaxSteps < 1 then
    AMaxSteps := 1;
  FMaxSteps := AMaxSteps;
end;

procedure TCanvasUndoLog.Push(const Op: TCanvasEditOp);
var
  I: Integer;
begin
  if Op.Count = 0 then
    Exit;
  SetLength(FRedo, 0);
  SetLength(FUndo, Length(FUndo) + 1);
  FUndo[High(FUndo)] := Op;
  if Length(FUndo) > FMaxSteps then
  begin
    { 丢最旧。逐元素赋值而非 Move：TCanvasEditOp 含托管数组，
      字节拷贝会破坏引用计数。 }
    for I := 0 to High(FUndo) - 1 do
      FUndo[I] := FUndo[I + 1];
    SetLength(FUndo, Length(FUndo) - 1);
  end;
end;

function TCanvasUndoLog.CanUndo: Boolean;
begin
  Result := Length(FUndo) > 0;
end;

function TCanvasUndoLog.CanRedo: Boolean;
begin
  Result := Length(FRedo) > 0;
end;

function TCanvasUndoLog.Undo: TCanvasEditOp;
begin
  Result := Default(TCanvasEditOp);
  if Length(FUndo) = 0 then
    Exit;
  Result := FUndo[High(FUndo)];
  SetLength(FUndo, Length(FUndo) - 1);
  SetLength(FRedo, Length(FRedo) + 1);
  FRedo[High(FRedo)] := Result;
end;

function TCanvasUndoLog.Redo: TCanvasEditOp;
begin
  Result := Default(TCanvasEditOp);
  if Length(FRedo) = 0 then
    Exit;
  Result := FRedo[High(FRedo)];
  SetLength(FRedo, Length(FRedo) - 1);
  SetLength(FUndo, Length(FUndo) + 1);
  FUndo[High(FUndo)] := Result;
end;

procedure TCanvasUndoLog.Clear;
begin
  SetLength(FUndo, 0);
  SetLength(FRedo, 0);
end;

function TCanvasUndoLog.UndoCount: Integer;
begin
  Result := Length(FUndo);
end;

function TCanvasUndoLog.RedoCount: Integer;
begin
  Result := Length(FRedo);
end;

{ TCanvasEditBuilder }

constructor TCanvasEditBuilder.Create(ADoc: TCanvasDoc; ALayer: Integer);
begin
  inherited Create;
  FDoc := ADoc;
  FLayer := ALayer;
  FCount := 0;
end;

procedure TCanvasEditBuilder.Grow;
var
  N: Integer;
begin
  if FCount >= Length(FDeltas) then
  begin
    if Length(FDeltas) = 0 then
      N := 64
    else
      N := Length(FDeltas) * 2;
    SetLength(FDeltas, N);
  end;
end;

procedure TCanvasEditBuilder.SetPixel(AX, AY: Integer; const ACell: TCanvasCell);
var
  Old: TCanvasCell;
begin
  if (AX < 0) or (AY < 0) or (AX >= FDoc.Width) or (AY >= FDoc.Height) then
    Exit;
  Old := FDoc.GetCell(FLayer, AX, AY);
  if CanvasCellEquals(Old, ACell) then
    Exit;
  Grow;
  FDeltas[FCount].X := AX;
  FDeltas[FCount].Y := AY;
  FDeltas[FCount].Old := Old;
  FDeltas[FCount].New := ACell;
  Inc(FCount);
  FDoc.SetCell(FLayer, AX, AY, ACell);
end;

procedure TCanvasEditBuilder.Clear;
begin
  FCount := 0;
end;

function TCanvasEditBuilder.Count: Integer;
begin
  Result := FCount;
end;

function TCanvasEditBuilder.Empty: Boolean;
begin
  Result := FCount = 0;
end;

function TCanvasEditBuilder.ToOp: TCanvasEditOp;
begin
  Result.Layer := FLayer;
  SetLength(Result.Deltas, FCount);
  { TCanvasDelta 是纯值记录（无托管字段），Move 合法。 }
  if FCount > 0 then
    Move(FDeltas[0], Result.Deltas[0], FCount * SizeOf(TCanvasDelta));
end;

{ 顶层应用函数 }

procedure CanvasApplyOp(ADoc: TCanvasDoc; const Op: TCanvasEditOp);
var
  I: Integer;
begin
  for I := 0 to High(Op.Deltas) do
    ADoc.SetCell(Op.Layer, Op.Deltas[I].X, Op.Deltas[I].Y, Op.Deltas[I].New);
end;

procedure CanvasApplyOpInverse(ADoc: TCanvasDoc; const Op: TCanvasEditOp);
var
  I: Integer;
begin
  for I := High(Op.Deltas) downto 0 do
    ADoc.SetCell(Op.Layer, Op.Deltas[I].X, Op.Deltas[I].Y, Op.Deltas[I].Old);
end;

end.