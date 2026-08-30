program test_sevenz_stress;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.sevenz,
  nextpas.core.test;

var
  T: TTestSuite;

function MakeBytes(APattern, ALen: Integer): TBytes;
var I: Integer;
begin
  SetLength(Result, ALen);
  for I:=0 to ALen-1 do Result[I]:= Byte((APattern + I) mod 251);
end;

procedure TestStressManyFilesSolid;
var
  W: ISevenZWriter;
  R: ISevenZReader;
  I: Integer;
  Got: TBytes;
begin
  W := TSevenZWriterImpl.Create;
  for I:=0 to 500 do
    W.AddFile('file_' + IntToStr(I) + '.bin', MakeBytes(I, 200 + I mod 100));
  R := TSevenZReaderImpl.Create(W.Finish);
  CheckEqual(Int64(501), Int64(R.EntryCount), 'stress 501 entries');
  for I:=0 to 500 do
  begin
    Got := R.Extract(I);
    CheckEqual(Int64(200 + I mod 100), Int64(Length(Got)), 'stress len '+IntToStr(I));
  end;
end;

procedure TestStressFolderSplit;
var
  W: ISevenZWriter;
  R: ISevenZReader;
  I: Integer;
begin
  W := TSevenZWriterImpl.Create;
  W.SetFolderLimits(4096, 10);
  for I:=0 to 100 do
    W.AddFile('f'+IntToStr(I)+'.dat', MakeBytes(I*3, 1024));
  R := TSevenZReaderImpl.Create(W.Finish);
  CheckEqual(Int64(101), Int64(R.EntryCount), 'stress folder split count');
  Check(Length(R.Extract(50)) = 1024, 'stress folder split sample');
end;

procedure TestStressRepeatedRoundtrip;
var
  I: Integer;
  W: ISevenZWriter;
  R: ISevenZReader;
  Raw: TBytes;
begin
  Raw := MakeBytes(7, 8192);
  for I:=0 to 200 do
  begin
    W := TSevenZWriterImpl.Create;
    W.AddFile('a.bin', Raw);
    R := TSevenZReaderImpl.Create(W.Finish);
    Check(Length(R.Extract(0)) = 8192, 'stress repeat '+IntToStr(I));
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.sevenz.stress');
  T.Test('stress many files solid', @TestStressManyFilesSolid);
  T.Test('stress folder split', @TestStressFolderSplit);
  T.Test('stress repeated roundtrip 200', @TestStressRepeatedRoundtrip);
  if not T.Run then Halt(1);
end.
