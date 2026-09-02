program test_vector_tess;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.test,
  nextpas.core.graphics.base,
  nextpas.core.graphics.path,
  nextpas.core.graphics.errors,
  nextpas.core.vector.path,
  nextpas.core.vector.tess;

var T: TTestSuite;

procedure TestFlatten;
var P: TPath; Poly: TPoly;
begin
  P := TPath.New.MoveTo(0,0).LineTo(10,0).LineTo(10,10).LineTo(0,10).Close;
  Poly := PathFlatten(P, 0.25);
  Check(Length(Poly) >= 4, 'flatten rect >=4');
  Check(PolyBounds(Poly).W > 0, 'bounds w');
end;

procedure TestTess;
var P: TPath; Traps: TTrapezoids;
begin
  P := TPath.New.MoveTo(0,0).LineTo(10,0).LineTo(10,10).LineTo(0,10).Close;
  Traps := Tessellate(P);
  Check(Length(Traps) > 0, 'traps >0');
  // inline zero-copy: Tessellate uses Double internal, Single external, no extra alloc per row
  P := TPath.New;
  Traps := Tessellate(P);
  Check(Length(Traps) = 0, 'empty path 0 traps');
end;

procedure TestBool;
var A,B, R: TPath;
begin
  A := TPath.New.MoveTo(0,0).LineTo(10,0).LineTo(10,10).LineTo(0,10).Close;
  B := TPath.New.MoveTo(5,5).LineTo(15,5).LineTo(15,15).LineTo(5,15).Close;
  R := PathUnion(A,B);
  Check(not R.IsEmpty, 'union');
  R := PathIntersect(A,B);
  Check(not R.IsEmpty, 'intersect');
  R := PathDifference(A,B);
  Check(not R.IsEmpty, 'diff');
  R := PathXor(A,B);
  Check(not R.IsEmpty, 'xor');
  // degenerate
  R := PathIntersect(TPath.New, B);
  Check(R.IsEmpty, 'empty intersect');
end;

procedure TestStroke;
var P, S: TPath;
begin
  P := TPath.New.MoveTo(0,0).LineTo(10,0);
  S := PathStroke(P, TStrokeOptions.Create(2));
  Check(not S.IsEmpty, 'stroke');
  S := PathStroke(TPath.New, TStrokeOptions.Create(2));
  Check(S.IsEmpty, 'empty stroke');
  CheckRaises(EVectorError, procedure begin TStrokeOptions.Create(-1); end, 'Width must be');
end;

begin
  T := TTestSuite.Create('nextpas.core.vector');
  T.Test('flatten', @TestFlatten);
  T.Test('tess', @TestTess);
  T.Test('bool', @TestBool);
  T.Test('stroke', @TestStroke);
  if not T.Run then Halt(1);
end.
