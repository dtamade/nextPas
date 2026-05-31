program test_transport;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.transport;

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

procedure TestMemoryTransportBasicReadWrite;
var
  LTransport: TSSLMemoryTransport;
  LData: array[0..3] of Byte;
  LBytesRead, LBytesWritten: Integer;
  LResult: TSSLTransportResult;
begin
  WriteLn('TestMemoryTransportBasicReadWrite');
  LTransport := TSSLMemoryTransport.Create(1024);
  try
    LData[0] := $DE; LData[1] := $AD; LData[2] := $BE; LData[3] := $EF;
    LResult := LTransport.Write(LData[0], 4, LBytesWritten);
    Check(LResult = trOK, 'Write returns trOK');
    Check(LBytesWritten = 4, 'Write 4 bytes');
    Check(LTransport.Pending = 4, 'Pending = 4');

    FillChar(LData, 4, 0);
    LResult := LTransport.Read(LData[0], 4, LBytesRead);
    Check(LResult = trOK, 'Read returns trOK');
    Check(LBytesRead = 4, 'Read 4 bytes');
    Check((LData[0] = $DE) and (LData[1] = $AD) and (LData[2] = $BE) and (LData[3] = $EF),
      'Data integrity');
  finally
    LTransport.Free;
  end;
end;

procedure TestMemoryTransportEmptyRead;
var
  LTransport: TSSLMemoryTransport;
  LBuf: Byte;
  LBytesRead: Integer;
  LResult: TSSLTransportResult;
begin
  WriteLn('TestMemoryTransportEmptyRead');
  LTransport := TSSLMemoryTransport.Create(64);
  try
    LResult := LTransport.Read(LBuf, 1, LBytesRead);
    Check(LResult = trWantRead, 'Empty read returns trWantRead');
    Check(LBytesRead = 0, 'BytesRead = 0');
  finally
    LTransport.Free;
  end;
end;

procedure TestMemoryTransportFullBuffer;
var
  LTransport: TSSLMemoryTransport;
  LData: array[0..63] of Byte;
  LBytesWritten: Integer;
  LResult: TSSLTransportResult;
begin
  WriteLn('TestMemoryTransportFullBuffer');
  LTransport := TSSLMemoryTransport.Create(32);
  try
    FillChar(LData, 64, $AA);
    LResult := LTransport.Write(LData[0], 64, LBytesWritten);
    Check(LResult = trOK, 'Partial write returns trOK');
    Check(LBytesWritten = 32, 'Only 32 bytes written to 32-byte buffer');

    LResult := LTransport.Write(LData[0], 1, LBytesWritten);
    Check(LResult = trWantWrite, 'Full buffer returns trWantWrite');
    Check(LBytesWritten = 0, 'Zero bytes written when full');
  finally
    LTransport.Free;
  end;
end;

procedure TestMemoryTransportInjectExtract;
var
  LTransport: TSSLMemoryTransport;
  LInjected, LExtracted: TBytes;
begin
  WriteLn('TestMemoryTransportInjectExtract');
  LTransport := TSSLMemoryTransport.Create(256);
  try
    SetLength(LInjected, 5);
    LInjected[0] := 1; LInjected[1] := 2; LInjected[2] := 3;
    LInjected[3] := 4; LInjected[4] := 5;
    LTransport.Inject(LInjected);
    Check(LTransport.Pending = 5, 'Pending after inject');

    LExtracted := LTransport.Extract(3);
    Check(Length(LExtracted) = 3, 'Extract 3 bytes');
    Check((LExtracted[0] = 1) and (LExtracted[1] = 2) and (LExtracted[2] = 3),
      'Extracted data correct');
    Check(LTransport.Pending = 2, 'Pending after partial extract');

    LExtracted := LTransport.Extract(100);
    Check(Length(LExtracted) = 2, 'Extract remaining capped');
    Check((LExtracted[0] = 4) and (LExtracted[1] = 5), 'Remaining data correct');
    Check(LTransport.Pending = 0, 'Pending = 0 after full extract');
  finally
    LTransport.Free;
  end;
end;

procedure TestMemoryTransportFlush;
var
  LTransport: TSSLMemoryTransport;
  LResult: TSSLTransportResult;
begin
  WriteLn('TestMemoryTransportFlush');
  LTransport := TSSLMemoryTransport.Create(64);
  try
    LResult := LTransport.Flush;
    Check(LResult = trOK, 'Flush returns trOK');
  finally
    LTransport.Free;
  end;
end;

procedure TestMemoryTransportPartialRead;
var
  LTransport: TSSLMemoryTransport;
  LData: array[0..9] of Byte;
  LBuf: array[0..2] of Byte;
  LBytesWritten, LBytesRead: Integer;
  I: Integer;
begin
  WriteLn('TestMemoryTransportPartialRead');
  LTransport := TSSLMemoryTransport.Create(256);
  try
    for I := 0 to 9 do LData[I] := Byte(I);
    LTransport.Write(LData[0], 10, LBytesWritten);
    Check(LBytesWritten = 10, 'Wrote 10 bytes');

    LTransport.Read(LBuf[0], 3, LBytesRead);
    Check(LBytesRead = 3, 'Read 3 bytes');
    Check((LBuf[0] = 0) and (LBuf[1] = 1) and (LBuf[2] = 2), 'First 3 bytes');
    Check(LTransport.Pending = 7, 'Pending = 7');
  finally
    LTransport.Free;
  end;
end;

procedure TestSocketTransportCreate;
var
  LTransport: TSSLSocketTransport;
begin
  WriteLn('TestSocketTransportCreate');
  LTransport := TSSLSocketTransport.Create(THandle(-1), True);
  try
    Check(LTransport.Flush = trOK, 'Socket flush returns trOK');
  finally
    LTransport.Free;
  end;
end;

procedure TestTransportResultEnum;
begin
  WriteLn('TestTransportResultEnum');
  Check(Ord(trOK) = 0, 'trOK = 0');
  Check(Ord(trWantRead) = 1, 'trWantRead = 1');
  Check(Ord(trWantWrite) = 2, 'trWantWrite = 2');
  Check(Ord(trClosed) = 3, 'trClosed = 3');
  Check(Ord(trError) = 4, 'trError = 4');
end;

begin
  //SetHeapTraceOutput - use -gh compiler flag instead
  LTotal := 0;
  LPassed := 0;

  TestMemoryTransportBasicReadWrite;
  TestMemoryTransportEmptyRead;
  TestMemoryTransportFullBuffer;
  TestMemoryTransportInjectExtract;
  TestMemoryTransportFlush;
  TestMemoryTransportPartialRead;
  TestSocketTransportCreate;
  TestTransportResultEnum;

  WriteLn;
  WriteLn('Transport tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
