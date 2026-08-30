program test_sevenz_fuzz;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.sevenz,
  nextpas.core.test;

var
  T: TTestSuite;

// 确定性伪随机：xorshift32
function PseudoBytes(ALen: Integer; ASeed: UInt32): TBytes;
var
  I: Integer;
  S: UInt32;
begin
  SetLength(Result, ALen);
  S := ASeed;
  for I := 0 to ALen - 1 do
  begin
    {$PUSH}{$Q-}{$R-}
    S := S xor (S shl 13);
    S := S xor (S shr 17);
    S := S xor (S shl 5);
    {$POP}
    Result[I] := Byte(S);
  end;
end;

procedure TestFuzzReaderNeverCrashes;
var
  I: Integer;
  B: TBytes;
begin
  for I := 0 to 200 do
  begin
    B := PseudoBytes((I*131) mod 512, UInt32(I*1103515245+12345));
    try
      TSevenZReaderImpl.Create(B);
      Check(True, 'fuzz ' + IntToStr(I) + ' parse no crash');
    except
      on E: ESevenZError do Check(True, 'fuzz ' + IntToStr(I) + ' expected SevenZError');
      on E: EArgumentError do Check(True, 'fuzz ' + IntToStr(I) + ' arg');
      on E: Exception do Check(False, 'fuzz ' + IntToStr(I) + ' unexpected ' + E.ClassName);
    end;
  end;
end;

procedure TestFuzzWriterReaderRoundtripRandom;
var
  I: Integer;
  W: ISevenZWriter;
  R: ISevenZReader;
  Raw, Got: TBytes;
begin
  for I := 0 to 20 do
  begin
    Raw := PseudoBytes(100 + I*53, UInt32(I*2654435761));
    W := TSevenZWriterImpl.Create;
    W.AddFile('fuzz/' + IntToStr(I) + '.bin', Raw);
    R := TSevenZReaderImpl.Create(W.Finish);
    CheckEqual(Int64(1), Int64(R.EntryCount), 'fuzz rt count');
    Got := R.Extract(0);
    CheckEqual(Int64(Length(Raw)), Int64(Length(Got)), 'fuzz rt len '+IntToStr(I));
    if Length(Raw)>0 then
      Check(CompareMem(@Raw[0], @Got[0], Length(Raw)), 'fuzz rt bytes '+IntToStr(I));
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.sevenz.fuzz');
  T.Test('fuzz reader no crash on random input', @TestFuzzReaderNeverCrashes);
  T.Test('fuzz writer/reader roundtrip random', @TestFuzzWriterReaderRoundtripRandom);
  if not T.Run then Halt(1);
end.
