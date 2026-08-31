program test_tui_widget_toast_anim;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.time,
  nextpas.core.tui.base,
  nextpas.core.tui.buffer,
  nextpas.core.tui.theme,
  nextpas.core.tui.widget.toast.anim,
  nextpas.core.test;

var
  T: TTestSuite;

function NowMs: QWord; inline;
begin
  Result := GetTickCount64;
end;

procedure TestToastKindEnum;
begin
  Check(Ord(tkInfo) = 0, 'tkInfo should be 0');
  Check(Ord(tkSpin) = 1, 'tkSpin should be 1');
  Check(Ord(tkOk) = 2, 'tkOk should be 2');
  Check(Ord(tkErr) = 3, 'tkErr should be 3');
  Check(Ord(tkWarn) = 4, 'tkWarn should be 4');
end;

procedure TestNew;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  Check(L <> nil, 'New should return non-nil');
  Check(L.Visible = 0, 'Initial visible should be 0');
end;

procedure TestShowOne;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('hello', tkInfo);
  Check(L.Visible = 1, 'Visible should be 1 after Show');
end;

procedure TestShowEmptyIgnored;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('', tkInfo);
  Check(L.Visible = 0, 'Empty text should be ignored');
end;

procedure TestShowSameKeyUpdates;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('first', tkInfo, 'k');
  L.Show('second', tkInfo, 'k');
  Check(L.Visible = 1, 'Same key Show must update in place, not append');
end;

procedure TestShowDifferentKeys;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('a', tkInfo, 'ka');
  L.Show('b', tkInfo, 'kb');
  Check(L.Visible = 2, 'Different keys should stack');
end;

procedure TestKindSwitchSameKey;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('work', tkInfo, 'k');
  L.Show('working', tkSpin, 'k');
  Check(L.Visible = 1, 'Kind switch on same key must not append');
end;

procedure TestFullStackDropsOldest;
var
  L: IToastAnim;
begin
  L := TToastAnim.New(1800, 3);
  L.Show('msg 1', tkInfo, 'k1');
  L.Show('msg 2', tkInfo, 'k2');
  L.Show('msg 3', tkInfo, 'k3');
  L.Show('msg 4', tkInfo, 'k4');
  Check(L.Visible = 3, 'Full stack should cap at AMaxVisible');
end;

procedure TestTickExpiresAll;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('x', tkInfo);
  L.Tick(NowMs + 10000);
  Check(L.Visible = 0, 'Tick past EndMs should drop the toast');
end;

procedure TestTickKeepsAliveMidLife;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('x', tkInfo);
  L.Tick(NowMs + 1000);
  Check(L.Visible = 1, 'Mid-life tick should keep the toast');
end;

procedure TestRenewExtendsLife;
var
  L: IToastAnim;
begin
  L := TToastAnim.New(1800, 3);
  L.Show('x', tkInfo, 'k');
  L.Renew('k', 5000);
  L.Tick(NowMs + 2000);
  Check(L.Visible = 1, 'Renew should extend past original duration');
  L.Tick(NowMs + 6000);
  Check(L.Visible = 0, 'Renewed toast should expire after ALifeMs');
end;

procedure TestRenewIgnoresMissingKey;
var
  L: IToastAnim;
begin
  L := TToastAnim.New;
  L.Show('x', tkInfo);
  L.Renew('', 5000);
  L.Renew('missing', 5000);
  Check(L.Visible = 1, 'Renew on empty/missing key must not create or crash');
end;

procedure TestNewClampsDurations;
var
  L: IToastAnim;
begin
  L := TToastAnim.New(0, 0);
  L.Show('x', tkInfo);
  L.Tick(NowMs + 10);
  Check(L.Visible = 0, 'Clamped duration should still expire (no div-by-zero)');
end;

procedure TestRenderEmpty;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  L := TToastAnim.New;
  LArea := TRect.Make(0, 0, 100, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Render(LBuffer, LArea, TTheme.Dark);
    Check(True, 'Render empty should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestRenderStable;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: TBufferLines;
  LAll: string;
  I: Integer;
begin
  L := TToastAnim.New;
  LArea := TRect.Make(0, 0, 100, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Show('已保存', tkOk);
    { 入场 240ms 由 Render 内真实时钟判定：真实等待入场结束再断言内容 }
    TSleep.ForDuration(TDuration.FromMilliseconds(260));
    L.Render(LBuffer, LArea, TTheme.Dark);
    LLines := LBuffer.AsLines;
    LAll := '';
    for I := 0 to High(LLines) do
      LAll := LAll + LLines[I] + #10;
    Check(Pos('╭', LAll) > 0, 'Top border should be drawn');
    Check(Pos('+', LAll) > 0, 'tkOk icon should be drawn');
    Check(Pos('已保存', LAll) > 0, 'Text should be drawn');
  finally
    LBuffer.Free;
  end;
end;

procedure TestRenderEnterPhase;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  L := TToastAnim.New;
  LArea := TRect.Make(0, 0, 100, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Show('入场中', tkInfo);
    L.Render(LBuffer, LArea, TTheme.Dark);   { BornMs 刚过：入场滑入+淡入分支 }
    Check(True, 'Render during enter phase should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestRenderExitPhase;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  L := TToastAnim.New(1800, 3);
  LArea := TRect.Make(0, 0, 100, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Show('退场中', tkWarn);
    L.Tick(NowMs + 1700);   { 剩余 100ms < EXIT_MS：下滑淡出分支 }
    L.Render(LBuffer, LArea, TTheme.Dark);
    Check(True, 'Render during exit phase should not raise');
  finally
    LBuffer.Free;
  end;
end;

procedure TestRenderNarrow;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
begin
  L := TToastAnim.New;
  LArea := TRect.Make(0, 0, 12, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Show('x', tkErr);
    L.Render(LBuffer, LArea, TTheme.Dark);
    Check(True, 'Render on narrow area should skip gracefully');
  finally
    LBuffer.Free;
  end;
end;

procedure TestRenderStack;
var
  L: IToastAnim;
  LBuffer: TBuffer;
  LArea: TRect;
  LLines: TBufferLines;
  LAll: string;
  I: Integer;
begin
  L := TToastAnim.New;
  LArea := TRect.Make(0, 0, 100, 30);
  LBuffer := TBuffer.CreateEmpty(LArea);
  try
    L.Show('一', tkInfo, '1');
    L.Show('二', tkInfo, '2');
    L.Show('三', tkInfo, '3');
    TSleep.ForDuration(TDuration.FromMilliseconds(260));   { 入场结束：栈稳定态 }
    L.Render(LBuffer, LArea, TTheme.Dark);
    LLines := LBuffer.AsLines;
    LAll := '';
    for I := 0 to High(LLines) do
      LAll := LAll + LLines[I] + #10;
    Check(Pos('一', LAll) > 0, 'oldest toast drawn');
    Check(Pos('二', LAll) > 0, 'middle toast drawn');
    Check(Pos('三', LAll) > 0, 'newest toast drawn');
  finally
    LBuffer.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.tui.widget.toast.anim');
  T.Test('TToastKind enum', @TestToastKindEnum);
  T.Test('TToastAnim.New', @TestNew);
  T.Test('TToastAnim.Show one', @TestShowOne);
  T.Test('TToastAnim.Show empty ignored', @TestShowEmptyIgnored);
  T.Test('TToastAnim.Show same key updates', @TestShowSameKeyUpdates);
  T.Test('TToastAnim.Show different keys', @TestShowDifferentKeys);
  T.Test('TToastAnim.Show kind switch same key', @TestKindSwitchSameKey);
  T.Test('TToastAnim full stack drops oldest', @TestFullStackDropsOldest);
  T.Test('TToastAnim.Tick expires all', @TestTickExpiresAll);
  T.Test('TToastAnim.Tick keeps alive mid-life', @TestTickKeepsAliveMidLife);
  T.Test('TToastAnim.Renew extends life', @TestRenewExtendsLife);
  T.Test('TToastAnim.Renew ignores missing key', @TestRenewIgnoresMissingKey);
  T.Test('TToastAnim.New clamps durations', @TestNewClampsDurations);
  T.Test('TToastAnim.Render empty', @TestRenderEmpty);
  T.Test('TToastAnim.Render stable', @TestRenderStable);
  T.Test('TToastAnim.Render enter phase', @TestRenderEnterPhase);
  T.Test('TToastAnim.Render exit phase', @TestRenderExitPhase);
  T.Test('TToastAnim.Render narrow', @TestRenderNarrow);
  T.Test('TToastAnim.Render stack', @TestRenderStack);
  if not T.Run then Halt(1);
end.