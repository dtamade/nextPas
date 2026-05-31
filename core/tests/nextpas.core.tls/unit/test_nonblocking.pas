program test_nonblocking;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, nextpas.core.tls.nonblocking;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestNonBlockingStreamRead;
var
  LInner: TMemoryStream;
  LNB: TNonBlockingStream;
  LBuf: array[0..9] of Byte;
  LRead: Longint;
begin
  WriteLn('TestNonBlockingStreamRead');
  LInner := TMemoryStream.Create;
  try
    LInner.Write(PAnsiChar('HelloWorld')^, 10);
    LInner.Position := 0;

    LNB := TNonBlockingStream.Create(LInner);
    try
      LRead := LNB.Read(LBuf, 10);
      Check(LRead = 10, 'Read 10 bytes');
      Check(LNB.LastIOResult = ioSuccess, 'LastIOResult = ioSuccess');
      Check(LBuf[0] = Ord('H'), 'Data correct');
    finally
      LNB.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestNonBlockingStreamEOF;
var
  LInner: TMemoryStream;
  LNB: TNonBlockingStream;
  LBuf: array[0..9] of Byte;
  LRead: Longint;
begin
  WriteLn('TestNonBlockingStreamEOF');
  LInner := TMemoryStream.Create;
  try
    LNB := TNonBlockingStream.Create(LInner);
    try
      LRead := LNB.Read(LBuf, 10);
      Check(LRead = 0, 'Read 0 at EOF');
      Check(LNB.LastIOResult = ioClosed, 'LastIOResult = ioClosed');
    finally
      LNB.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestNonBlockingStreamWrite;
var
  LInner: TMemoryStream;
  LNB: TNonBlockingStream;
  LData: array[0..3] of Byte;
  LWritten: Longint;
begin
  WriteLn('TestNonBlockingStreamWrite');
  LInner := TMemoryStream.Create;
  try
    LNB := TNonBlockingStream.Create(LInner);
    try
      LData[0] := $DE; LData[1] := $AD; LData[2] := $BE; LData[3] := $EF;
      LWritten := LNB.Write(LData, 4);
      Check(LWritten = 4, 'Wrote 4 bytes');
      Check(LNB.LastIOResult = ioSuccess, 'Write success');
      Check(LInner.Size = 4, 'Inner stream has 4 bytes');
    finally
      LNB.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestNonBlockingStreamSeek;
var
  LInner: TMemoryStream;
  LNB: TNonBlockingStream;
  LPos: Int64;
begin
  WriteLn('TestNonBlockingStreamSeek');
  LInner := TMemoryStream.Create;
  try
    LInner.Size := 100;
    LNB := TNonBlockingStream.Create(LInner);
    try
      LPos := LNB.Seek(Int64(50), soBeginning);
      Check(LPos = 50, 'Seek to 50');
    finally
      LNB.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestIOResultEnum;
begin
  WriteLn('TestIOResultEnum');
  Check(Ord(ioSuccess) = 0, 'ioSuccess = 0');
  Check(Ord(ioWantRead) = 1, 'ioWantRead = 1');
  Check(Ord(ioWantWrite) = 2, 'ioWantWrite = 2');
  Check(Ord(ioError) = 3, 'ioError = 3');
  Check(Ord(ioClosed) = 4, 'ioClosed = 4');
end;

procedure TestInnerStreamProperty;
var
  LInner: TMemoryStream;
  LNB: TNonBlockingStream;
begin
  WriteLn('TestInnerStreamProperty');
  LInner := TMemoryStream.Create;
  try
    LNB := TNonBlockingStream.Create(LInner);
    try
      Check(LNB.InnerStream = LInner, 'InnerStream property');
    finally
      LNB.Free;
    end;
  finally
    LInner.Free;
  end;
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestNonBlockingStreamRead;
  TestNonBlockingStreamEOF;
  TestNonBlockingStreamWrite;
  TestNonBlockingStreamSeek;
  TestIOResultEnum;
  TestInnerStreamProperty;

  WriteLn;
  WriteLn('NonBlocking tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
