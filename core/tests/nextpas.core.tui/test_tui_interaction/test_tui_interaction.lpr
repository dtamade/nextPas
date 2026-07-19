program test_tui_interaction;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.interaction,
  nextpas.core.test;
var T: TTestSuite;

procedure TestCapture;
var C: TPointerCapture;
begin
  C.Release; Check(not C.Active, 'released');
  C.Acquire(Pointer(1), mbLeft); Check(C.Active, 'acquired');
  C.Release; Check(not C.Active, 'released again');
end;

procedure TestSession;
var S: TInteractionSession;
begin
  S.State := ssNone; Check(not S.IsActive, 'none not active');
  S.Begin_(nil); Check(S.IsActive, 'active after begin');
  S.Commit; Check(S.State = ssCommitted, 'committed');
  S.State := ssNone; S.Begin_(nil); S.Cancel;
  Check(S.State = ssCancelled, 'cancelled');
end;

procedure TestHitTest;
begin
  Check(HitTest(TRect.Make(2,2,4,4), 3, 3), 'inside');
  Check(not HitTest(TRect.Make(2,2,4,4), 6, 3), 'outside right');
end;

procedure TestHitTestBoundary;
begin
  Check(HitTest(TRect.Make(0,0,10,10), 0, 0), 'top-left corner inside');
  Check(not HitTest(TRect.Make(0,0,10,10), 10, 0), 'right edge outside');
  Check(not HitTest(TRect.Make(0,0,10,10), 0, 10), 'bottom edge outside');
  Check(HitTest(TRect.Make(0,0,10,10), 9, 9), 'bottom-right-1 inside');
  Check(not HitTest(TRect.Make(0,0,10,10), -1, 0), 'negative x outside');
  Check(not HitTest(TRect.Make(0,0,10,10), 0, -1), 'negative y outside');
end;

procedure TestHover;
begin
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 10,10, 2,2) = hcEntered, 'entered');
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 2,2, 10,10) = hcLeft, 'left');
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 2,2, 3,3) = hcStay, 'stay');
end;

procedure TestHoverSamePos;
begin
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 3,3, 3,3) = hcStay, 'same position stay');
end;

procedure TestSessionMultipleTransitions;
var S: TInteractionSession;
begin
  { committed -> none -> active -> cancelled }
  S.State := ssNone; S.Begin_(nil); S.Commit;
  Check(S.State = ssCommitted, 'first commit');
  S.State := ssNone;
  Check(not S.IsActive, 'none not active after reset');
  S.Begin_(nil); S.Cancel;
  Check(S.State = ssCancelled, 'cancelled after reset');
end;


procedure TestCaptureReleaseClears;
var
  C: TPointerCapture;
begin
  C.Acquire(Pointer(1), mbLeft);
  Check(C.Active, 'acquired');
  C.Release;
  Check(not C.Active, 'released');
end;

procedure TestSessionIsActiveLifecycle;
var
  S: TInteractionSession;
begin
  S.State := ssNone;
  Check(not S.IsActive, 'none inactive');
  S.Begin_(Pointer(2));
  Check(S.IsActive, 'active after begin');
  S.Commit;
  Check(not S.IsActive, 'committed inactive');
end;

procedure TestHitTestOutside;
begin
  Check(not HitTest(TRect.Make(0, 0, 5, 5), 10, 10), 'outside false');
  Check(HitTest(TRect.Make(0, 0, 5, 5), 0, 0), 'origin inside');
end;

procedure TestHoverEnterLeave;
var
  H: THoverChange;
begin
  H := DetectHoverChange(TRect.Make(0, 0, 5, 5), 10, 10, 1, 1);
  Check(H = hcEntered, 'enter');
  H := DetectHoverChange(TRect.Make(0, 0, 5, 5), 1, 1, 10, 10);
  Check(H = hcLeft, 'leave');
end;

procedure TestHitTestEventUsesCoords;
var
  Ev: TMouseEvent;
begin
  Ev.X := 2;
  Ev.Y := 2;
  Ev.Kind := mkMoved;
  Ev.Button := mbNone;
  Ev.Modifiers := [];
  Check(HitTestEvent(TRect.Make(0, 0, 5, 5), Ev), 'event inside');
end;


begin
  T := TTestSuite.Create('nextpas.core.tui.interaction');
  T.Test('capture', @TestCapture);
  T.Test('session', @TestSession);
  T.Test('hit test', @TestHitTest);
  T.Test('hit test boundary', @TestHitTestBoundary);
  T.Test('hover', @TestHover);
  T.Test('hover same position', @TestHoverSamePos);
  T.Test('session multiple transitions', @TestSessionMultipleTransitions);
    T.Test('capture release clears', @TestCaptureReleaseClears);
  T.Test('session is active lifecycle', @TestSessionIsActiveLifecycle);
  T.Test('hit test outside', @TestHitTestOutside);
  T.Test('hover enter leave', @TestHoverEnterLeave);
  T.Test('hit test event coords', @TestHitTestEventUsesCoords);
if not T.Run then Halt(1);
end.
