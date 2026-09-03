program test_clone;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base.utils,
  nextpas.core.base,
  nextpas.core.hash.base,
  nextpas.core.hash.intf,
  nextpas.core.hash,
  nextpas.core.test;

procedure TestCloneAlgo(const AName: string; AFactory: IHasher);
var
  H1, H2: IHasher;
  D1, D2: TBytes;
  A, B: array[0..3] of Byte;
begin
  A[0] := $AA; A[1] := $BB; A[2] := $CC; A[3] := $DD;
  B[0] := $11; B[1] := $22; B[2] := $33; B[3] := $44;

  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H1.Write(A[0], 4);
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  CheckTrue(not CompareMem(@D1[0], @D2[0], Length(D1)),
    AName + ': divergent after clone');

  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H1.Write(B[0], 4);
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  CheckTrue(CompareMem(@D1[0], @D2[0], Length(D1)),
    AName + ': same continuation = same result');

  H1 := AFactory;
  H1.Write(A[0], 4);
  H2 := H1.Clone;
  H2.Reset;
  H2.Write(B[0], 4);
  D1 := H1.SumBytes;
  D2 := H2.SumBytes;
  CheckTrue(not CompareMem(@D1[0], @D2[0], Length(D1)),
    AName + ': reset clone independent');
end;

procedure TestMD5; begin TestCloneAlgo('MD5', NewMD5); end;
procedure TestSHA1; begin TestCloneAlgo('SHA1', NewSHA1); end;
procedure TestSHA256; begin TestCloneAlgo('SHA256', NewSHA256); end;
procedure TestSHA384; begin TestCloneAlgo('SHA384', NewSHA384); end;
procedure TestSHA512; begin TestCloneAlgo('SHA512', NewSHA512); end;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('clone');
  LSuite.Test('MD5 clone', @TestMD5);
  LSuite.Test('SHA1 clone', @TestSHA1);
  LSuite.Test('SHA256 clone', @TestSHA256);
  LSuite.Test('SHA384 clone', @TestSHA384);
  LSuite.Test('SHA512 clone', @TestSHA512);
  LRunner := TSuiteRunner.Create('nextpas.core.hash.clone');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then
    Halt(1);
end.
