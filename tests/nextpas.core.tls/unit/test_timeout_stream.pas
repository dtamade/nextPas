program test_timeout_stream;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, Classes, nextpas.core.tls.timeout;

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

procedure TestCreateDefaults;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
begin
  WriteLn('TestCreateDefaults');
  LInner := TMemoryStream.Create;
  try
    LTimeout := TTimeoutStream.Create(LInner);
    try
      Check(LTimeout.ReadTimeout = 30000, 'Default read timeout 30s');
      Check(LTimeout.WriteTimeout = 30000, 'Default write timeout 30s');
      Check(LTimeout.ConnectTimeout = 10000, 'Default connect timeout 10s');
      Check(LTimeout.InnerStream = LInner, 'InnerStream property');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestCreateCustomTimeouts;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
begin
  WriteLn('TestCreateCustomTimeouts');
  LInner := TMemoryStream.Create;
  try
    LTimeout := TTimeoutStream.Create(LInner, 5000, 10000);
    try
      Check(LTimeout.ReadTimeout = 5000, 'Custom read timeout');
      Check(LTimeout.WriteTimeout = 10000, 'Custom write timeout');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestReadFromMemoryStream;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
  LBuf: array[0..4] of Byte;
  LRead: Longint;
begin
  WriteLn('TestReadFromMemoryStream');
  LInner := TMemoryStream.Create;
  try
    LInner.Write(PAnsiChar('ABCDE')^, 5);
    LInner.Position := 0;
    LTimeout := TTimeoutStream.Create(LInner);
    try
      LRead := LTimeout.Read(LBuf, 5);
      Check(LRead = 5, 'Read 5 bytes');
      Check(LBuf[0] = Ord('A'), 'Data[0] = A');
      Check(LBuf[4] = Ord('E'), 'Data[4] = E');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestWriteThrough;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
  LData: array[0..2] of Byte;
  LWritten: Longint;
begin
  WriteLn('TestWriteThrough');
  LInner := TMemoryStream.Create;
  try
    LTimeout := TTimeoutStream.Create(LInner);
    try
      LData[0] := $01; LData[1] := $02; LData[2] := $03;
      LWritten := LTimeout.Write(LData, 3);
      Check(LWritten = 3, 'Wrote 3 bytes');
      Check(LInner.Size = 3, 'Inner stream size = 3');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestSeek;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
  LPos: Int64;
begin
  WriteLn('TestSeek');
  LInner := TMemoryStream.Create;
  try
    LInner.Size := 200;
    LTimeout := TTimeoutStream.Create(LInner);
    try
      LPos := LTimeout.Seek(Int64(100), soBeginning);
      Check(LPos = 100, 'Seek to 100');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

procedure TestTimeoutPropertySetters;
var
  LInner: TMemoryStream;
  LTimeout: TTimeoutStream;
begin
  WriteLn('TestTimeoutPropertySetters');
  LInner := TMemoryStream.Create;
  try
    LTimeout := TTimeoutStream.Create(LInner);
    try
      LTimeout.ReadTimeout := 1000;
      LTimeout.WriteTimeout := 2000;
      LTimeout.ConnectTimeout := 3000;
      Check(LTimeout.ReadTimeout = 1000, 'Set read timeout');
      Check(LTimeout.WriteTimeout = 2000, 'Set write timeout');
      Check(LTimeout.ConnectTimeout = 3000, 'Set connect timeout');
    finally
      LTimeout.Free;
    end;
  finally
    LInner.Free;
  end;
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestCreateDefaults;
  TestCreateCustomTimeouts;
  TestReadFromMemoryStream;
  TestWriteThrough;
  TestSeek;
  TestTimeoutPropertySetters;

  WriteLn;
  WriteLn('Timeout Stream tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
