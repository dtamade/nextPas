program test_automation;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.audio.studio.automation;

type T = class
  procedure TestCreate;
  procedure TestAddPoint;
  procedure TestValueAt;
  procedure TestHermite;
  procedure TestClear;
  procedure TestCount;
  procedure TestFillRealtime;
  procedure TestInterpolate;
end;

procedure T.TestCreate;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; CheckEqual(0, C.Count, '0'); C.Free;
end;

procedure T.TestAddPoint;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; C.AddPoint(0,0); C.AddPoint(100,1); CheckEqual(2, C.Count, '2'); C.Free;
end;

procedure T.TestValueAt;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; C.AddPoint(0,0); C.AddPoint(100,1);
  CheckNear(0, C.ValueAt(0), 1e-6, '0');
  CheckNear(1, C.ValueAt(100), 1e-6, '1');
  CheckTrue(C.ValueAt(50)>=0, 'mid');
  C.Free;
end;

procedure T.TestHermite;
var V: Single;
begin
  V:=HermiteInterpolate(0,0,1,1,0.5);
  CheckTrue(V>=0, 'hermite');
end;

procedure T.TestClear;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; C.AddPoint(0,0); C.Clear; CheckEqual(0, C.Count, 'clear'); C.Free;
end;

procedure T.TestCount;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; CheckEqual(0, C.Count, '0'); C.AddPoint(10,1); CheckEqual(1, C.Count, '1'); C.Free;
end;

procedure T.TestFillRealtime;
var C: TAutomationCurve; D: array[0..9] of Single; I: Integer;
begin
  C:=TAutomationCurve.Create; C.AddPoint(0,0); C.AddPoint(10,1);
  C.FillRealtimeValues(0,10,@D[0]); CheckTrue(D[0]=0, 'first'); C.Free;
end;

procedure T.TestInterpolate;
var C: TAutomationCurve;
begin
  C:=TAutomationCurve.Create; C.AddPoint(0,0); C.AddPoint(100,10); C.AddPoint(200,0);
  CheckTrue(C.ValueAt(100)=10, 'peak'); C.Free;
end;

var Suite: TTestSuite; Cc: T;
begin
  Cc:=T.Create; Suite:=TTestSuite.Create('audio.automation');
  Suite.Test('create', @Cc.TestCreate);
  Suite.Test('add point', @Cc.TestAddPoint);
  Suite.Test('value at', @Cc.TestValueAt);
  Suite.Test('hermite', @Cc.TestHermite);
  Suite.Test('clear', @Cc.TestClear);
  Suite.Test('count', @Cc.TestCount);
  Suite.Test('fill realtime', @Cc.TestFillRealtime);
  Suite.Test('interpolate', @Cc.TestInterpolate);
  Cc.Free;
  if not Suite.Run then Halt(1);
end.
