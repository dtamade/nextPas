unit nextpas.core.tui.base;

{**
 * @desc TUI 几何基础类型（Rect / Position / Size / Margin / Direction）。
 *
 * 全部为 packed record，值语义，按值传递低开销，永不分配。Word(u16) 字段
 * 与终端坐标系一致——终端尺寸实际不超过 u16，匹配该宽度可避免在屏幕边缘
 * 求交时发生有符号溢出。
 *
 * 移植自 fafafa.tui 的 ftui_rect，对齐 ratatui::layout 的
 * Rect / Position / Size / Margin。
 *}

{$I nextpas.core.settings.inc}

interface

type
  { 布局方向 }
  TDirection = (dirHorizontal, dirVertical);

  { 二维坐标点 }
  TPosition = packed record
    X, Y: Word;
  end;

  { 尺寸 }
  TSize = packed record
    Width, Height: Word;
  end;

  { 边距（水平/垂直对称） }
  TMargin = packed record
    Horizontal, Vertical: Word;
  end;

  { 矩形区域。X/Y 为左上角，Width/Height 为尺寸。 }
  TRect = packed record
    X, Y, Width, Height: Word;

    class function Make(const AX, AY, AWidth, AHeight: Word): TRect; static; inline;

    function Area: LongWord; inline;
    function Left: Word; inline;
    function Right: Word; inline;          { 右边界（不含）：X + Width }
    function Top: Word; inline;
    function Bottom: Word; inline;         { 下边界（不含）：Y + Height }

    function IsEmpty: Boolean; inline;
    function Contains(const APos: TPosition): Boolean; inline;
    function Intersects(const AOther: TRect): Boolean;
    function Intersection(const AOther: TRect): TRect;
    function Union(const AOther: TRect): TRect;
    function Inner(const AMargin: TMargin): TRect;
  end;

function PositionMake(const AX, AY: Word): TPosition; inline;
function SizeMake(const AWidth, AHeight: Word): TSize; inline;
function MarginMake(const AHorizontal, AVertical: Word): TMargin; inline;

function RectEquals(const A, B: TRect): Boolean; inline;
function PositionEquals(const A, B: TPosition): Boolean; inline;

implementation

function PositionMake(const AX, AY: Word): TPosition;
begin
  Result.X := AX;
  Result.Y := AY;
end;

function SizeMake(const AWidth, AHeight: Word): TSize;
begin
  Result.Width := AWidth;
  Result.Height := AHeight;
end;

function MarginMake(const AHorizontal, AVertical: Word): TMargin;
begin
  Result.Horizontal := AHorizontal;
  Result.Vertical := AVertical;
end;

function PositionEquals(const A, B: TPosition): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y);
end;

function RectEquals(const A, B: TRect): Boolean;
begin
  Result := (A.X = B.X) and (A.Y = B.Y) and
            (A.Width = B.Width) and (A.Height = B.Height);
end;

{ TRect }

class function TRect.Make(const AX, AY, AWidth, AHeight: Word): TRect;
begin
  Result.X := AX;
  Result.Y := AY;
  Result.Width := AWidth;
  Result.Height := AHeight;
end;

function TRect.Area: LongWord;
begin
  Result := LongWord(Width) * LongWord(Height);
end;

function TRect.Left: Word;
begin
  Result := X;
end;

function TRect.Right: Word;
begin
  Result := X + Width;
end;

function TRect.Top: Word;
begin
  Result := Y;
end;

function TRect.Bottom: Word;
begin
  Result := Y + Height;
end;

function TRect.IsEmpty: Boolean;
begin
  Result := (Width = 0) or (Height = 0);
end;

function TRect.Contains(const APos: TPosition): Boolean;
begin
  Result := (APos.X >= X) and (APos.X < Right) and
            (APos.Y >= Y) and (APos.Y < Bottom);
end;

function TRect.Intersects(const AOther: TRect): Boolean;
begin
  Result := (X < AOther.Right) and (Right > AOther.X) and
            (Y < AOther.Bottom) and (Bottom > AOther.Y);
end;

function TRect.Intersection(const AOther: TRect): TRect;
var
  LLeft, LRight, LTop, LBottom: Integer;
begin
  if not Intersects(AOther) then
  begin
    Result := TRect.Make(0, 0, 0, 0);
    Exit;
  end;
  LLeft := X; if AOther.X > LLeft then LLeft := AOther.X;
  LTop := Y; if AOther.Y > LTop then LTop := AOther.Y;
  LRight := Right; if AOther.Right < LRight then LRight := AOther.Right;
  LBottom := Bottom; if AOther.Bottom < LBottom then LBottom := AOther.Bottom;
  Result := TRect.Make(LLeft, LTop, LRight - LLeft, LBottom - LTop);
end;

function TRect.Union(const AOther: TRect): TRect;
var
  LLeft, LRight, LTop, LBottom: Integer;
begin
  if Self.IsEmpty then
  begin
    Result := AOther;
    Exit;
  end;
  if AOther.IsEmpty then
  begin
    Result := Self;
    Exit;
  end;
  LLeft := X; if AOther.X < LLeft then LLeft := AOther.X;
  LTop := Y; if AOther.Y < LTop then LTop := AOther.Y;
  LRight := Right; if AOther.Right > LRight then LRight := AOther.Right;
  LBottom := Bottom; if AOther.Bottom > LBottom then LBottom := AOther.Bottom;
  Result := TRect.Make(LLeft, LTop, LRight - LLeft, LBottom - LTop);
end;

function TRect.Inner(const AMargin: TMargin): TRect;
var
  LDH, LDV: LongInt;
  LNewW, LNewH: LongInt;
begin
  LDH := LongInt(AMargin.Horizontal) * 2;
  LDV := LongInt(AMargin.Vertical) * 2;
  if LDH >= LongInt(Width) then
    LNewW := 0
  else
    LNewW := LongInt(Width) - LDH;
  if LDV >= LongInt(Height) then
    LNewH := 0
  else
    LNewH := LongInt(Height) - LDV;
  if LNewW = 0 then
  begin
    Result := TRect.Make(X, Y, 0, 0);
    Exit;
  end;
  Result := TRect.Make(X + AMargin.Horizontal, Y + AMargin.Vertical, LNewW, LNewH);
end;

end.
