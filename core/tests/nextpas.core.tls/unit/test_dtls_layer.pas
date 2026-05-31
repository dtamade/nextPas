program test_dtls_layer;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.dtls.layer;

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

procedure TestBuildRecord;
var
  LLayer: TDTLSRecordLayer;
  LPayload, LRecord: TBytes;
begin
  WriteLn('TestBuildRecord');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    SetLength(LPayload, 5);
    LPayload[0] := $01; LPayload[1] := $02; LPayload[2] := $03;
    LPayload[3] := $04; LPayload[4] := $05;

    LRecord := LLayer.BuildRecord(DTLS_CONTENT_TYPE_HANDSHAKE, LPayload);
    Check(Length(LRecord) = 18, 'Record length = 13 header + 5 payload');
    Check(LRecord[0] = DTLS_CONTENT_TYPE_HANDSHAKE, 'Content type');
    Check((LRecord[1] = Hi(DTLS_VERSION_1_2)) and (LRecord[2] = Lo(DTLS_VERSION_1_2)),
      'Version DTLS 1.2');
    Check((LRecord[3] = 0) and (LRecord[4] = 0), 'Epoch 0');
    Check(LRecord[10] = 0, 'Sequence number byte');
    Check((LRecord[11] = 0) and (LRecord[12] = 5), 'Payload length = 5');
    Check(LRecord[13] = $01, 'Payload data[0]');
  finally
    LLayer.Free;
  end;
end;

procedure TestSequenceIncrement;
var
  LLayer: TDTLSRecordLayer;
  LPayload, LR1, LR2: TBytes;
begin
  WriteLn('TestSequenceIncrement');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    SetLength(LPayload, 1);
    LPayload[0] := $FF;
    LR1 := LLayer.BuildRecord(DTLS_CONTENT_TYPE_APPLICATION_DATA, LPayload);
    LR2 := LLayer.BuildRecord(DTLS_CONTENT_TYPE_APPLICATION_DATA, LPayload);
    Check(LR1[10] = 0, 'First record seq = 0');
    Check(LR2[10] = 1, 'Second record seq = 1');
  finally
    LLayer.Free;
  end;
end;

procedure TestParseRecordHeader;
var
  LLayer: TDTLSRecordLayer;
  LPayload, LRecord: TBytes;
  LHeader: TDTLSRecordHeader;
begin
  WriteLn('TestParseRecordHeader');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    SetLength(LPayload, 3);
    LPayload[0] := $AA; LPayload[1] := $BB; LPayload[2] := $CC;
    LRecord := LLayer.BuildRecord(DTLS_CONTENT_TYPE_ALERT, LPayload);

    Check(LLayer.ParseRecordHeader(LRecord, 0, LHeader), 'Parse succeeds');
    Check(LHeader.ContentType = DTLS_CONTENT_TYPE_ALERT, 'Parsed content type');
    Check(LHeader.Version = DTLS_VERSION_1_2, 'Parsed version');
    Check(LHeader.Epoch = 0, 'Parsed epoch');
    Check(LHeader.Length = 3, 'Parsed length');
  finally
    LLayer.Free;
  end;
end;

procedure TestParseRecordHeaderTooShort;
var
  LLayer: TDTLSRecordLayer;
  LData: TBytes;
  LHeader: TDTLSRecordHeader;
begin
  WriteLn('TestParseRecordHeaderTooShort');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    SetLength(LData, 5);
    Check(not LLayer.ParseRecordHeader(LData, 0, LHeader), 'Too short returns false');
  finally
    LLayer.Free;
  end;
end;

procedure TestEpochIncrement;
var
  LLayer: TDTLSRecordLayer;
  LPayload, LRecord: TBytes;
begin
  WriteLn('TestEpochIncrement');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    Check(LLayer.WriteEpoch = 0, 'Initial epoch = 0');
    LLayer.IncrementWriteEpoch;
    Check(LLayer.WriteEpoch = 1, 'Epoch after increment = 1');

    SetLength(LPayload, 1);
    LPayload[0] := $42;
    LRecord := LLayer.BuildRecord(DTLS_CONTENT_TYPE_APPLICATION_DATA, LPayload);
    Check((LRecord[3] = 0) and (LRecord[4] = 1), 'Record uses new epoch');
    Check(LRecord[10] = 0, 'Sequence reset after epoch change');
  finally
    LLayer.Free;
  end;
end;

procedure TestFragmentation;
var
  LLayer: TDTLSRecordLayer;
  LHandshake: TBytes;
  LFragments: TBytesArray;
begin
  WriteLn('TestFragmentation');
  LLayer := TDTLSRecordLayer.Create(50);
  try
    SetLength(LHandshake, 100);
    FillChar(LHandshake[0], 100, $AB);
    LHandshake[0] := 1;
    LFragments := LLayer.FragmentHandshake(LHandshake, 0);
    Check(Length(LFragments) >= 2, 'Multiple fragments for large handshake');

    Check(LFragments[0][0] = DTLS_CONTENT_TYPE_HANDSHAKE, 'Fragment is handshake type');
  finally
    LLayer.Free;
  end;
end;

procedure TestRetransmitQueue;
var
  LLayer: TDTLSRecordLayer;
  LData, LRetransmit: TBytes;
begin
  WriteLn('TestRetransmitQueue');
  LLayer := TDTLSRecordLayer.Create(1400);
  try
    SetLength(LData, 10);
    FillChar(LData[0], 10, $CC);
    LLayer.QueueForRetransmit(LData, 0);

    LRetransmit := LLayer.GetRetransmitData;
    Check(Length(LRetransmit) = 10, 'Retransmit data length');
    Check(LRetransmit[0] = $CC, 'Retransmit data content');
  finally
    LLayer.Free;
  end;
end;

procedure TestMTUProperty;
var
  LLayer: TDTLSRecordLayer;
begin
  WriteLn('TestMTUProperty');
  LLayer := TDTLSRecordLayer.Create(1200);
  try
    Check(LLayer.MTU = 1200, 'Initial MTU');
    LLayer.MTU := 576;
    Check(LLayer.MTU = 576, 'Updated MTU');
  finally
    LLayer.Free;
  end;
end;

begin
  
  LTotal := 0;
  LPassed := 0;

  TestBuildRecord;
  TestSequenceIncrement;
  TestParseRecordHeader;
  TestParseRecordHeaderTooShort;
  TestEpochIncrement;
  TestFragmentation;
  TestRetransmitQueue;
  TestMTUProperty;

  WriteLn;
  WriteLn('DTLS Layer tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
