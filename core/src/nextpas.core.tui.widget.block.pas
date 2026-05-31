unit nextpas.core.tui.widget.block;

{**
 * @desc TBlock — 容器 widget，提供边框和标题。
 *
 * 实现 IWidget + IBlock 接口。IBlock 扩展 IWidget 加 Inner 方法，
 * 供其他 widget（如 TList）引用 block 作外框时面向接口。
 *
 * Builder 链返回 IBlock（接口引用），消费方全程持接口引用。
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
  nextpas.core.tui.buffer,
  nextpas.core.tui.borders,
  nextpas.core.tui.widget.intf;

type
  { IBlock 扩展 IWidget：容器 widget 提供 Inner 计算内部可用区域。 }
  IBlock = interface(IWidget)
    ['{C8D9E0F1-2A3B-4C5D-6E7F-8A9B0C1D2E3F}']
    function Inner(const AArea: TRect): TRect;
    function WithBorders(ABorders: TBorders): IBlock;
    function WithBorderSet(const ABorderSet: TBorderSet): IBlock;
    function WithTitle(const ATitle: AnsiString): IBlock;
    function WithStyle(const AStyle: TStyle): IBlock;
    function WithBorderStyle(const AStyle: TStyle): IBlock;
    function WithTitleStyle(const AStyle: TStyle): IBlock;
  end;

  TBlock = class(TInterfacedObject, IWidget, IBlock)
  private
    FBorders: TBorders;
    FBorderSet: TBorderSet;
    FHasTitle: Boolean;
    FTitle: AnsiString;
    FStyle: TStyle;
    FBorderStyle: TStyle;
    FTitleStyle: TStyle;
  public
    class function New: IBlock; static;
    { 快捷：全边框 + 标题（最常用模式） }
    class function Bordered(const ATitle: AnsiString): IBlock; static;

    { IBlock builder 链 }
    function WithBorders(ABorders: TBorders): IBlock;
    function WithBorderSet(const ABorderSet: TBorderSet): IBlock;
    function WithTitle(const ATitle: AnsiString): IBlock;
    function WithStyle(const AStyle: TStyle): IBlock;
    function WithBorderStyle(const AStyle: TStyle): IBlock;
    function WithTitleStyle(const AStyle: TStyle): IBlock;

    { IWidget }
    procedure Render(const AArea: TRect; ABuffer: TBuffer);

    { IBlock }
    function Inner(const AArea: TRect): TRect;
  end;

implementation

{ helper }

procedure PaintGlyph(ABuffer: TBuffer; AX, AY: Integer;
  const AGlyph: AnsiString; const AStyle: TStyle); inline;
var
  LCP: PCell;
begin
  LCP := ABuffer.CellAt(AX, AY);
  if LCP = nil then Exit;
  if System.Length(AGlyph) > 0 then
    CellSetSymbolBytes(LCP^, AGlyph[1], System.Length(AGlyph), 1);
  CellApplyStyle(LCP^, AStyle);
end;

{ TBlock }

class function TBlock.New: IBlock;
var
  LBlock: TBlock;
begin
  LBlock := TBlock.Create;
  LBlock.FBorders := [];
  LBlock.FBorderSet := BorderSetPlain;
  LBlock.FHasTitle := False;
  LBlock.FTitle := '';
  LBlock.FStyle := TStyle.Default;
  LBlock.FBorderStyle := TStyle.Default;
  LBlock.FTitleStyle := TStyle.Default;
  Result := LBlock;
end;

class function TBlock.Bordered(const ATitle: AnsiString): IBlock;
begin
  Result := TBlock.New.WithBorders(BORDERS_ALL).WithTitle(ATitle);
end;

function TBlock.WithBorders(ABorders: TBorders): IBlock;
begin
  FBorders := ABorders;
  Result := Self;
end;

function TBlock.WithBorderSet(const ABorderSet: TBorderSet): IBlock;
begin
  FBorderSet := ABorderSet;
  Result := Self;
end;

function TBlock.WithTitle(const ATitle: AnsiString): IBlock;
begin
  FHasTitle := True;
  FTitle := ATitle;
  Result := Self;
end;

function TBlock.WithStyle(const AStyle: TStyle): IBlock;
begin
  FStyle := AStyle;
  Result := Self;
end;

function TBlock.WithBorderStyle(const AStyle: TStyle): IBlock;
begin
  FBorderStyle := AStyle;
  Result := Self;
end;

function TBlock.WithTitleStyle(const AStyle: TStyle): IBlock;
begin
  FTitleStyle := AStyle;
  Result := Self;
end;

procedure TBlock.Render(const AArea: TRect; ABuffer: TBuffer);
var
  LClip: TRect;
  LX, LY, LRightX, LBottomY, LTitleX, LTitleMaxW: Integer;
begin
  LClip := ABuffer.Area.Intersection(AArea);
  if LClip.IsEmpty then Exit;

  { Step 1: 用 block 基础样式涂满区域 }
  ABuffer.SetStyle(LClip, FStyle);

  LRightX := LClip.X + LClip.Width - 1;
  LBottomY := LClip.Y + LClip.Height - 1;

  { Step 2: 边 }
  if bsTop in FBorders then
    for LX := LClip.X to LRightX do
      PaintGlyph(ABuffer, LX, LClip.Y, FBorderSet.Horizontal, FBorderStyle);

  if bsBottom in FBorders then
    for LX := LClip.X to LRightX do
      PaintGlyph(ABuffer, LX, LBottomY, FBorderSet.Horizontal, FBorderStyle);

  if bsLeft in FBorders then
    for LY := LClip.Y to LBottomY do
      PaintGlyph(ABuffer, LClip.X, LY, FBorderSet.Vertical, FBorderStyle);

  if bsRight in FBorders then
    for LY := LClip.Y to LBottomY do
      PaintGlyph(ABuffer, LRightX, LY, FBorderSet.Vertical, FBorderStyle);

  { Step 3: 角 }
  if (bsTop in FBorders) and (bsLeft in FBorders) then
    PaintGlyph(ABuffer, LClip.X, LClip.Y, FBorderSet.TopLeft, FBorderStyle);
  if (bsTop in FBorders) and (bsRight in FBorders) then
    PaintGlyph(ABuffer, LRightX, LClip.Y, FBorderSet.TopRight, FBorderStyle);
  if (bsBottom in FBorders) and (bsLeft in FBorders) then
    PaintGlyph(ABuffer, LClip.X, LBottomY, FBorderSet.BottomLeft, FBorderStyle);
  if (bsBottom in FBorders) and (bsRight in FBorders) then
    PaintGlyph(ABuffer, LRightX, LBottomY, FBorderSet.BottomRight, FBorderStyle);

  { Step 4: 标题 }
  if FHasTitle and (System.Length(FTitle) > 0) and (LClip.Height > 0) then
  begin
    if bsLeft in FBorders then
      LTitleX := LClip.X + 1
    else
      LTitleX := LClip.X;
    LTitleMaxW := LClip.Width;
    if bsLeft in FBorders then Dec(LTitleMaxW);
    if bsRight in FBorders then Dec(LTitleMaxW);
    if LTitleMaxW > 0 then
      ABuffer.SetStringN(LTitleX, LClip.Y, FTitle, LTitleMaxW, FTitleStyle);
  end;
end;

function TBlock.Inner(const AArea: TRect): TRect;
var
  LX, LY, LW, LH: Integer;
  LTopShrink, LBottomShrink: Integer;
begin
  LX := AArea.X;
  LY := AArea.Y;
  LW := AArea.Width;
  LH := AArea.Height;

  LTopShrink := 0;
  LBottomShrink := 0;

  if bsLeft in FBorders then begin Inc(LX); Dec(LW); end;
  if bsRight in FBorders then Dec(LW);
  if bsTop in FBorders then LTopShrink := 1;
  if bsBottom in FBorders then LBottomShrink := 1;

  { ratatui 规则：顶部标题即使无顶边框也强制 +1 垂直收缩 }
  if FHasTitle and (LTopShrink = 0) then LTopShrink := 1;

  Inc(LY, LTopShrink);
  Dec(LH, LTopShrink + LBottomShrink);

  if LW < 0 then LW := 0;
  if LH < 0 then LH := 0;

  Result := TRect.Make(LX, LY, LW, LH);
end;

end.
