program test_tls13_record_size_limit;

{$mode objfpc}{$H+}{$J-}

uses
  SysUtils,
  nextpas.core.tls.tls13.clienthello,
  nextpas.core.tls.tls13.clienthello.parser,
  nextpas.core.tls.tls13.parser,
  nextpas.core.tls.tls13.wire;

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

function BuildEncryptedExtensionsWithRecordSizeLimit(ALimit: Word): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
begin
  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS_EXTENSION_RECORD_SIZE_LIMIT);
  AppendUInt16(LExtensions, 2);
  AppendUInt16(LExtensions, ALimit);

  SetLength(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

function BuildEncryptedExtensionsWithRawRecordSizeLimit(const ARawData: TBytes): TBytes;
var
  LBody: TBytes;
  LExtensions: TBytes;
begin
  SetLength(LExtensions, 0);
  AppendUInt16(LExtensions, TLS_EXTENSION_RECORD_SIZE_LIMIT);
  AppendUInt16(LExtensions, Word(Length(ARawData)));
  AppendBytes(LExtensions, ARawData);

  SetLength(LBody, 0);
  AppendUInt16(LBody, Word(Length(LExtensions)));
  AppendBytes(LBody, LExtensions);

  Result := nil;
  AppendByte(Result, TLS_HANDSHAKE_TYPE_ENCRYPTED_EXTENSIONS);
  AppendUInt24(Result, Length(LBody));
  AppendBytes(Result, LBody);
end;

procedure AssertClientHelloRecordSizeLimit(const AHandshake: TBytes; const AName: string);
var
  LInfo: TTLS13ClientHelloInfo;
  LError: string;
begin
  Check(TryParseTLS13ClientHelloFromHandshake(AHandshake, LInfo, LError), AName + ' parses');
  Check(LInfo.HasRecordSizeLimit, AName + ' includes record_size_limit');
  Check(LInfo.RecordSizeLimit = TLS13_RECORD_SIZE_LIMIT_DEFAULT, AName + ' uses default limit');
end;

procedure TestBuildExtensionRecordSizeLimit;
var
  LExt: TBytes;
  LRaised: Boolean;
begin
  WriteLn('TestBuildExtensionRecordSizeLimit');
  LExt := BuildExtensionRecordSizeLimit(16384);

  Check(Length(LExt) = 6, 'record_size_limit extension length');
  Check(ReadUInt16(LExt, 0) = TLS_EXTENSION_RECORD_SIZE_LIMIT, 'record_size_limit extension type');
  Check(ReadUInt16(LExt, 2) = 2, 'record_size_limit payload length');
  Check(ReadUInt16(LExt, 4) = 16384, 'record_size_limit payload value');

  LRaised := False;
  try
    LExt := BuildExtensionRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_MIN - 1);
  except
    on E: Exception do
      LRaised := True;
  end;
  Check(LRaised, 'record_size_limit rejects values below RFC minimum');
end;

procedure TestClientHelloIncludesRecordSizeLimit;
var
  LKeyShare: TBytes;
  LCipherSuites: TTLS13CipherSuiteList;
begin
  WriteLn('TestClientHelloIncludesRecordSizeLimit');
  SetLength(LKeyShare, 32);
  FillChar(LKeyShare[0], Length(LKeyShare), $A5);

  AssertClientHelloRecordSizeLimit(
    BuildTLS13ClientHelloHandshake('example.com', 'h2', LKeyShare),
    'default ClientHello'
  );

  SetLength(LCipherSuites, 1);
  LCipherSuites[0] := TLS13_CIPHER_AES_128_GCM_SHA256;
  AssertClientHelloRecordSizeLimit(
    BuildTLS13ClientHelloHandshakeWithCiphers('', '', LKeyShare, LCipherSuites),
    'configured-cipher ClientHello'
  );
end;

procedure TestEncryptedExtensionsRecordSizeLimit;
var
  LInfo: TTLS13EncryptedExtensionsInfo;
  LError: string;
  LRaw: TBytes;
begin
  WriteLn('TestEncryptedExtensionsRecordSizeLimit');
  Check(TryParseTLS13EncryptedExtensions(
    BuildEncryptedExtensionsWithRecordSizeLimit(4096),
    LInfo,
    LError
  ), 'EncryptedExtensions record_size_limit parses');
  Check(LInfo.HasRecordSizeLimit, 'EncryptedExtensions stores record_size_limit presence');
  Check(LInfo.RecordSizeLimit = 4096, 'EncryptedExtensions stores record_size_limit value');

  SetLength(LRaw, 1);
  LRaw[0] := $40;
  Check(not TryParseTLS13EncryptedExtensions(
    BuildEncryptedExtensionsWithRawRecordSizeLimit(LRaw),
    LInfo,
    LError
  ), 'EncryptedExtensions rejects wrong record_size_limit length');

  Check(not TryParseTLS13EncryptedExtensions(
    BuildEncryptedExtensionsWithRecordSizeLimit(TLS13_RECORD_SIZE_LIMIT_MIN - 1),
    LInfo,
    LError
  ), 'EncryptedExtensions rejects record_size_limit below RFC minimum');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestBuildExtensionRecordSizeLimit;
  TestClientHelloIncludesRecordSizeLimit;
  TestEncryptedExtensionsRecordSizeLimit;

  WriteLn;
  WriteLn('TLS13 record_size_limit tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
