program test_tui_widget_intf;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.testing;

type
  { 最小 stub widget：用单字符填满区域，验证 IWidget 契约可实现可调用 }
  TFillWidget = class(TInterfacedObject, IWidget)
  private
    FCh: AnsiChar;
  public
    constructor Create(ACh: AnsiChar);
    procedure Render(const AArea: TRect; ABuffer: TBuffer);
  end;

constructor TFillWidget.Create(ACh: AnsiChar);
begin
  inherited Create;
  FCh := ACh;
end;

procedure TFillWidget.Render(const AArea: TRect; ABuffer: TBuffer);
begin
  ABuffer.FillRect(AArea, FCh, StyleDefault);
end;

var
  T: TTestRunner;

procedure TestImplementAndRender;
var
  LWidget: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LWidget := TFillWidget.Create('*');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 2));
  try
    LWidget.Render(TRect.Make(0, 0, 3, 2), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('***', LLines[0], 'row 0 filled');
    CheckEqual('***', LLines[1], 'row 1 filled');
  finally
    LBuf.Free;
    { LWidget 引用计数自动释放 }
  end;
end;

procedure TestPolymorphicArray;
var
  LWidgets: array of IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
  LI: Integer;
begin
  { 多态集合：不同 widget 存为 IWidget，统一分发 }
  SetLength(LWidgets, 2);
  LWidgets[0] := TFillWidget.Create('a');
  LWidgets[1] := TFillWidget.Create('b');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 2));
  try
    { widget[0] 填上半，widget[1] 填下半 }
    LWidgets[0].Render(TRect.Make(0, 0, 2, 1), LBuf);
    LWidgets[1].Render(TRect.Make(0, 1, 2, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('aa', LLines[0], 'row 0 from widget a');
    CheckEqual('bb', LLines[1], 'row 1 from widget b');
    for LI := 0 to High(LWidgets) do
      LWidgets[LI] := nil;
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterRenderFunction;
var
  LWidget: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LWidget := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      ABuffer.FillRect(AArea, '#', StyleDefault);
    end);

  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 1));
  try
    LWidget.Render(TRect.Make(0, 0, 4, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('####', LLines[0], 'adapter invokes render function');
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterRejectsNilRenderFunction;
var
  LCaught: Boolean;
begin
  LCaught := False;
  try
    TWidgetAdapter.Create(nil);
  except
    on E: EArgumentException do
    begin
      LCaught := True;
      Check(Pos('render function', E.Message) > 0, 'adapter error message names render function');
    end;
  end;
  Check(LCaught, 'nil adapter render function rejected');
end;

begin
  T := TTestRunner.Create('nextpas.core.tui.widget.intf');
  T.Run('implement and render', @TestImplementAndRender);
  T.Run('polymorphic array', @TestPolymorphicArray);
  T.Run('adapter render function', @TestAdapterRenderFunction);
  T.Run('adapter rejects nil render function', @TestAdapterRejectsNilRenderFunction);
  T.Summary;
  if not T.AllPassed then
    Halt(1);
end.
