program test_tui_widget_intf;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tui.base,
  nextpas.core.tui.color,
  nextpas.core.tui.style,
  nextpas.core.tui.cell,
  nextpas.core.tui.buffer,
  nextpas.core.tui.widget.intf,
  nextpas.core.errors,
  nextpas.core.test;

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
  T: TTestSuite;

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
    on E: EArgumentError do
    begin
      LCaught := True;
      Check(Pos('render function', E.Message) > 0, 'adapter error message names render function');
    end;
  end;
  Check(LCaught, 'nil adapter render function rejected');
end;

procedure TestAdapterChaining;
var
  LWidget: IWidget;
  LBuf: TBuffer;
begin
  LWidget := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      ABuffer.FillRect(AArea, '*', StyleDefault);
    end);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LWidget.Render(TRect.Make(0, 0, 3, 1), LBuf);
    Check(Pos('***', LBuf.RowAsString(0)) > 0, 'adapter chained render');
  finally LBuf.Free; end;
end;

procedure TestRefcountRelease;
var
  LWidget: IWidget;
begin
  LWidget := TFillWidget.Create('Z');
  Check(LWidget <> nil, 'widget created');
  LWidget := nil;
  Check(True, 'widget released without error');
end;

procedure TestPartialAreaLeavesOutsideUntouched;
var
  LWidget: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LWidget := TFillWidget.Create('*');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 4, 2));
  try
    LBuf.FillRect(TRect.Make(0, 0, 4, 2), '.', StyleDefault);
    LWidget.Render(TRect.Make(1, 0, 2, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('.**.', LLines[0], 'partial fill only mid');
    CheckEqual('....', LLines[1], 'row 1 untouched');
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterEmptyAreaNoCrash;
var
  LWidget: IWidget;
  LBuf: TBuffer;
  LCalled: Boolean;
begin
  LCalled := False;
  LWidget := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      LCalled := True;
      ABuffer.FillRect(AArea, '?', StyleDefault);
    end);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LWidget.Render(TRect.Make(0, 0, 0, 0), LBuf);
    Check(LCalled, 'adapter still invokes for zero area');
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterOverwritesPrevious;
var
  LWidget: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LWidget := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      ABuffer.FillRect(AArea, '2', StyleDefault);
    end);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LBuf.FillRect(TRect.Make(0, 0, 3, 1), '1', StyleDefault);
    LWidget.Render(TRect.Make(0, 0, 3, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('222', LLines[0], 'second render overwrites');
  finally
    LBuf.Free;
  end;
end;

procedure TestThreeWidgetCompose;
var
  LWidgets: array[0..2] of IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
  I: Integer;
begin
  LWidgets[0] := TFillWidget.Create('a');
  LWidgets[1] := TFillWidget.Create('b');
  LWidgets[2] := TFillWidget.Create('c');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    for I := 0 to 2 do
      LWidgets[I].Render(TRect.Make(I, 0, 1, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('abc', LLines[0], 'three widgets compose');
  finally
    LBuf.Free;
  end;
end;

procedure TestInterfaceReassign;
var
  LA, LB: IWidget;
  LBuf: TBuffer;
  LLines: TBufferLines;
begin
  LA := TFillWidget.Create('A');
  LB := LA;
  Check(LA <> nil, 'alias non-nil');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 1, 1));
  try
    LB.Render(TRect.Make(0, 0, 1, 1), LBuf);
    LLines := LBuf.AsLines;
    CheckEqual('A', LLines[0], 'alias renders same instance');
    LA := nil;
    LB.Render(TRect.Make(0, 0, 1, 1), LBuf);
    CheckEqual('A', LBuf.AsLines[0], 'survives other ref nil');
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterCapturesOuter;
var
  LCh: AnsiChar;
  LWidget: IWidget;
  LBuf: TBuffer;
begin
  LCh := '@';
  LWidget := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      ABuffer.FillRect(AArea, LCh, StyleDefault);
    end);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LWidget.Render(TRect.Make(0, 0, 2, 1), LBuf);
    CheckEqual('@@', LBuf.AsLines[0], 'closure captures outer char');
  finally
    LBuf.Free;
  end;
end;

procedure TestNestedAdapterOverFill;
var
  LInner: IWidget;
  LOuter: IWidget;
  LBuf: TBuffer;
begin
  LInner := TFillWidget.Create('i');
  LOuter := TWidgetAdapter.Create(
    procedure(const AArea: TRect; ABuffer: TBuffer)
    begin
      LInner.Render(AArea, ABuffer);
    end);
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LOuter.Render(TRect.Make(0, 0, 2, 1), LBuf);
    CheckEqual('ii', LBuf.AsLines[0], 'adapter delegates to fill');
  finally
    LBuf.Free;
  end;
end;

procedure TestFillWidgetIdentityStable;
var
  LWidget: IWidget;
  LSame: IWidget;
begin
  LWidget := TFillWidget.Create('z');
  LSame := LWidget;
  Check(LWidget = LSame, 'interface identity stable');
end;

procedure TestAdapterRenderTwiceIdempotent;
var
  LWidget: IWidget;
  LBuf: TBuffer;
begin
  LWidget := TFillWidget.Create('#');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 3, 1));
  try
    LWidget.Render(TRect.Make(0, 0, 3, 1), LBuf);
    LWidget.Render(TRect.Make(0, 0, 3, 1), LBuf);
    CheckEqual('###', LBuf.AsLines[0], 'second render same');
  finally
    LBuf.Free;
  end;
end;

procedure TestAdapterZeroWidthAreaSafe;
var
  LWidget: IWidget;
  LBuf: TBuffer;
begin
  LWidget := TFillWidget.Create('!');
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 2, 1));
  try
    LBuf.SetString(0, 0, 'ab', StyleDefault);
    LWidget.Render(TRect.Make(0, 0, 0, 1), LBuf);
    CheckEqual('ab', LBuf.AsLines[0], 'zero width no write');
  finally
    LBuf.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.intf');
  T.Test('implement and render', @TestImplementAndRender);
  T.Test('polymorphic array', @TestPolymorphicArray);
  T.Test('adapter render function', @TestAdapterRenderFunction);
  T.Test('adapter rejects nil render function', @TestAdapterRejectsNilRenderFunction);
  T.Test('adapter chaining', @TestAdapterChaining);
  T.Test('refcount release', @TestRefcountRelease);
  T.Test('partial area leaves outside untouched', @TestPartialAreaLeavesOutsideUntouched);
  T.Test('adapter empty area no crash', @TestAdapterEmptyAreaNoCrash);
  T.Test('adapter overwrites previous', @TestAdapterOverwritesPrevious);
  T.Test('three widget compose', @TestThreeWidgetCompose);
  T.Test('interface reassign', @TestInterfaceReassign);
  T.Test('adapter captures outer', @TestAdapterCapturesOuter);
  T.Test('nested adapter over fill', @TestNestedAdapterOverFill);
  T.Test('fill widget identity stable', @TestFillWidgetIdentityStable);
  T.Test('adapter render twice idempotent', @TestAdapterRenderTwiceIdempotent);
  T.Test('adapter zero width area safe', @TestAdapterZeroWidthAreaSafe);
  if not T.Run then Halt(1);
end.
