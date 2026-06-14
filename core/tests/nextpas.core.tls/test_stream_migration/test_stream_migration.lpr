program test_stream_migration;

{$mode ObjFPC}{$H+}

uses
  SysUtils, Classes,
  nextpas.core.tls.asn1,
  nextpas.core.tls.crl,
  nextpas.core.tls.debug.utils,
  nextpas.core.tls.ocsp.cache,
  nextpas.core.tls.timeout,
  nextpas.core.tls.nonblocking,
  nextpas.core.tls.pending,
  nextpas.core.tls.tls12.io,
  nextpas.core.tls.websocket,
  nextpas.core.tls.utils,
  nextpas.core.io.intf,
  nextpas.core.io.memory;

const
  CERT_ADVANCED_PATH = 'core/src/nextpas.core.tls.cert.advanced.pas';
  CT_LOG_PATH = 'core/src/nextpas.core.tls.ct.log.pas';
  CRL_PATH = 'core/src/nextpas.core.tls.crl.pas';
  OCSP_CACHE_PATH = 'core/src/nextpas.core.tls.ocsp.cache.pas';
  ASN1_PATH = 'core/src/nextpas.core.tls.asn1.pas';
  CERT_PINNING_PATH = 'core/src/nextpas.core.tls.cert.pinning.pas';
  DEBUG_UTILS_PATH = 'core/src/nextpas.core.tls.debug.utils.pas';
  TIMEOUT_PATH = 'core/src/nextpas.core.tls.timeout.pas';
  NONBLOCKING_PATH = 'core/src/nextpas.core.tls.nonblocking.pas';
  PENDING_PATH = 'core/src/nextpas.core.tls.pending.pas';
  TLS12_IO_PATH = 'core/src/nextpas.core.tls.tls12.io.pas';
  WEBSOCKET_PATH = 'core/src/nextpas.core.tls.websocket.pas';
  TLS_UTILS_PATH = 'core/src/nextpas.core.tls.utils.pas';

  VALID_CRL_PEM =
    '-----BEGIN X509 CRL-----'#10 +
    'MIIBjTB3AgEBMA0GCSqGSIb3DQEBCwUAMDQxEDAOBgNVBAMMB1Rlc3QgQ0ExEzAR'#10 +
    'BgNVBAoMCmZhZmFmYS5zc2wxCzAJBgNVBAYTAlVTFw0yNjAzMjAxNTI5NDZaFw0y'#10 +
    'NjA0MTkxNTI5NDZaoA8wDTALBgNVHRQEBAICEAAwDQYJKoZIhvcNAQELBQADggEB'#10 +
    'ACLaEDdVdaNeX3pTi8a2QjBKXDhZhr3sphOOr+4jGq2BrM4nd3Y/AzSLeykWtch7'#10 +
    'tWtNT0BoNpPP63zD7qkUx3BS9qT/ATFuikWflP2cG3NzMXPLzjdcVF2LJCJf64VI'#10 +
    'FOjEW1F6MDGp0Rciwjj9X52IePexvrmGqHVnDsvn1KVWNEiIP4THom01tUeHn186'#10 +
    '8uLIjDgJ4DD7rSbR+OH1H6d8Dhh14yGBz6xVMA/BaCzTcRKH4VpUKgrw6wPKZAIy'#10 +
    'RAAm1DGds5Z9gTqELwYJVHwv2UpdESsCGIYs7kOuyj+2MYyHhGNEPbUer3IZ7OZN'#10 +
    'A0+1F8BNBBFon7Ehk2j/F6c='#10 +
    '-----END X509 CRL-----';

var
  GPassed: Integer = 0;
  GFailed: Integer = 0;

function BytesOf(const AValues: array of Byte): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AValues));
  for I := 0 to High(AValues) do
    Result[I] := AValues[I];
end;

procedure Check(ACondition: Boolean; const AName: string; const ADetail: string = '');
begin
  if ACondition then
  begin
    Inc(GPassed);
    WriteLn('[PASS] ', AName);
  end
  else
  begin
    Inc(GFailed);
    WriteLn('[FAIL] ', AName);
    if ADetail <> '' then
      WriteLn('       ', ADetail);
  end;
end;

function LoadText(const AFileName: string): string;
var
  LStream: TStringList;
begin
  LStream := TStringList.Create;
  try
    LStream.LoadFromFile(AFileName);
    Result := LStream.Text;
  finally
    LStream.Free;
  end;
end;

function TempFileName(const APrefix: string): string;
begin
  Result := IncludeTrailingPathDelimiter(GetTempDir(False)) +
    APrefix + '_' + IntToStr(GetProcessID) + '_' + IntToStr(Random(1000000));
end;

procedure DeleteIfExists(const AFileName: string);
begin
  if FileExists(AFileName) then
    DeleteFile(AFileName);
end;

procedure TestSourceMigrationContracts;
var
  LText: string;
begin
  WriteLn;
  WriteLn('=== Source migration contracts ===');

  LText := LoadText(CERT_ADVANCED_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'cert.advanced removed TFileStream',
    'TFileStream is still present in ' + CERT_ADVANCED_PATH);
  Check(Pos('FsOpen(', LText) > 0,
    'cert.advanced uses FsOpen',
    'FsOpen replacement is missing in ' + CERT_ADVANCED_PATH);
  Check(Pos('FsCreate(', LText) > 0,
    'cert.advanced uses FsCreate',
    'FsCreate replacement is missing in ' + CERT_ADVANCED_PATH);
  Check(Pos('Classes', LText) = 0,
    'cert.advanced removed Classes uses',
    'Classes is still present in ' + CERT_ADVANCED_PATH);

  LText := LoadText(CT_LOG_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'ct.log removed TFileStream',
    'TFileStream is still present in ' + CT_LOG_PATH);
  Check(Pos('Classes', LText) = 0,
    'ct.log removed Classes uses',
    'Classes is still present in ' + CT_LOG_PATH);
  Check(Pos('FsOpen(', LText) > 0,
    'ct.log uses FsOpen',
    'FsOpen replacement is missing in ' + CT_LOG_PATH);
  Check(Pos('FsCreate(', LText) > 0,
    'ct.log uses FsCreate',
    'FsCreate replacement is missing in ' + CT_LOG_PATH);

  LText := LoadText(CRL_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'crl removed TFileStream',
    'TFileStream is still present in ' + CRL_PATH);
  Check(Pos('FsOpen(', LText) > 0,
    'crl uses FsOpen',
    'FsOpen replacement is missing in ' + CRL_PATH);

  LText := LoadText(OCSP_CACHE_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'ocsp.cache removed TFileStream',
    'TFileStream is still present in ' + OCSP_CACHE_PATH);
  Check(Pos('FsOpen(', LText) > 0,
    'ocsp.cache uses FsOpen',
    'FsOpen replacement is missing in ' + OCSP_CACHE_PATH);
  Check(Pos('FsCreate(', LText) > 0,
    'ocsp.cache uses FsCreate',
    'FsCreate replacement is missing in ' + OCSP_CACHE_PATH);
  Check(Pos('Classes', LText) = 0,
    'ocsp.cache removed Classes uses',
    'Classes is still present in ' + OCSP_CACHE_PATH);

  LText := LoadText(ASN1_PATH);
  Check(Pos('TMemoryStream', LText) = 0,
    'asn1 removed TMemoryStream',
    'TMemoryStream is still present in ' + ASN1_PATH);
  Check(Pos('CreateBytesStream', LText) > 0,
    'asn1 uses CreateBytesStream',
    'CreateBytesStream replacement is missing in ' + ASN1_PATH);

  LText := LoadText(CERT_PINNING_PATH);
  Check(Pos('TStringStream', LText) = 0,
    'cert.pinning removed TStringStream',
    'TStringStream is still present in ' + CERT_PINNING_PATH);
  Check(Pos('Base64Decode', LText) > 0,
    'cert.pinning uses Base64Decode',
    'Base64Decode replacement is missing in ' + CERT_PINNING_PATH);
  Check(Pos('Base64Encode', LText) > 0,
    'cert.pinning uses Base64Encode',
    'Base64Encode replacement is missing in ' + CERT_PINNING_PATH);
  Check(Pos('Classes', LText) = 0,
    'cert.pinning removed Classes uses',
    'Classes is still present in ' + CERT_PINNING_PATH);

  LText := LoadText(DEBUG_UTILS_PATH);
  Check(Pos('class(TMemoryStream)', LText) = 0,
    'debug.utils removed TMemoryStream inheritance',
    'TSSLMemoryStream still inherits from TMemoryStream');
  Check(Pos('FData: TBytes;', LText) > 0,
    'debug.utils uses byte buffer',
    'Standalone byte buffer storage is missing in ' + DEBUG_UTILS_PATH);

  LText := LoadText(TIMEOUT_PATH);
  Check(Pos('class(TInterfacedObject, IStream)', LText) > 0,
    'timeout stream implements IStream',
    'IStream wrapper class is missing in ' + TIMEOUT_PATH);
  Check(Pos('constructor Create(AInner: IStream', LText) > 0,
    'timeout stream exposes IStream constructor',
    'IStream constructor is missing in ' + TIMEOUT_PATH);
  Check(Pos('SetReadDeadline', LText) > 0,
    'timeout stream uses net deadline control',
    'deadline-based timeout wiring is missing in ' + TIMEOUT_PATH);
  Check(Pos('WrapTStream(', LText) > 0,
    'timeout stream keeps TStream compatibility bridge',
    'TStream bridge is missing in ' + TIMEOUT_PATH);

  LText := LoadText(NONBLOCKING_PATH);
  Check(Pos('class(TInterfacedObject, IStream)', LText) > 0,
    'nonblocking stream implements IStream',
    'IStream wrapper class is missing in ' + NONBLOCKING_PATH);
  Check(Pos('constructor Create(AInner: IStream', LText) > 0,
    'nonblocking stream exposes IStream constructor',
    'IStream constructor is missing in ' + NONBLOCKING_PATH);
  Check(Pos('ITcpStreamRuntime', LText) > 0,
    'nonblocking stream uses ITcpStreamRuntime',
    'runtime nonblocking seam is missing in ' + NONBLOCKING_PATH);
  Check(Pos('WrapTStream(', LText) > 0,
    'nonblocking stream keeps TStream compatibility bridge',
    'TStream bridge is missing in ' + NONBLOCKING_PATH);

  LText := LoadText(PENDING_PATH);
  Check(Pos('FinishIStream', LText) > 0,
    'pending connect exposes IStream completion',
    'FinishIStream helper is missing in ' + PENDING_PATH);
  Check(Pos('TryFinishIStream', LText) > 0,
    'pending connect exposes TryFinishIStream',
    'TryFinishIStream helper is missing in ' + PENDING_PATH);
  Check(Pos('WrapIStream(', LText) > 0,
    'pending connect bridges IStream back to TStream',
    'pending TStream bridge is missing in ' + PENDING_PATH);

  LText := LoadText(TLS12_IO_PATH);
  Check(Pos('nextpas.core.io.intf', LText) > 0,
    'tls12.io imports io.intf',
    'io.intf import is missing in ' + TLS12_IO_PATH);
  Check(Pos('function TLS12SendRecord(AStream: IStream', LText) > 0,
    'tls12.io exposes IStream send helper',
    'IStream send helper is missing in ' + TLS12_IO_PATH);
  Check(Pos('function TLS12ReadRecord(AStream: IStream', LText) > 0,
    'tls12.io exposes IStream read helper',
    'IStream read helper is missing in ' + TLS12_IO_PATH);
  Check(Pos('IoReadFull', LText) > 0,
    'tls12.io uses IoReadFull',
    'IoReadFull usage is missing in ' + TLS12_IO_PATH);
  Check(Pos('WrapTStream(', LText) > 0,
    'tls12.io keeps TStream compatibility bridge',
    'TStream bridge is missing in ' + TLS12_IO_PATH);

  LText := LoadText(WEBSOCKET_PATH);
  Check(Pos('nextpas.core.io.intf', LText) > 0,
    'websocket imports io.intf',
    'io.intf import is missing in ' + WEBSOCKET_PATH);
  Check(Pos('constructor Create(AStream: IStream', LText) > 0,
    'websocket exposes IStream constructor',
    'IStream constructor is missing in ' + WEBSOCKET_PATH);
  Check(Pos('IoReadFull', LText) > 0,
    'websocket uses IoReadFull',
    'IoReadFull usage is missing in ' + WEBSOCKET_PATH);
  Check(Pos('WrapTStream(', LText) > 0,
    'websocket keeps TStream compatibility bridge',
    'TStream bridge is missing in ' + WEBSOCKET_PATH);

  LText := LoadText(TLS_UTILS_PATH);
  Check(Pos('TStrings', LText) = 0,
    'tls.utils removed TStrings dependency',
    'TStrings dependency is still present in ' + TLS_UTILS_PATH);
  Check(Pos('TStringList', LText) = 0,
    'tls.utils removed TStringList dependency',
    'TStringList dependency is still present in ' + TLS_UTILS_PATH);
  Check(Pos('ParseDistinguishedName(const ADN: string): TSSLStringArray', LText) > 0,
    'tls.utils returns array-based distinguished names',
    'array-based ParseDistinguishedName signature is missing in ' + TLS_UTILS_PATH);
end;

procedure TestASN1WriterRoundTrip;
var
  LWriter: TASN1Writer;
  LData: TBytes;
  LReader: TASN1Reader;
  LRoot: TASN1Node;
begin
  WriteLn;
  WriteLn('=== ASN.1 roundtrip ===');

  LWriter := TASN1Writer.Create;
  try
    LWriter.BeginSequence;
    LWriter.WriteInteger(42);
    LWriter.WriteUTF8String('stream-migration');
    LWriter.EndSequence;
    LData := LWriter.GetData;
  finally
    LWriter.Free;
  end;

  Check(Length(LData) > 0, 'asn1 writer emitted bytes');

  LReader := TASN1Reader.Create(LData);
  try
    LRoot := LReader.Parse;
    try
      Check(LRoot.IsSequence, 'asn1 parsed sequence');
      Check(LRoot.ChildCount = 2, 'asn1 sequence child count');
      if LRoot.ChildCount >= 2 then
      begin
        Check(LRoot.GetChild(0).AsInteger = 42, 'asn1 integer roundtrip');
        Check(LRoot.GetChild(1).AsString = 'stream-migration', 'asn1 string roundtrip');
      end;
    finally
      LRoot.Free;
    end;
  finally
    LReader.Free;
  end;
end;

procedure TestSSLMemoryStreamBehavior;
var
  LStream: TSSLMemoryStream;
  LBytes: TBytes;
begin
  WriteLn;
  WriteLn('=== TSSLMemoryStream behavior ===');

  LStream := TSSLMemoryStream.Create('migration');
  try
    LStream.WriteByte($12);
    LStream.WriteWord($3456);
    LStream.WriteDWord($789ABCDE);
    LStream.WriteString('ok');

    Check(LStream.Size > 0, 'ssl memory stream size tracks writes');
    LStream.Position := 0;
    Check(LStream.PeekByte = $12, 'ssl memory stream peek byte');
    Check(LStream.ReadByte = $12, 'ssl memory stream read byte');
    Check(LStream.ReadWord = $3456, 'ssl memory stream read word');
    Check(LStream.ReadDWord = $789ABCDE, 'ssl memory stream read dword');
    Check(LStream.ReadString(2) = 'ok', 'ssl memory stream read string');
    Check(LStream.RemainingBytes = 0, 'ssl memory stream remaining bytes');

    LStream.Position := 0;
    LBytes := LStream.ReadBytes(LStream.Size);
    Check(Length(LBytes) = LStream.Size, 'ssl memory stream read bytes count');
    Check(Pos('12', UpperCase(LStream.GetHexDump)) > 0, 'ssl memory stream hex dump');
  finally
    LStream.Free;
  end;
end;

procedure TestTimeoutAndNonBlockingIStreamCompatibility;
var
  LInner: IStream;
  LTimeout: TTimeoutStream;
  LNonBlocking: TNonBlockingStream;
  LBuf: array[0..3] of Byte;
begin
  WriteLn;
  WriteLn('=== IStream wrapper compatibility ===');

  LInner := CreateBytesStreamFrom(BytesOf([$41, $42, $43, $44]));

  LTimeout := TTimeoutStream.Create(LInner);
  try
    Check(LTimeout.Read(LBuf[0], Length(LBuf)) = Length(LBuf),
      'timeout wrapper reads through IStream');
  finally
    LTimeout.Free;
  end;

  LInner := CreateBytesStreamFrom(BytesOf([$10, $20, $30]));
  LNonBlocking := TNonBlockingStream.Create(LInner);
  try
    Check(LNonBlocking.Read(LBuf[0], 3) = 3,
      'nonblocking wrapper reads through IStream');
    Check(LNonBlocking.LastIOResult = ioSuccess,
      'nonblocking wrapper tracks ioSuccess');
  finally
    LNonBlocking.Free;
  end;
end;

procedure TestTLS12AndWebSocketIStreamRoundTrip;
var
  LInner: IStream;
  LContentType: Byte;
  LPayload: TBytes;
  LFrame: TWebSocketFrame;
  LWebSocket: TWebSocketConnection;
begin
  WriteLn;
  WriteLn('=== TLS12/WebSocket IStream roundtrip ===');

  LInner := CreateBytesStream;
  Check(TLS12SendRecord(LInner, 22, BytesOf([$01, $02, $03])),
    'tls12 send record on IStream');
  LInner.Position := 0;
  Check(TLS12ReadRecord(LInner, LContentType, LPayload),
    'tls12 read record on IStream');
  Check(LContentType = 22, 'tls12 content type preserved');
  Check((Length(LPayload) = 3) and (LPayload[2] = $03),
    'tls12 payload preserved');

  LInner := CreateBytesStream;
  LWebSocket := TWebSocketConnection.Create(LInner, False);
  try
    Check(LWebSocket.SendText('Phase3'), 'websocket send text on IStream');
    LInner.Position := 0;
    Check(LWebSocket.ReadFrame(LFrame), 'websocket read frame on IStream');
    Check(LFrame.Opcode = wsOpText, 'websocket opcode preserved');
    Check(Length(LFrame.Payload) = 6, 'websocket payload length preserved');
  finally
    LWebSocket.Free;
  end;
end;

procedure TestTLSUtilsArraySurface;
var
  LParts: TSSLStringArray;
begin
  WriteLn;
  WriteLn('=== TLS utils array surface ===');

  LParts := TSSLUtils.ParseDistinguishedName('CN=example.com, O=nextPas');
  Check(Length(LParts) = 2, 'dn parser returns string array');
  if Length(LParts) = 2 then
    Check(LParts[0] = 'CN=example.com', 'dn parser preserves first component');
end;

procedure TestOCSPCacheFileRoundTrip;
var
  LCache: TOCSPResponseCache;
  LReloaded: TOCSPResponseCache;
  LSerial: TBytes;
  LResponse: TBytes;
  LLoaded: TBytes;
  LFileName: string;
begin
  WriteLn;
  WriteLn('=== OCSP cache file roundtrip ===');

  SetLength(LSerial, 3);
  LSerial[0] := 1;
  LSerial[1] := 2;
  LSerial[2] := 3;

  SetLength(LResponse, 4);
  LResponse[0] := $30;
  LResponse[1] := $82;
  LResponse[2] := $00;
  LResponse[3] := $01;

  LFileName := TempFileName('nextpas_tls_ocsp_cache.bin');
  DeleteIfExists(LFileName);

  LCache := TOCSPResponseCache.Create;
  try
    LCache.Put(LSerial, LResponse, Now, Now + 1);
    Check(LCache.SaveToFile(LFileName), 'ocsp cache save to file');
  finally
    LCache.Free;
  end;

  LReloaded := TOCSPResponseCache.Create;
  try
    Check(LReloaded.LoadFromFile(LFileName), 'ocsp cache load from file');
    Check(LReloaded.Get(LSerial, LLoaded), 'ocsp cache entry reloaded');
    Check(Length(LLoaded) = Length(LResponse), 'ocsp cache response length');
  finally
    LReloaded.Free;
    DeleteIfExists(LFileName);
  end;
end;

procedure TestCRLLoadFromFile;
var
  LCRL: TX509CRL;
  LFileName: string;
  LText: TStringList;
begin
  WriteLn;
  WriteLn('=== CRL load from file ===');

  LFileName := TempFileName('nextpas_tls_test.crl');
  DeleteIfExists(LFileName);
  LText := TStringList.Create;
  try
    LText.Text := VALID_CRL_PEM;
    LText.SaveToFile(LFileName);
  finally
    LText.Free;
  end;

  LCRL := TX509CRL.Create;
  try
    try
      LCRL.LoadFromFile(LFileName);
      Check(True, 'crl load from file');
    except
      on E: Exception do
        Check(False, 'crl load from file', E.ClassName + ': ' + E.Message);
    end;
  finally
    LCRL.Free;
    DeleteIfExists(LFileName);
  end;
end;

begin
  Randomize;

  TestSourceMigrationContracts;
  TestASN1WriterRoundTrip;
  TestSSLMemoryStreamBehavior;
  TestTimeoutAndNonBlockingIStreamCompatibility;
  TestTLS12AndWebSocketIStreamRoundTrip;
  TestTLSUtilsArraySurface;
  TestOCSPCacheFileRoundTrip;
  TestCRLLoadFromFile;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
