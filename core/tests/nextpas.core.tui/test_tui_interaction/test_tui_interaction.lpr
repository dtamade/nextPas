program test_tui_interaction;
{$I nextpas.core.settings.inc}
uses
  nextpas.core.tui.base,
  nextpas.core.tui.event,
  nextpas.core.tui.interaction,
  nextpas.core.testing;
var T: TTestRunner;
procedure TestCapture;
var C: TPointerCapture;
begin C.Release; Check(not C.Active, 'released');
  C.Acquire(Pointer(1), mbLeft); Check(C.Active, 'acquired');
  C.Release; Check(not C.Active, 'released again'); end;
procedure TestSession;
var S: TInteractionSession;
begin S.State := ssNone; Check(not S.IsActive, 'none not active');
  S.Begin_(nil); Check(S.IsActive, 'active after begin');
  S.Commit; Check(S.State = ssCommitted, 'committed');
  S.State := ssNone; S.Begin_(nil); S.Cancel;
  Check(S.State = ssCancelled, 'cancelled'); end;
procedure TestHitTest;
begin Check(HitTest(TRect.Make(2,2,4,4), 3, 3), 'inside');
  Check(not HitTest(TRect.Make(2,2,4,4), 6, 3), 'outside right'); end;
procedure TestHover;
begin Check(DetectHoverChange(TRect.Make(0,0,5,5), 10,10, 2,2) = hcEntered, 'entered');
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 2,2, 10,10) = hcLeft, 'left');
  Check(DetectHoverChange(TRect.Make(0,0,5,5), 2,2, 3,3) = hcStay, 'stay'); end;
begin
  T := TTestRunner.Create('nextpas.core.tui.interaction');
  T.Run('capture', @TestCapture); T.Run('session', @TestSession);
  T.Run('hit test', @TestHitTest); T.Run('hover', @TestHover);
  T.Summary; if not T.AllPassed then Halt(1);
end.
