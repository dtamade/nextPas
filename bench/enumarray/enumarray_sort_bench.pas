{$mode ObjFPC}{$H+}
{$packenum 1}
program enumarray_sort_bench;
uses nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 100000;

type
  TTokenKind = (
    tkIdent, tkNumber, tkString, tkKeyword, tkOperator,
    tkComma, tkSemicolon, tkLParen, tkRParen, tkLBrack,
    tkRBrack, tkDot, tkColon, tkAssign, tkPlus,
    tkMinus, tkStar, tkSlash, tkEqual, tkNotEqual
  );
  TTokenSet = set of TTokenKind;

var
  GTokens: array[0..N-1] of TTokenKind;
  GCopy: array[0..N-1] of TTokenKind;
  GResult: Integer;

procedure QuickSort(var A: array of TTokenKind; ALo, AHi: Integer);
var
  I, J: Integer;
  LPivot, LTmp: TTokenKind;
begin
  if ALo >= AHi then Exit;
  LPivot := A[(ALo + AHi) div 2];
  I := ALo; J := AHi;
  while I <= J do
  begin
    while A[I] < LPivot do Inc(I);
    while A[J] > LPivot do Dec(J);
    if I <= J then
    begin
      LTmp := A[I]; A[I] := A[J]; A[J] := LTmp;
      Inc(I); Dec(J);
    end;
  end;
  if ALo < J then QuickSort(A, ALo, J);
  if I < AHi then QuickSort(A, I, AHi);
end;

procedure SortTokens(const ACtx: IBenchContext);
begin
  Move(GCopy[0], GTokens[0], N);
  QuickSort(GTokens, 0, N-1);
end;

const PUNCT: TTokenSet = [tkComma, tkSemicolon, tkDot, tkColon, tkAssign];

procedure SetFilter(const ACtx: IBenchContext);
var
  I, LCount: Integer;
begin
  LCount := 0;
  for I := 0 to N-1 do
    if GTokens[I] in PUNCT then Inc(LCount);
  GResult := LCount;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  for I := 0 to N-1 do
    GCopy[I] := TTokenKind(19 - (I mod 20));
  Move(GCopy[0], GTokens[0], N);
  LSuite := TBenchSuite.Create('enumarray/sort');
  LSuite.Add('QuickSort/100K', @SortTokens);
  LSuite.Add('SetFilter/100K', @SetFilter);
  LSuite.SetMinSamples(10);
  LSuite.SetMaxIterations(10000);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
