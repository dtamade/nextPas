{$mode ObjFPC}{$H+}
{$packenum 1}
program enumarray_bench;
uses nextpas.core.base, nextpas.core.time.base,
  nextpas.core.bench, nextpas.core.bench.intf;

const
  N = 1000000;

type
  TTokenKind = (
    tkIdent, tkNumber, tkString, tkKeyword, tkOperator,
    tkComma, tkSemicolon, tkLParen, tkRParen, tkLBrack,
    tkRBrack, tkDot, tkColon, tkAssign, tkPlus,
    tkMinus, tkStar, tkSlash, tkEqual, tkNotEqual
  );

var
  GTokens: array[0..N-1] of TTokenKind;
  GResult: Int64;

procedure Traverse(const ACtx: IBenchContext);
var
  I: Integer;
  LCount: Int64;
begin
  LCount := 0;
  for I := 0 to N-1 do
    if GTokens[I] in [tkKeyword, tkOperator, tkAssign] then
      Inc(LCount);
  GResult := LCount;
end;

procedure FilterCount(const ACtx: IBenchContext);
var
  I: Integer;
  LCount: Int64;
begin
  LCount := 0;
  for I := 0 to N-1 do
    if Ord(GTokens[I]) >= Ord(tkComma) then
      Inc(LCount);
  GResult := LCount;
end;

procedure SumOrdinals(const ACtx: IBenchContext);
var
  I: Integer;
  LSum: Int64;
begin
  LSum := 0;
  for I := 0 to N-1 do
    LSum := LSum + Ord(GTokens[I]);
  GResult := LSum;
end;

var
  LSuite: IBenchSuite;
  LResults: IBenchResults;
  I: Integer;
begin
  for I := 0 to N-1 do
    GTokens[I] := TTokenKind(I mod 20);
  LSuite := TBenchSuite.Create('enumarray');
  LSuite.Add('Traverse/1M', @Traverse);
  LSuite.Add('FilterCount/1M', @FilterCount);
  LSuite.Add('SumOrdinals/1M', @SumOrdinals);
  LSuite.SetMinSamples(5);
  LSuite.SetMaxIterations(50000);
  LResults := LSuite.Run;
  WriteLn(LResults.ToBenchStat);
end.
