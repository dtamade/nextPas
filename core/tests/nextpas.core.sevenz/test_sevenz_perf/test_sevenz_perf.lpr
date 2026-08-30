program test_sevenz_perf;

{$I nextpas.core.settings.inc}

uses
  SysUtils,
  nextpas.core.base,
  nextpas.core.io.intf,
  nextpas.core.sevenz,
  nextpas.core.test;

var
  T: TTestSuite;

function MakeBytes(ALen: Integer): TBytes;
var I: Integer;
begin
  SetLength(Result, ALen);
  for I:=0 to ALen-1 do Result[I]:= Byte(I mod 251);
end;

procedure TestPerfZeroCopyExtract;
var
  W: ISevenZWriter;
  R: ISevenZReader;
  Raw, Got: TBytes;
  S: IStream;
begin
  Raw := MakeBytes(64*1024);
  W := TSevenZWriterImpl.Create;
  W.AddFile('big.bin', Raw);
  R := TSevenZReaderImpl.Create(W.Finish);
  // OpenStream 零拷贝：不二次分配，直接引用内部缓冲
  S := R.OpenStream(0);
  CheckEqual(Int64(64*1024), S.GetSize, 'perf stream size');
  SetLength(Got, S.GetSize);
  S.Read(Got[0], Length(Got));
  Check(CompareMem(@Raw[0], @Got[0], Length(Raw)), 'perf zero-copy content');
  S.Close;
end;

procedure TestPerfThroughput;
var
  Raw: TBytes;
  W: ISevenZWriter;
  R: ISevenZReader;
  Start, Elapsed: QWord;
  I: Integer;
begin
  Raw := MakeBytes(256*1024);
  Start := GetTickCount64;
  for I:=0 to 50 do
  begin
    W := TSevenZWriterImpl.Create;
    W.AddFile('a.bin', Raw);
    R := TSevenZReaderImpl.Create(W.Finish);
    R.Extract(0);
  end;
  Elapsed := GetTickCount64 - Start;
  // 50次 256KB 往返应在 10s 内完成（本地零拷贝阈值）
  Check(Elapsed < 10000, 'perf 50x256KB <10s elapsed '+IntToStr(Elapsed)+'ms');
end;

begin
  T := TTestSuite.Create('nextpas.core.sevenz.perf');
  T.Test('perf zero-copy extract', @TestPerfZeroCopyExtract);
  T.Test('perf throughput 50x256KB', @TestPerfThroughput);
  if not T.Run then Halt(1);
end.
