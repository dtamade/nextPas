program test_stream_migration;

{$mode ObjFPC}{$H+}

uses
  nextpas.core.base,
  nextpas.core.exception,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.tls.asn1,
  nextpas.core.tls.base,
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
  CORE_SRC_PREFIX = '../../../src/';
  CERT_ADVANCED_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.cert.advanced.pas';
  CT_LOG_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.ct.log.pas';
  CRL_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.crl.pas';
  OCSP_CACHE_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.ocsp.cache.pas';
  ASN1_PATH = CORE_SRC_PREFIX + 'nextpas.core.crypto.asn1.pas';
  ASN1_SHIM_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.asn1.pas';
  CERT_PINNING_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.cert.pinning.pas';
  DEBUG_UTILS_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.debug.utils.pas';
  TIMEOUT_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.timeout.pas';
  NONBLOCKING_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.nonblocking.pas';
  PENDING_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.pending.pas';
  TLS12_IO_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.tls12.io.pas';
  WEBSOCKET_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.websocket.pas';
  TLS_UTILS_PATH = CORE_SRC_PREFIX + 'nextpas.core.tls.utils.pas';


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
begin
  Result := ReadFileText(AFileName);
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
    'nextpas.core.system.classes is still present in ' + CERT_ADVANCED_PATH);

  LText := LoadText(CT_LOG_PATH);
  Check(Pos('TFileStream', LText) = 0,
    'ct.log removed TFileStream',
    'TFileStream is still present in ' + CT_LOG_PATH);
  Check(Pos('Classes', LText) = 0,
    'ct.log removed Classes uses',
    'nextpas.core.system.classes is still present in ' + CT_LOG_PATH);
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
    'nextpas.core.system.classes is still present in ' + OCSP_CACHE_PATH);

  LText := LoadText(ASN1_PATH);
  Check(Pos('TMemoryStream', LText) = 0,
    'asn1 removed TMemoryStream',
    'TMemoryStream is still present in ' + ASN1_PATH);
  Check(Pos('CreateBytesStream', LText) > 0,
    'asn1 uses CreateBytesStream',
    'CreateBytesStream replacement is missing in ' + ASN1_PATH);
  LText := LoadText(ASN1_SHIM_PATH);
  Check(Pos('nextpas.core.crypto.asn1', LText) > 0,
    'tls.asn1 shims to crypto.asn1',
    'tls.asn1 must re-export nextpas.core.crypto.asn1');

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
    'nextpas.core.system.classes is still present in ' + CERT_PINNING_PATH);

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
  Check(Pos('WrapTStream(', LText) = 0,
    'timeout stream dropped TStream compatibility bridge',
    'TStream bridge still present in ' + TIMEOUT_PATH);

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
  Check(Pos('WrapTStream(', LText) = 0,
    'nonblocking stream dropped TStream compatibility bridge',
    'TStream bridge still present in ' + NONBLOCKING_PATH);

  LText := LoadText(PENDING_PATH);
  Check(Pos('FinishIStream', LText) > 0,
    'pending connect exposes IStream completion',
    'FinishIStream helper is missing in ' + PENDING_PATH);
  Check(Pos('TryFinishIStream', LText) > 0,
    'pending connect exposes TryFinishIStream',
    'TryFinishIStream helper is missing in ' + PENDING_PATH);
  Check(Pos('WrapIStream(', LText) = 0,
    'pending connect dropped IStream→TStream bridge',
    'pending TStream bridge still present in ' + PENDING_PATH);

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
  Check(Pos('WrapTStream(', LText) = 0,
    'tls12.io dropped TStream compatibility bridge',
    'TStream bridge still present in ' + TLS12_IO_PATH);

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
  Check(Pos('WrapTStream(', LText) = 0,
    'websocket dropped TStream compatibility bridge',
    'TStream bridge still present in ' + WEBSOCKET_PATH);

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
    Check(LTimeout.Read(LBuf[0], Longint(Length(LBuf))) = Longint(Length(LBuf)),
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

begin

  TestSourceMigrationContracts;
  TestTimeoutAndNonBlockingIStreamCompatibility;
  TestTLS12AndWebSocketIStreamRoundTrip;
  TestTLSUtilsArraySurface;

  WriteLn;
  WriteLn(Format('Results: %d passed, %d failed', [GPassed, GFailed]));
  if GFailed > 0 then
    Halt(1);
end.
