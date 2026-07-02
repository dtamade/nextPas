{$mode ObjFPC}{$H+}
program multidim_bench;
uses SysUtils, Classes,
  nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 1000;
  M = 1000;
  ACCESSES = 150;

type
  TMatrix = array[0..N-1, 0..M-1] of Double;

var
  GMatrix: TMatrix;
  GResult: Double;

procedure MultidimRead(const ACtx: IBenchContext);
var
  I, J, K: Integer;
  S: Double;
  LSeed: UInt32;
begin
  LSeed := 12345;
  S := 0.0;
  for K := 1 to ACCESSES do
  begin
    LSeed := LSeed xor (LSeed shl 13);
    LSeed := LSeed xor (LSeed shr 17);
    LSeed := LSeed xor (LSeed shl 5);
    I := (LSeed and $FFFF) mod N;
    J := ((LSeed shr 16) and $FFFF) mod M;
    S := S + GMatrix[I, J];
  end;
  GResult := S;
end;

procedure MultidimWrite(const ACtx: IBenchContext);
var
  I, J, K: Integer;
  LSeed: UInt32;
begin
  LSeed := 12345;
  for K := 1 to ACCESSES do
  begin
    LSeed := LSeed xor (LSeed shl 13);
    LSeed := LSeed xor (LSeed shr 17);
    LSeed := LSeed xor (LSeed shl 5);
    I := (LSeed and $FFFF) mod N;
    J := ((LSeed shr 16) and $FFFF) mod M;
    GMatrix[I, J] := K;
  end;
end;

procedure MultidimLinear(const ACtx: IBenchContext);
var
  I, J: Integer;
  S: Double;
begin
  S := 0.0;
  for I := 0 to 9 do
    for J := 0 to M-1 do
      S := S + GMatrix[I, J];
  GResult := S;
end;

var
  LSuite: IBenchSuite;
begin
  FillChar(GMatrix, SizeOf(GMatrix), 0);
  LSuite := TBenchSuite.Create('Multidim');
  LSuite.Add('RandomRead/150', @MultidimRead);
  LSuite.Add('RandomWrite/150', @MultidimWrite);
  LSuite.Add('LinearScan/10K', @MultidimLinear);
  LSuite.SetMinSamples(10);
  LSuite.SetMaxIterations(100000);
  LSuite.Run;
end.
