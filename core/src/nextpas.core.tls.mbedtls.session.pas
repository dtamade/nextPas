{**
 * Unit: nextpas.core.tls.mbedtls.session
 * Purpose: MbedTLS 会话管理实现
 *
 * 实现 ISSLSession 接口的 MbedTLS 后端。
 * 支持 TLS 会话恢复和会话票据。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.mbedtls.session;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  nextpas.core.base,
  nextpas.core.exception, nextpas.core.text.conv, nextpas.core.system.classes, DateUtils,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.mbedtls.base,
  nextpas.core.tls.mbedtls.native_handle,
  nextpas.core.tls.mbedtls.api;

type
  { TMbedTLSSession - MbedTLS 会话类 }
  TMbedTLSSession = class(TInterfacedObject, ISSLSession, ISSLNativeHandleAccess)
  private
    FSession: Pmbedtls_ssl_session;
    FOwnsSession: Boolean;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FSessionID: string;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FPeerCertificate: ISSLCertificate;
    FSerializedData: TBytes;

    procedure AllocateSession;
    procedure FreeSession;
    function BuildSerializedSessionData(const ANativeData: TBytes): TBytes;
    function TryLoadSerializedSessionData(const AData: TBytes;
      out ANativeData: TBytes; out ASessionID: string;
      out ACreationTime: TDateTime; out ATimeout: Integer;
      out AProtocolVersion: TSSLProtocolVersion; out ACipherName: string;
      out AHasEnvelope: Boolean): Boolean;
    procedure ExtractSessionInfo;
    function GenerateSessionID: string;

  public
    constructor Create; overload;
    constructor Create(ASession: Pmbedtls_ssl_session; AOwnsSession: Boolean = True); overload;
    destructor Destroy; override;

    { ISSLSession - 会话信息 }
    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;

    { ISSLSession - 会话属性 }
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;

    { ISSLSession - 序列化 }
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;

    { ISSLNativeHandleAccess implementation }
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;

    function Clone: ISSLSession;

    { 额外方法 }
    class function FromContext(ASSLCtx: Pmbedtls_ssl_context): ISSLSession;
  end;

implementation

uses
  nextpas.core.text.strings,
  nextpas.core.tls.mbedtls.certificate;

const
  MBEDTLS_SSL_SESSION_SIZE = 512;  // 估算大小
  MBEDTLS_ERR_SSL_BUFFER_TOO_SMALL_LOCAL = -$6A00;
  MBEDTLS_SESSION_SERIALIZATION_MAGIC = 'fafafa-mbedtls-session-v1';
  HEX_DIGITS: array[0..15] of Char = '0123456789ABCDEF';

type
  {$PUSH}
  {$PACKRECORDS C}
  TMbedTLSSessionNativeView = record
    mfl_code: Byte;
    exported: Byte;
    endpoint: Byte;
    tls_version: LongInt;
    start: NativeInt;
    ciphersuite: LongInt;
    id_len: NativeUInt;
    id: array[0..31] of Byte;
  end;
  {$POP}
  PMbedTLSSessionNativeView = ^TMbedTLSSessionNativeView;

function ParseMbedTLSVersionString(const AVersion: string): TSSLProtocolVersion;
begin
  if Pos('TLSv1.3', AVersion) > 0 then
    Exit(sslProtocolTLS13);
  if Pos('TLSv1.2', AVersion) > 0 then
    Exit(sslProtocolTLS12);
  if Pos('TLSv1.1', AVersion) > 0 then
    Exit(sslProtocolTLS11);
  if Pos('TLSv1.0', AVersion) > 0 then
    Exit(sslProtocolTLS10);
  if Pos('SSLv3', AVersion) > 0 then
    Exit(sslProtocolSSL3);
  Result := sslProtocolUnknown;
end;

function HasSessionSerializeHelpers: Boolean;
begin
  Result := Assigned(mbedtls_ssl_session_save);
end;

function HasSessionDeserializeHelpers: Boolean;
begin
  Result := Assigned(mbedtls_ssl_session_load);
end;

function NativeMbedTLSProtocolToSSL(AProtocol: LongInt): TSSLProtocolVersion;
begin
  case AProtocol of
    MBEDTLS_SSL_VERSION_TLS1_2: Result := sslProtocolTLS12;
    MBEDTLS_SSL_VERSION_TLS1_3: Result := sslProtocolTLS13;
  else
    Result := sslProtocolUnknown;
  end;
end;

function HexNibbleValue(ACh: Char; out AValue: Byte): Boolean;
begin
  case ACh of
    '0'..'9':
      begin
        AValue := Byte(Ord(ACh) - Ord('0'));
        Result := True;
      end;
    'A'..'F':
      begin
        AValue := Byte(Ord(ACh) - Ord('A') + 10);
        Result := True;
      end;
    'a'..'f':
      begin
        AValue := Byte(Ord(ACh) - Ord('a') + 10);
        Result := True;
      end;
  else
    AValue := 0;
    Result := False;
  end;
end;

function BytesToHexString(const ABytes: TBytes): string;
var
  I: Integer;
begin
  if Length(ABytes) = 0 then
    Exit('');

  SetLength(Result, Length(ABytes) * 2);
  for I := 0 to High(ABytes) do
  begin
    Result[I * 2 + 1] := HEX_DIGITS[(ABytes[I] shr 4) and $0F];
    Result[I * 2 + 2] := HEX_DIGITS[ABytes[I] and $0F];
  end;
end;

function TryHexStringToBytes(const AHex: string; out ABytes: TBytes): Boolean;
var
  I: Integer;
  LHighNibble: Byte;
  LLowNibble: Byte;
begin
  Result := False;
  SetLength(ABytes, 0);
  if (AHex = '') or ((Length(AHex) mod 2) <> 0) then
    Exit;

  SetLength(ABytes, Length(AHex) div 2);
  for I := 0 to High(ABytes) do
  begin
    if (not HexNibbleValue(AHex[I * 2 + 1], LHighNibble)) or
       (not HexNibbleValue(AHex[I * 2 + 2], LLowNibble)) then
    begin
      SetLength(ABytes, 0);
      Exit;
    end;
    ABytes[I] := (LHighNibble shl 4) or LLowNibble;
  end;

  Result := True;
end;

function TryGetNativeSessionView(ASession: Pmbedtls_ssl_session;
  out ASessionView: PMbedTLSSessionNativeView): Boolean;
begin
  ASessionView := nil;
  if ASession = nil then
    Exit(False);

  ASessionView := PMbedTLSSessionNativeView(ASession);
  Result := ASessionView <> nil;
end;

function TryExtractNativeSessionID(ASession: Pmbedtls_ssl_session;
  out ASessionID: string): Boolean;
var
  LView: PMbedTLSSessionNativeView;
  LIDBytes: TBytes;
begin
  ASessionID := '';
  if not TryGetNativeSessionView(ASession, LView) then
    Exit(False);
  if (LView^.id_len = 0) or (LView^.id_len > Length(LView^.id)) then
    Exit(False);

  SetLength(LIDBytes, LView^.id_len);
  Move(LView^.id[0], LIDBytes[0], LView^.id_len);
  ASessionID := BytesToHexString(LIDBytes);
  Result := ASessionID <> '';
end;

function TryExtractNativeSessionCreationTime(ASession: Pmbedtls_ssl_session;
  out ACreationTime: TDateTime): Boolean;
var
  LView: PMbedTLSSessionNativeView;
begin
  ACreationTime := 0;
  if not TryGetNativeSessionView(ASession, LView) then
    Exit(False);
  if LView^.start <= 0 then
    Exit(False);

  ACreationTime := UnixToDateTime(LView^.start);
  Result := True;
end;

function TryExtractNativeSessionProtocolVersion(ASession: Pmbedtls_ssl_session;
  out AProtocolVersion: TSSLProtocolVersion): Boolean;
var
  LView: PMbedTLSSessionNativeView;
begin
  AProtocolVersion := sslProtocolUnknown;
  if not TryGetNativeSessionView(ASession, LView) then
    Exit(False);

  AProtocolVersion := NativeMbedTLSProtocolToSSL(LView^.tls_version);
  Result := AProtocolVersion <> sslProtocolUnknown;
end;

function TryExtractNativeSessionCipherName(ASession: Pmbedtls_ssl_session;
  out ACipherName: string): Boolean;
var
  LView: PMbedTLSSessionNativeView;
  LCipherSuiteInfo: Pmbedtls_ssl_ciphersuite_info;
begin
  ACipherName := '';
  if not TryGetNativeSessionView(ASession, LView) then
    Exit(False);
  if (LView^.ciphersuite <= 0) or
     (not Assigned(mbedtls_ssl_ciphersuite_from_id)) then
    Exit(False);

  LCipherSuiteInfo := mbedtls_ssl_ciphersuite_from_id(LView^.ciphersuite);
  if (LCipherSuiteInfo = nil) or (LCipherSuiteInfo^.name = nil) then
    Exit(False);

  ACipherName := string(LCipherSuiteInfo^.name);
  Result := ACipherName <> '';
end;

function MaterializeMbedTLSPeerCertificate(ACert: Pmbedtls_x509_crt): ISSLCertificate;
var
  LDER: TBytes;
  LTemp: TMbedTLSCertificate;
  LOwned: TMbedTLSCertificate;
begin
  Result := nil;
  if ACert = nil then
    Exit;

  LTemp := TMbedTLSCertificate.Create(ACert, False);
  try
    LDER := LTemp.SaveToDER;
    if Length(LDER) = 0 then
      Exit;

    LOwned := TMbedTLSCertificate.Create;
    try
      if not LOwned.LoadFromDER(LDER) then
        Exit;
      Result := LOwned;
      LOwned := nil;
    finally
      LOwned.Free;
    end;
  finally
    LTemp.Free;
  end;
end;

{ TMbedTLSSession }

constructor TMbedTLSSession.Create;
begin
  inherited Create;
  FSession := nil;
  FOwnsSession := False;
  FCreationTime := DateTimeNow;
  FTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionID := GenerateSessionID;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := '';
  FPeerCertificate := nil;
  SetLength(FSerializedData, 0);
end;

constructor TMbedTLSSession.Create(ASession: Pmbedtls_ssl_session; AOwnsSession: Boolean);
begin
  Create;
  FSession := ASession;
  FOwnsSession := AOwnsSession;
  if FSession <> nil then
    ExtractSessionInfo;
end;

destructor TMbedTLSSession.Destroy;
begin
  if FOwnsSession then
    FreeSession;
  inherited Destroy;
end;

procedure TMbedTLSSession.AllocateSession;
begin
  if FSession <> nil then
    FreeSession;

  GetMem(FSession, MBEDTLS_SSL_SESSION_SIZE);
  FillChar(FSession^, MBEDTLS_SSL_SESSION_SIZE, 0);

  if Assigned(mbedtls_ssl_session_init) then
    mbedtls_ssl_session_init(FSession);

  FOwnsSession := True;
end;

procedure TMbedTLSSession.FreeSession;
begin
  if FSession <> nil then
  begin
    if Assigned(mbedtls_ssl_session_free) then
      mbedtls_ssl_session_free(FSession);
    FreeMem(FSession);
    FSession := nil;
  end;
end;

function TMbedTLSSession.BuildSerializedSessionData(const ANativeData: TBytes): TBytes;
var
  LCreatedUnix: Int64;
begin
  Result := nil;
  if Length(ANativeData) = 0 then
    Exit;

    if FCreationTime > 0 then
      LCreatedUnix := DateTimeToUnix(FCreationTime)
    else
      LCreatedUnix := 0;

    Result := BytesOf(UTF8String(
      'magic=' + MBEDTLS_SESSION_SERIALIZATION_MAGIC + sLineBreak +
      'id=' + FSessionID + sLineBreak +
      'created_unix=' + IntToStr(LCreatedUnix) + sLineBreak +
      'timeout=' + IntToStr(FTimeout) + sLineBreak +
      'protocol=' + IntToStr(Ord(FProtocolVersion)) + sLineBreak +
      'cipher=' + FCipherName + sLineBreak +
      'native_hex=' + BytesToHexString(ANativeData) + sLineBreak
    ));
  end;

function TMbedTLSSession.TryLoadSerializedSessionData(const AData: TBytes;
  out ANativeData: TBytes; out ASessionID: string;
  out ACreationTime: TDateTime; out ATimeout: Integer;
  out AProtocolVersion: TSSLProtocolVersion; out ACipherName: string;
  out AHasEnvelope: Boolean): Boolean;
var

  LText: RawByteString;
  LCreatedUnix: Int64;
  LProtocolOrdinal: Integer;
  LNativeHex: string;
  LPrefix: RawByteString;
  LLines: TStringArray;
  LPairs: TStringPairArray;
begin
  Result := False;
  AHasEnvelope := False;
  SetLength(ANativeData, 0);
  ASessionID := '';
  ACreationTime := 0;
  ATimeout := 0;
  AProtocolVersion := sslProtocolUnknown;
  ACipherName := '';
  if Length(AData) = 0 then
    Exit;

  LPrefix := RawByteString('magic=' + MBEDTLS_SESSION_SERIALIZATION_MAGIC);
  if Length(AData) < Length(LPrefix) then
    Exit;
  if not CompareMem(@AData[0], @LPrefix[1], Length(LPrefix)) then
    Exit;

  AHasEnvelope := True;
  SetString(LText, PAnsiChar(@AData[0]), Length(AData));

  LLines := StringsParseLines(string(LText));
  LPairs := StringsParseKeyValues(string(LText));
  try

    if StringPairsGet(LPairs, 'magic') <> MBEDTLS_SESSION_SERIALIZATION_MAGIC then
      Exit;

    ASessionID := StringPairsGet(LPairs, 'id');
    if ASessionID = '' then
      Exit;
    if not TryStrToInt64(StringPairsGet(LPairs, 'created_unix'), LCreatedUnix) then
      Exit;
    if not TryStrToInt(StringPairsGet(LPairs, 'timeout'), ATimeout) then
      Exit;
    if not TryStrToInt(StringPairsGet(LPairs, 'protocol'), LProtocolOrdinal) then
      Exit;
    if (LProtocolOrdinal < Ord(Low(TSSLProtocolVersion))) or
       (LProtocolOrdinal > Ord(High(TSSLProtocolVersion))) then
      Exit;

    LNativeHex := StringPairsGet(LPairs, 'native_hex');
    if not TryHexStringToBytes(LNativeHex, ANativeData) then
      Exit;
    if Length(ANativeData) = 0 then
      Exit;

    if LCreatedUnix > 0 then
      ACreationTime := UnixToDateTime(LCreatedUnix)
    else
      ACreationTime := 0;
    AProtocolVersion := TSSLProtocolVersion(LProtocolOrdinal);
    ACipherName := StringPairsGet(LPairs, 'cipher');
    Result := True;
  except
    on E: Exception do
      Exit;
  end;
end;

procedure TMbedTLSSession.ExtractSessionInfo;
var
  LSessionID: string;
  LCreationTime: TDateTime;
  LProtocolVersion: TSSLProtocolVersion;
  LCipherName: string;
begin
  if FSession = nil then Exit;

  FSessionID := GenerateSessionID;
  FCreationTime := DateTimeNow;
  FProtocolVersion := sslProtocolTLS12;
  FCipherName := '';

  if TryExtractNativeSessionID(FSession, LSessionID) then
    FSessionID := LSessionID;
  if TryExtractNativeSessionCreationTime(FSession, LCreationTime) then
    FCreationTime := LCreationTime;
  if TryExtractNativeSessionProtocolVersion(FSession, LProtocolVersion) then
    FProtocolVersion := LProtocolVersion;
  if TryExtractNativeSessionCipherName(FSession, LCipherName) then
    FCipherName := LCipherName;
end;

function TMbedTLSSession.GenerateSessionID: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
end;

function TMbedTLSSession.GetID: string;
begin
  Result := FSessionID;
end;

function TMbedTLSSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TMbedTLSSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TMbedTLSSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
end;

function TMbedTLSSession.IsValid: Boolean;
var
  LElapsed: Integer;
begin
  Result := False;
  if FSession = nil then Exit;

  LElapsed := DateTimeSecondsBetween(DateTimeNow, FCreationTime);
  Result := LElapsed < FTimeout;
end;

function TMbedTLSSession.IsResumable: Boolean;
begin
  Result := IsValid and (FSession <> nil);
end;

function TMbedTLSSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TMbedTLSSession.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TMbedTLSSession.GetPeerCertificate: ISSLCertificate;
begin
  if FPeerCertificate <> nil then
    Result := FPeerCertificate.Clone
  else
    Result := nil;
end;

function TMbedTLSSession.Serialize: TBytes;
var
  LRequiredSize: NativeUInt;
  LResultCode: Integer;
  LNativeData: TBytes;
begin
  if (Length(FSerializedData) > 0) and
     ((FSession = nil) or not HasSessionSerializeHelpers()) then
    Exit(Copy(FSerializedData));

  SetLength(Result, 0);
  if (FSession = nil) or not HasSessionSerializeHelpers() then
    Exit;

  LRequiredSize := 0;
  LResultCode := mbedtls_ssl_session_save(FSession, nil, 0, @LRequiredSize);
  if (LResultCode <> 0) and
     (LResultCode <> MBEDTLS_ERR_SSL_BUFFER_TOO_SMALL_LOCAL) then
    Exit;

  if LRequiredSize = 0 then
    Exit;

  SetLength(Result, LRequiredSize);
  LResultCode := mbedtls_ssl_session_save(FSession, @Result[0],
    Length(Result), @LRequiredSize);
  if LResultCode <> 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(LNativeData, LRequiredSize);
  Move(Result[0], LNativeData[0], LRequiredSize);
  if FCipherName <> '' then
    Result := BuildSerializedSessionData(LNativeData)
  else
    Result := LNativeData;
  FSerializedData := Copy(Result);
end;

function TMbedTLSSession.Deserialize(const AData: TBytes): Boolean;
var
  LSession: Pmbedtls_ssl_session;
  LNativeData: TBytes;
  LSessionID: string;
  LCreationTime: TDateTime;
  LTimeout: Integer;
  LProtocolVersion: TSSLProtocolVersion;
  LCipherName: string;
  LHasEnvelope: Boolean;
begin
  Result := False;
  if (Length(AData) = 0) or not HasSessionDeserializeHelpers() then
    Exit;

  if not TryLoadSerializedSessionData(AData, LNativeData, LSessionID,
    LCreationTime, LTimeout, LProtocolVersion, LCipherName, LHasEnvelope) then
  begin
    if LHasEnvelope then
      Exit;
    LNativeData := Copy(AData);
  end;

  LSession := nil;
  GetMem(LSession, MBEDTLS_SSL_SESSION_SIZE);
  FillChar(LSession^, MBEDTLS_SSL_SESSION_SIZE, 0);

  if Assigned(mbedtls_ssl_session_init) then
    mbedtls_ssl_session_init(LSession);

  if mbedtls_ssl_session_load(LSession, @LNativeData[0], Length(LNativeData)) <> 0 then
  begin
    if Assigned(mbedtls_ssl_session_free) then
      mbedtls_ssl_session_free(LSession);
    FreeMem(LSession);
    Exit;
  end;

  if FOwnsSession then
    FreeSession;

  FSession := LSession;
  FOwnsSession := True;
  ExtractSessionInfo;
  if LHasEnvelope then
  begin
    if LSessionID <> '' then
      FSessionID := LSessionID;
    if LCreationTime > 0 then
      FCreationTime := LCreationTime;
    FTimeout := LTimeout;
    if LProtocolVersion <> sslProtocolUnknown then
      FProtocolVersion := LProtocolVersion;
    if LCipherName <> '' then
      FCipherName := LCipherName;
    FSerializedData := Copy(AData);
  end
  else
    FSerializedData := Copy(LNativeData);
  FPeerCertificate := nil;
  Result := True;
end;

function TMbedTLSSession.GetNativeHandle: Pointer;
begin
  Result := FSession;
end;

function TMbedTLSSession.GetBackendType: TSSLLibraryType;
begin
  Result := sslMbedTLS;
end;

function TMbedTLSSession.IsNativeHandleValid: Boolean;
begin
  Result := (FSession <> nil);
end;

function TMbedTLSSession.Clone: ISSLSession;
var
  LClone: TMbedTLSSession;
  LSerialized: TBytes;
begin
  Result := nil;
  LClone := TMbedTLSSession.Create;
  try
    LClone.FCreationTime := FCreationTime;
    LClone.FTimeout := FTimeout;
    LClone.FSessionID := FSessionID;
    LClone.FProtocolVersion := FProtocolVersion;
    LClone.FCipherName := FCipherName;
    if FPeerCertificate <> nil then
      LClone.FPeerCertificate := FPeerCertificate.Clone
    else
      LClone.FPeerCertificate := nil;
    LClone.FSerializedData := Copy(FSerializedData);

    if FSession <> nil then
    begin
      LSerialized := Serialize;
      if (Length(LSerialized) = 0) or (not LClone.Deserialize(LSerialized)) then
        Exit(nil);

      LClone.FCreationTime := FCreationTime;
      LClone.FTimeout := FTimeout;
      LClone.FSessionID := FSessionID;
      LClone.FProtocolVersion := FProtocolVersion;
      LClone.FCipherName := FCipherName;
      if FPeerCertificate <> nil then
        LClone.FPeerCertificate := FPeerCertificate.Clone
      else
        LClone.FPeerCertificate := nil;
      LClone.FSerializedData := Copy(LSerialized);
    end;

    Result := LClone;
    LClone := nil;
  finally
    LClone.Free;
  end;
end;

class function TMbedTLSSession.FromContext(ASSLCtx: Pmbedtls_ssl_context): ISSLSession;
var
  LSession: TMbedTLSSession;
  LVersion: PAnsiChar;
  LCipherName: PAnsiChar;
  LPeerCert: Pmbedtls_x509_crt;
  LParsedVersion: TSSLProtocolVersion;
begin
  Result := nil;
  if ASSLCtx = nil then Exit;
  if not Assigned(mbedtls_ssl_get_session) then Exit;

  LSession := TMbedTLSSession.Create;
  LSession.AllocateSession;

  if mbedtls_ssl_get_session(ASSLCtx, LSession.FSession) = 0 then
  begin
    LSession.ExtractSessionInfo;

    if Assigned(mbedtls_ssl_get_version) then
    begin
      LVersion := mbedtls_ssl_get_version(ASSLCtx);
      if LVersion <> nil then
      begin
        LParsedVersion := ParseMbedTLSVersionString(string(LVersion));
        if LParsedVersion <> sslProtocolUnknown then
          LSession.FProtocolVersion := LParsedVersion;
      end;
    end;

    if Assigned(mbedtls_ssl_get_ciphersuite) then
    begin
      LCipherName := mbedtls_ssl_get_ciphersuite(ASSLCtx);
      if LCipherName <> nil then
        LSession.FCipherName := string(LCipherName);
    end;

    if Assigned(mbedtls_ssl_get_peer_cert) then
    begin
      LPeerCert := mbedtls_ssl_get_peer_cert(ASSLCtx);
      if LPeerCert <> nil then
        LSession.FPeerCertificate := MaterializeMbedTLSPeerCertificate(LPeerCert);
    end;

    Result := LSession;
  end
  else
  begin
    LSession.Free;
    Result := nil;
  end;
end;

end.
