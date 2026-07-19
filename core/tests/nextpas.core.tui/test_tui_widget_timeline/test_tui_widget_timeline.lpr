program test_tui_widget_timeline;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base, nextpas.core.base.utils,
  nextpas.core.tui.base, nextpas.core.tui.color, nextpas.core.tui.style,
  nextpas.core.tui.buffer, nextpas.core.tui.widget.timeline,
  nextpas.core.test;

var T: TTestSuite;

procedure TestEventMake;
var E: TTimelineEvent;
begin E := TTimelineEvent.Make('10:00', 'Release'); Check(E.Time = '10:00', 'time'); Check(E.Title = 'Release', 'title'); end;

procedure TestEventWithDescription;
var E: TTimelineEvent;
begin E := TTimelineEvent.Make('T', 'E').WithDescription('Desc'); Check(E.Description = 'Desc', 'desc'); end;

procedure TestEventWithStyle;
var E: TTimelineEvent; S: TStyle;
begin S.Fg := IndexedColor(1); E := TTimelineEvent.Make('T', 'E').WithStyle(S); Check(True, 'style'); end;

procedure TestNew;
begin Check(TTimeline.New([TTimelineEvent.Make('T', 'E')]) <> nil, 'New'); end;

procedure TestNewEmpty;
begin Check(TTimeline.New([]) <> nil, 'New empty'); end;

procedure TestWithStyle;
var S: TStyle;
begin S.Fg := IndexedColor(1); Check(TTimeline.New([TTimelineEvent.Make('T', 'E')]).WithStyle(S) <> nil, 'WithStyle'); end;

procedure TestWithLineStyle;
var S: TStyle;
begin S.Fg := IndexedColor(2); Check(TTimeline.New([TTimelineEvent.Make('T', 'E')]).WithLineStyle(S) <> nil, 'WithLineStyle'); end;

procedure TestWithNodeChar;
begin Check(TTimeline.New([TTimelineEvent.Make('T', 'E')]).WithNodeChar('*') <> nil, 'WithNodeChar'); end;

procedure TestRender;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 10); B := TBuffer.CreateEmpty(A);
  TTimeline.New([TTimelineEvent.Make('10:00', 'A'), TTimelineEvent.Make('11:00', 'B')]).Render(A, B);
  Check(True, 'Render');
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 20, 5); B := TBuffer.CreateEmpty(A);
  TTimeline.New([]).Render(A, B);
  Check(True, 'Render empty');
end;

procedure TestBuilderChaining;
var S1, S2: TStyle;
begin
  S1.Fg := IndexedColor(1); S2.Fg := IndexedColor(2);
  Check(TTimeline.New([TTimelineEvent.Make('T', 'E').WithDescription('D')]).WithStyle(S1).WithLineStyle(S2).WithNodeChar('*') <> nil, 'chain');
end;

begin
  T := TTestSuite.Create('tui_widget_timeline');
  T.Test('EventMake', @TestEventMake);
  T.Test('EventWithDescription', @TestEventWithDescription);
  T.Test('EventWithStyle', @TestEventWithStyle);
  T.Test('New', @TestNew);
  T.Test('New empty', @TestNewEmpty);
  T.Test('WithStyle', @TestWithStyle);
  T.Test('WithLineStyle', @TestWithLineStyle);
  T.Test('WithNodeChar', @TestWithNodeChar);
  T.Test('Render', @TestRender);
  T.Test('Render empty', @TestRenderEmpty);
  T.Test('Builder chaining', @TestBuilderChaining);
  if not T.Run then Halt(1);
end.
