program test_fpc_math;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.fpc.math,
  nextpas.core.testing;

var
  T: TTestRunner;

procedure TestMinMax;
begin
  Check(Min(3, 7) = 3, 'min int');
  Check(Max(3, 7) = 7, 'max int');
  Check(Min(Int64(-1), Int64(1)) = -1, 'min i64');
  Check(Max(Int64(-1), Int64(1)) = 1, 'max i64');
end;

procedure TestEnsureRange;
begin
  Check(EnsureRange(5, 1, 10) = 5, 'in range');
  Check(EnsureRange(-5, 0, 100) = 0, 'below');
  Check(EnsureRange(200, 0, 100) = 100, 'above');
end;

procedure TestInRange;
begin
  Check(InRange(5, 1, 10), '5 in 1..10');
  Check(not InRange(0, 1, 10), '0 not in 1..10');
  Check(InRange(1, 1, 10), 'boundary low');
  Check(InRange(10, 1, 10), 'boundary high');
end;

procedure TestSign;
begin
  Check(Sign(42) = 1, 'positive');
  Check(Sign(-7) = -1, 'negative');
  Check(Sign(0) = 0, 'zero');
end;

procedure TestIfThen;
begin
  Check(IfThen(True, 1, 2) = 1, 'true');
  Check(IfThen(False, 1, 2) = 2, 'false');
  Check(IfThen(True, 'yes', 'no') = 'yes', 'str true');
end;

procedure TestPowerOfTwo;
begin
  Check(IsPowerOfTwo(1), '1');
  Check(IsPowerOfTwo(2), '2');
  Check(IsPowerOfTwo(1024), '1024');
  Check(not IsPowerOfTwo(3), '3');
  Check(not IsPowerOfTwo(0), '0');
  Check(NextPowerOfTwo(5) = 8, 'next 5->8');
  Check(NextPowerOfTwo(8) = 8, 'next 8->8');
  Check(NextPowerOfTwo(1) = 1, 'next 1->1');
  Check(NextPowerOfTwo(0) = 1, 'next 0->1');
end;

procedure TestCeilDiv;
begin
  Check(CeilDiv(10, 3) = 4, '10/3');
  Check(CeilDiv(9, 3) = 3, '9/3');
  Check(CeilDiv(1, 4) = 1, '1/4');
end;

begin
  T := TTestRunner.Create('nextpas.core.fpc.math');
  T.Run('Min/Max', @TestMinMax);
  T.Run('EnsureRange', @TestEnsureRange);
  T.Run('InRange', @TestInRange);
  T.Run('Sign', @TestSign);
  T.Run('IfThen', @TestIfThen);
  T.Run('PowerOfTwo', @TestPowerOfTwo);
  T.Run('CeilDiv', @TestCeilDiv);
  T.Summary;
end.
