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
  A := TRect.Make(0, 0, 40, 10);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([TTimelineEvent.Make('10:00', 'A'), TTimelineEvent.Make('11:00', 'B')]).Render(A, B);
    Check(True, 'Render');
  finally
    B.Free;
  end;
end;

procedure TestRenderEmpty;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 20, 5);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([]).Render(A, B);
    Check(True, 'Render empty');
  finally
    B.Free;
  end;
end;

procedure TestBuilderChaining;
var S1, S2: TStyle;
begin
  S1.Fg := IndexedColor(1); S2.Fg := IndexedColor(2);
  Check(TTimeline.New([TTimelineEvent.Make('T', 'E').WithDescription('D')]).WithStyle(S1).WithLineStyle(S2).WithNodeChar('*') <> nil, 'chain');
end;


procedure TestRenderShowsTimeAndTitle;
var B: TBuffer; A: TRect; L: AnsiString;
begin
  A := TRect.Make(0, 0, 40, 6);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([TTimelineEvent.Make('10:00', 'Deploy')]).WithNodeChar('*').Render(A, B);
    L := B.RowAsString(0);
    Check(Pos('10:00', L) > 0, 'time visible');
    Check(Pos('Deploy', L) > 0, 'title visible');
    Check(Pos('*', L) > 0, 'custom node char');
  finally B.Free; end;
end;

procedure TestRenderDescriptionOccupiesNextRow;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 40, 6);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([
      TTimelineEvent.Make('09:00', 'Start').WithDescription('boot')
    ]).Render(A, B);
    Check(Pos('Start', B.RowAsString(0)) > 0, 'title on first row');
    Check(Pos('boot', B.RowAsString(1)) > 0, 'description on next row');
  finally B.Free; end;
end;

procedure TestRenderClipsToAreaHeight;
var B: TBuffer; A: TRect; I: Integer; S: AnsiString;
begin
  A := TRect.Make(0, 0, 30, 1);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([
      TTimelineEvent.Make('1', 'First'),
      TTimelineEvent.Make('2', 'Second')
    ]).Render(A, B);
    S := B.RowAsString(0);
    Check(Pos('First', S) > 0, 'first event fits height 1');
    { no second row exists }
    CheckEqual(1, Length(B.AsLines), 'only one row buffer');
  finally B.Free; end;
end;

procedure TestRenderZeroAreaNoCrash;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 0, 0);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([TTimelineEvent.Make('T', 'E')]).Render(A, B);
    Check(True, 'zero area ok');
  finally B.Free; end;
end;

procedure TestRenderNarrowWidthStillShowsTitlePrefix;
var B: TBuffer; A: TRect;
begin
  A := TRect.Make(0, 0, 12, 3);
  B := TBuffer.CreateEmpty(A);
  try
    TTimeline.New([TTimelineEvent.Make('t', 'HelloWorld')]).Render(A, B);
    Check(Pos('Hello', B.RowAsString(0)) > 0, 'title prefix in narrow width');
  finally B.Free; end;
end;


{ PH33 P3：数据更新面——SetEvents 原地替换 + AddEvent 追加 }
procedure TestTimelineSetAddEvents;
var LT: ITimeline; LBuf: TBuffer; LAll: AnsiString; I: Integer;
begin
  LT := TTimeline.New([TTimelineEvent.Make('10:00', 'start')]);
  LT.SetEvents([TTimelineEvent.Make('11:00', 'replaced')]);
  LT.AddEvent(TTimelineEvent.Make('12:00', 'appended'));
  LBuf := TBuffer.CreateEmpty(TRect.Make(0, 0, 40, 5));
  try
    LT.Render(TRect.Make(0, 0, 40, 5), LBuf);
    LAll := '';
    for I := 0 to 4 do LAll := LAll + LBuf.RowAsString(I);
    Check(Pos('replaced', LAll) > 0, 'replaced event visible');
    Check(Pos('appended', LAll) > 0, 'appended event visible');
    Check(Pos('start', LAll) = 0, 'old event gone');
  finally LBuf.Free; end;
end;

procedure TestTimelineWithEventsChaining;
var LT: ITimeline;
begin
  LT := TTimeline.New([]).WithEvents([TTimelineEvent.Make('t', 'chained')]);
  Check(LT <> nil, 'WithEvents chains and returns interface');
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
  T.Test('render shows time and title', @TestRenderShowsTimeAndTitle);
  T.Test('render description next row', @TestRenderDescriptionOccupiesNextRow);
  T.Test('render clips to area height', @TestRenderClipsToAreaHeight);
  T.Test('render zero area', @TestRenderZeroAreaNoCrash);
  T.Test('render narrow width title prefix', @TestRenderNarrowWidthStillShowsTitlePrefix);
  T.Test('SetEvents/AddEvent update (PH33 P3)', @TestTimelineSetAddEvents);
  T.Test('WithEvents chaining (PH33 P3)', @TestTimelineWithEventsChaining);
if not T.Run then Halt(1);
end.
