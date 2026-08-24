unit nextpas.core.tui.widget.emptystate;

{*
  空态占位渲染:主行 + 可选提示行在区域内水平垂直居中。

  范式来源(agentman888 反哺):列表无数据时严禁假数据兜底,
  以居中占位文案表达空态——主行用 Soft 色,提示行用 Dim 色
  (颜色由调用方经 TStyle 传入,本单元不持有主题概念)。
  宽度一律按显示宽(CJK/全角 = 2 列)计算,保证中英文案都居中。
*}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.style,
  nextpas.core.text.width;

{ AHint 为空只画主行(单行垂直居中);文本宽于区域时钳到区域左缘 }
procedure RenderCenteredEmptyState(ABuffer: TBuffer; const AArea: TRect;
  const AMain, AHint: string;
  const AMainStyle, AHintStyle: TStyle);

implementation

procedure RenderCenteredEmptyState(ABuffer: TBuffer; const AArea: TRect;
  const AMain, AHint: string;
  const AMainStyle, AHintStyle: TStyle);
var
  Rows, Y, MX, HX: Integer;
begin
  if AArea.IsEmpty then Exit;
  if AHint = '' then
    Rows := 1
  else
    Rows := 2;
  { 垂直居中:两行块顶行 = AArea.Y + (H - Rows) div 2 }
  Y := AArea.Y + (AArea.Height - Rows) div 2;
  if Y < AArea.Y then Y := AArea.Y;
  MX := AArea.X + (AArea.Width -
    Integer(StringDisplayWidth(AnsiString(AMain)))) div 2;
  if MX < AArea.X then MX := AArea.X;
  ABuffer.SetString(MX, Y, AnsiString(AMain), AMainStyle);
  if Rows = 2 then
  begin
    HX := AArea.X + (AArea.Width -
      Integer(StringDisplayWidth(AnsiString(AHint)))) div 2;
    if HX < AArea.X then HX := AArea.X;
    ABuffer.SetString(HX, Y + 1, AnsiString(AHint), AHintStyle);
  end;
end;

end.
