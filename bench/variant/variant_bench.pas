{$mode ObjFPC}{$H+}
program variant_bench;
uses SysUtils, Classes, nextpas.core.base, nextpas.core.time.base, nextpas.core.bench, nextpas.core.bench.intf;

type
  TShapeKind = (skCircle, skRect, skTriangle);

  TShape = record
    case Kind: TShapeKind of
      skCircle: (Radius: Double);
      skRect: (Width, Height: Double);
      skTriangle: (Base, TriHeight: Double);
  end;

var
  GShapes: array[0..9999] of TShape;
  GCounter: Double;

procedure InitShapes;
var
  I: Integer;
begin
  for I := 0 to 9999 do
  begin
    case I mod 3 of
      0: begin GShapes[I].Kind := skCircle; GShapes[I].Radius := I * 0.5; end;
      1: begin GShapes[I].Kind := skRect; GShapes[I].Width := I * 0.5; GShapes[I].Height := I * 0.3; end;
      2: begin GShapes[I].Kind := skTriangle; GShapes[I].Base := I * 0.5; GShapes[I].TriHeight := I * 0.4; end;
    end;
  end;
end;

procedure CalcArea(const ACtx: IBenchContext);
var
  I, J: Integer;
  A: Double;
begin
  A := 0;
  for J := 1 to 1000 do
    for I := 0 to 9999 do
    begin
      case GShapes[I].Kind of
        skCircle: A := A + 3.14159 * GShapes[I].Radius * GShapes[I].Radius;
        skRect: A := A + GShapes[I].Width * GShapes[I].Height;
        skTriangle: A := A + 0.5 * GShapes[I].Base * GShapes[I].TriHeight;
      end;
    end;
  GCounter := GCounter + A;
end;

procedure TagOnly(const ACtx: IBenchContext);
var
  I, J, C: Integer;
begin
  C := 0;
  for J := 1 to 1000 do
    for I := 0 to 9999 do
      case GShapes[I].Kind of
        skCircle: Inc(C);
        skRect: Inc(C, 2);
        skTriangle: Inc(C, 3);
      end;
  GCounter := GCounter + C;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
begin
  InitShapes;

  LSuite := TBenchSuite.Create('Variant')
    .SetMinDuration(TDuration.FromMilliseconds(100))
    .SetMaxIterations(10000)
    .SetMinSamples(6)
    .SetWarmupIters(3);

  LSuite.Add('Area/10M', @CalcArea);
  LSuite.Add('TagOnly/10M', @TagOnly);

  LResults := LSuite.Run;

  WriteLn;
  WriteLn('=== benchstat format ===');
  WriteLn(LResults.ToBenchStat);
end.
