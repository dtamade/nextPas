{
  test_easing.lpr
  Tests for nextpas.core.math.easing
}
program test_easing;

{$mode ObjFPC}{$H+}

uses
  SysUtils,
  nextpas.core.math.scalar,
  nextpas.core.math.easing;

var
  GTestCount: Integer = 0;
  GPassCount: Integer = 0;
  GFailCount: Integer = 0;

procedure AssertFloatEq(const ATestName: string; const AActual, AExpected, AEpsilon: Single);
begin
  Inc(GTestCount);
  if Abs(AActual - AExpected) <= AEpsilon then
  begin
    Inc(GPassCount);
    WriteLn('  PASS: ', ATestName);
  end
  else
  begin
    Inc(GFailCount);
    WriteLn('  FAIL: ', ATestName, ' expected=', AExpected:8:4, ' actual=', AActual:8:4);
  end;
end;

begin
  WriteLn('=== nextpas.core.math.easing tests ===');
  WriteLn;

  // Test endpoints (t=0 -> 0, t=1 -> 1)
  WriteLn('Testing endpoints (t=0 -> 0, t=1 -> 1):');
  AssertFloatEq('Linear t=0', Linear(0.0), 0.0, 0.001);
  AssertFloatEq('Linear t=1', Linear(1.0), 1.0, 0.001);
  AssertFloatEq('QuadIn t=0', QuadIn(0.0), 0.0, 0.001);
  AssertFloatEq('QuadIn t=1', QuadIn(1.0), 1.0, 0.001);
  AssertFloatEq('QuadOut t=0', QuadOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuadOut t=1', QuadOut(1.0), 1.0, 0.001);
  AssertFloatEq('QuadInOut t=0', QuadInOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuadInOut t=1', QuadInOut(1.0), 1.0, 0.001);
  AssertFloatEq('CubicIn t=0', CubicIn(0.0), 0.0, 0.001);
  AssertFloatEq('CubicIn t=1', CubicIn(1.0), 1.0, 0.001);
  AssertFloatEq('CubicOut t=0', CubicOut(0.0), 0.0, 0.001);
  AssertFloatEq('CubicOut t=1', CubicOut(1.0), 1.0, 0.001);
  AssertFloatEq('CubicInOut t=0', CubicInOut(0.0), 0.0, 0.001);
  AssertFloatEq('CubicInOut t=1', CubicInOut(1.0), 1.0, 0.001);
  AssertFloatEq('QuartIn t=0', QuartIn(0.0), 0.0, 0.001);
  AssertFloatEq('QuartIn t=1', QuartIn(1.0), 1.0, 0.001);
  AssertFloatEq('QuartOut t=0', QuartOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuartOut t=1', QuartOut(1.0), 1.0, 0.001);
  AssertFloatEq('QuartInOut t=0', QuartInOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuartInOut t=1', QuartInOut(1.0), 1.0, 0.001);
  AssertFloatEq('QuintIn t=0', QuintIn(0.0), 0.0, 0.001);
  AssertFloatEq('QuintIn t=1', QuintIn(1.0), 1.0, 0.001);
  AssertFloatEq('QuintOut t=0', QuintOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuintOut t=1', QuintOut(1.0), 1.0, 0.001);
  AssertFloatEq('QuintInOut t=0', QuintInOut(0.0), 0.0, 0.001);
  AssertFloatEq('QuintInOut t=1', QuintInOut(1.0), 1.0, 0.001);
  AssertFloatEq('SineIn t=0', SineIn(0.0), 0.0, 0.001);
  AssertFloatEq('SineIn t=1', SineIn(1.0), 1.0, 0.001);
  AssertFloatEq('SineOut t=0', SineOut(0.0), 0.0, 0.001);
  AssertFloatEq('SineOut t=1', SineOut(1.0), 1.0, 0.001);
  AssertFloatEq('SineInOut t=0', SineInOut(0.0), 0.0, 0.001);
  AssertFloatEq('SineInOut t=1', SineInOut(1.0), 1.0, 0.001);
  AssertFloatEq('ExpoIn t=0', ExpoIn(0.0), 0.0, 0.001);
  AssertFloatEq('ExpoIn t=1', ExpoIn(1.0), 1.0, 0.001);
  AssertFloatEq('ExpoOut t=0', ExpoOut(0.0), 0.0, 0.001);
  AssertFloatEq('ExpoOut t=1', ExpoOut(1.0), 1.0, 0.001);
  AssertFloatEq('ExpoInOut t=0', ExpoInOut(0.0), 0.0, 0.001);
  AssertFloatEq('ExpoInOut t=1', ExpoInOut(1.0), 1.0, 0.001);
  AssertFloatEq('CircIn t=0', CircIn(0.0), 0.0, 0.001);
  AssertFloatEq('CircIn t=1', CircIn(1.0), 1.0, 0.001);
  AssertFloatEq('CircOut t=0', CircOut(0.0), 0.0, 0.001);
  AssertFloatEq('CircOut t=1', CircOut(1.0), 1.0, 0.001);
  AssertFloatEq('CircInOut t=0', CircInOut(0.0), 0.0, 0.001);
  AssertFloatEq('CircInOut t=1', CircInOut(1.0), 1.0, 0.001);
  AssertFloatEq('ElasticIn t=0', ElasticIn(0.0), 0.0, 0.001);
  AssertFloatEq('ElasticIn t=1', ElasticIn(1.0), 1.0, 0.001);
  AssertFloatEq('ElasticOut t=0', ElasticOut(0.0), 0.0, 0.001);
  AssertFloatEq('ElasticOut t=1', ElasticOut(1.0), 1.0, 0.001);
  AssertFloatEq('ElasticInOut t=0', ElasticInOut(0.0), 0.0, 0.001);
  AssertFloatEq('ElasticInOut t=1', ElasticInOut(1.0), 1.0, 0.001);
  AssertFloatEq('BackIn t=0', BackIn(0.0), 0.0, 0.001);
  AssertFloatEq('BackIn t=1', BackIn(1.0), 1.0, 0.001);
  AssertFloatEq('BackOut t=0', BackOut(0.0), 0.0, 0.001);
  AssertFloatEq('BackOut t=1', BackOut(1.0), 1.0, 0.001);
  AssertFloatEq('BackInOut t=0', BackInOut(0.0), 0.0, 0.001);
  AssertFloatEq('BackInOut t=1', BackInOut(1.0), 1.0, 0.001);
  AssertFloatEq('BounceIn t=0', BounceIn(0.0), 0.0, 0.001);
  AssertFloatEq('BounceIn t=1', BounceIn(1.0), 1.0, 0.001);
  AssertFloatEq('BounceOut t=0', BounceOut(0.0), 0.0, 0.001);
  AssertFloatEq('BounceOut t=1', BounceOut(1.0), 1.0, 0.001);
  AssertFloatEq('BounceInOut t=0', BounceInOut(0.0), 0.0, 0.001);
  AssertFloatEq('BounceInOut t=1', BounceInOut(1.0), 1.0, 0.001);

  WriteLn;
  WriteLn('Testing midpoints (t=0.5):');
  // Test that easing functions produce reasonable midpoint values
  AssertFloatEq('Linear mid', Linear(0.5), 0.5, 0.001);
  AssertFloatEq('QuadIn mid', QuadIn(0.5), 0.25, 0.001);
  AssertFloatEq('QuadOut mid', QuadOut(0.5), 0.75, 0.001);
  AssertFloatEq('SineIn mid', SineIn(0.5), 0.293, 0.001);  // 1 - cos(45deg) = 1 - 0.707 = 0.293
  AssertFloatEq('SineOut mid', SineOut(0.5), 0.707, 0.001); // sin(45deg) = 0.707
  AssertFloatEq('BounceOut mid', BounceOut(0.5), 0.766, 0.001); // in range [2.25/2.75, 2.5/2.75]

  WriteLn;
  WriteLn('Tests: ', GTestCount, ' | Pass: ', GPassCount, ' | Fail: ', GFailCount);
  if GFailCount > 0 then
  begin
    WriteLn('*** FAILURES DETECTED ***');
    Halt(1);
  end
  else
    WriteLn('All tests passed!');
end.
