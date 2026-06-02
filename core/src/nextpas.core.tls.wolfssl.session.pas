{**
 * Unit: nextpas.core.tls.wolfssl.session
 * Purpose: WolfSSL 会话管理实现
 *
 * 实现 ISSLSession 接口的 WolfSSL 后端。
 * 支持 TLS 会话恢复和会话票据。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2026-01-10
 *}

unit nextpas.core.tls.wolfssl.session;

{$mode objfpc}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, Classes, DateUtils, ctypes,
  nextpas.core.time,
  nextpas.core.tls.base,
  nextpas.core.tls.wolfssl.base,
  nextpas.core.tls.wolfssl.native_handle,
  nextpas.core.tls.wolfssl.api;

type
  { TWolfSSLSession - WolfSSL 会话类 }
  TWolfSSLSession = class(TInterfacedObject, ISSLSession, ISSLNativeHandleAccess)
  private
    FSession: PWOLFSSL_SESSION;
    FOwnsSession: Boolean;
    FCreationTime: TDateTime;
    FTimeout: Integer;
    FSessionID: string;
    FProtocolVersion: TSSLProtocolVersion;
    FCipherName: string;
    FPeerCertificate: ISSLCertificate;
    FSerializedData: TBytes;

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
    constructor Create(ASession: PWOLFSSL_SESSION; AOwnsSession: Boolean = True); overload;
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
    class function FromConnection(ASSL: PWOLFSSL): ISSLSession;
  end;

implementation

uses
  nextpas.core.tls.wolfssl.certificate;

const
  WOLFSSL_SESSION_SERIALIZATION_MAGIC = 'fafafa-wolfssl-session-v1';
  HEX_DIGITS: array[0..15] of Char = '0123456789ABCDEF';

function ParseWolfSSLVersionString(const AVersion: string): TSSLProtocolVersion;
begin
  if Pos('TLSv1.3', AVersion) > 0 then
    Exit(sslProtocolTLS13);
  if Pos('TLSv1.2', AVersion) > 0 then
    Exit(sslProtocolTLS12);
  if Pos('TLSv1.1', AVersion) > 0 then
    Exit(sslProtocolTLS11);
  if Pos('TLSv1', AVersion) > 0 then
    Exit(sslProtocolTLS10);
  Result := sslProtocolUnknown;
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

function TryExtractNativeSessionID(ASession: PWOLFSSL_SESSION;
  out ASessionID: string): Boolean;
var
  LIDLen: Cardinal;
  LIDPtr: PByte;
  I: Cardinal;
begin
  ASessionID := '';
  if (ASession = nil) or (not Assigned(wolfSSL_SESSION_get_id)) then
    Exit(False);

  LIDLen := 0;
  LIDPtr := wolfSSL_SESSION_get_id(ASession, @LIDLen);
  if (LIDPtr = nil) or (LIDLen = 0) then
    Exit(False);

  SetLength(ASessionID, LIDLen * 2);
  for I := 0 to LIDLen - 1 do
  begin
    ASessionID[I * 2 + 1] := HEX_DIGITS[(PByte(LIDPtr + I)^ shr 4) and $0F];
    ASessionID[I * 2 + 2] := HEX_DIGITS[PByte(LIDPtr + I)^ and $0F];
  end;
  Result := True;
end;

function TryExtractNativeSessionCreationTime(ASession: PWOLFSSL_SESSION;
  out ACreationTime: TDateTime): Boolean;
var
  LUnixTime: clong;
begin
  ACreationTime := 0;
  if (ASession = nil) or (not Assigned(wolfSSL_SESSION_get_time)) then
    Exit(False);

  LUnixTime := wolfSSL_SESSION_get_time(ASession);
  if LUnixTime <= 0 then
    Exit(False);

  ACreationTime := UnixToDateTime(LUnixTime);
  Result := True;
end;

function TryExtractNativeSessionTimeout(ASession: PWOLFSSL_SESSION;
  out ATimeout: Integer): Boolean;
var
  LTimeout: clong;
begin
  ATimeout := 0;
  if (ASession = nil) or (not Assigned(wolfSSL_SESSION_get_timeout)) then
    Exit(False);

  LTimeout := wolfSSL_SESSION_get_timeout(ASession);
  if LTimeout <= 0 then
    Exit(False);

  ATimeout := LTimeout;
  Result := True;
end;

function TryExtractNativeSessionCipherName(ASession: PWOLFSSL_SESSION;
  out ACipherName: string): Boolean;
var
  LName: PAnsiChar;
begin
  ACipherName := '';
  if (ASession = nil) or (not Assigned(wolfSSL_SESSION_CIPHER_get_name)) then
    Exit(False);

  LName := wolfSSL_SESSION_CIPHER_get_name(ASession);
  if LName = nil then
    Exit(False);

  ACipherName := string(LName);
  Result := ACipherName <> '';
end;

function DuplicateWolfSSLSessionHandle(ASession: PWOLFSSL_SESSION): PWOLFSSL_SESSION;
var
  LLen: Integer;
  LBufPtr: PByte;
  LSerialized: TBytes;
begin
  Result := nil;
  if ASession = nil then
    Exit;

  if Assigned(wolfSSL_SESSION_dup) then
    Exit(wolfSSL_SESSION_dup(ASession));

  if not Assigned(wolfSSL_i2d_SSL_SESSION) or
     not Assigned(wolfSSL_d2i_SSL_SESSION) then
    Exit;

  LLen := wolfSSL_i2d_SSL_SESSION(ASession, nil);
  if LLen <= 0 then
    Exit;

  SetLength(LSerialized, LLen);
  LBufPtr := @LSerialized[0];
  LLen := wolfSSL_i2d_SSL_SESSION(ASession, @LBufPtr);
  if LLen <= 0 then
    Exit;

  SetLength(LSerialized, LLen);
  LBufPtr := @LSerialized[0];
  Result := wolfSSL_d2i_SSL_SESSION(nil, @LBufPtr, Length(LSerialized));
end;

function MaterializeWolfSSLCertificate(AX509: PWOLFSSL_X509): ISSLCertificate;
var
  LDER: TBytes;
  LTemp: TWolfSSLCertificate;
  LOwned: TWolfSSLCertificate;
begin
  Result := nil;
  if AX509 = nil then
    Exit;

  LTemp := TWolfSSLCertificate.Create(AX509);
  try
    LDER := LTemp.SaveToDER;
    if Length(LDER) = 0 then
      Exit;

    LOwned := TWolfSSLCertificate.Create;
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

{ TWolfSSLSession }

constructor TWolfSSLSession.Create;
begin
  inherited Create;
  FSession := nil;
  FOwnsSession := False;
  FCreationTime := DateTimeNow;
  FTimeout := SSL_DEFAULT_SESSION_TIMEOUT;
  FSessionID := GenerateSessionID;  // 总是生成会话 ID
  FProtocolVersion := sslProtocolUnknown;
  FCipherName := 'unknown';
  FPeerCertificate := nil;
  SetLength(FSerializedData, 0);
end;

constructor TWolfSSLSession.Create(ASession: PWOLFSSL_SESSION; AOwnsSession: Boolean);
begin
  Create;
  FSession := ASession;
  FOwnsSession := AOwnsSession;
  if FSession <> nil then
    ExtractSessionInfo;
end;

destructor TWolfSSLSession.Destroy;
begin
  if FOwnsSession and (FSession <> nil) then
  begin
    if Assigned(wolfSSL_SESSION_free) then
      wolfSSL_SESSION_free(FSession);
    FSession := nil;
  end;
  inherited Destroy;
end;

function TWolfSSLSession.BuildSerializedSessionData(
  const ANativeData: TBytes): TBytes;
var
  LData: TStringList;
  LCreatedUnix: Int64;
begin
  SetLength(Result, 0);
  if Length(ANativeData) = 0 then
    Exit;

  LData := TStringList.Create;
  try
    if FCreationTime > 0 then
      LCreatedUnix := DateTimeToUnix(FCreationTime)
    else
      LCreatedUnix := 0;

    LData.Values['magic'] := WOLFSSL_SESSION_SERIALIZATION_MAGIC;
    LData.Values['id'] := FSessionID;
    LData.Values['created_unix'] := IntToStr(LCreatedUnix);
    LData.Values['timeout'] := IntToStr(FTimeout);
    LData.Values['protocol'] := IntToStr(Ord(FProtocolVersion));
    LData.Values['cipher'] := FCipherName;
    LData.Values['native_hex'] := BytesToHexString(ANativeData);
    Result := BytesOf(UTF8String(LData.Text));
  finally
    LData.Free;
  end;
end;

function TWolfSSLSession.TryLoadSerializedSessionData(const AData: TBytes;
  out ANativeData: TBytes; out ASessionID: string;
  out ACreationTime: TDateTime; out ATimeout: Integer;
  out AProtocolVersion: TSSLProtocolVersion; out ACipherName: string;
  out AHasEnvelope: Boolean): Boolean;
var
  LData: TStringList;
  LText: RawByteString;
  LCreatedUnix: Int64;
  LProtocolOrdinal: Integer;
  LNativeHex: string;
  LPrefix: RawByteString;
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

  LPrefix := RawByteString('magic=' + WOLFSSL_SESSION_SERIALIZATION_MAGIC);
  if Length(AData) < Length(LPrefix) then
    Exit;
  if not CompareMem(@AData[0], @LPrefix[1], Length(LPrefix)) then
    Exit;

  AHasEnvelope := True;
  SetString(LText, PAnsiChar(@AData[0]), Length(AData));
  LData := TStringList.Create;
  try
    LData.Text := string(UTF8String(LText));
    if LData.Values['magic'] <> WOLFSSL_SESSION_SERIALIZATION_MAGIC then
      Exit;

    ASessionID := LData.Values['id'];
    if ASessionID = '' then
      Exit;
    if not TryStrToInt64(LData.Values['created_unix'], LCreatedUnix) then
      Exit;
    if not TryStrToInt(LData.Values['timeout'], ATimeout) then
      Exit;
    if not TryStrToInt(LData.Values['protocol'], LProtocolOrdinal) then
      Exit;
    if (LProtocolOrdinal < Ord(Low(TSSLProtocolVersion))) or
       (LProtocolOrdinal > Ord(High(TSSLProtocolVersion))) then
      Exit;

    LNativeHex := LData.Values['native_hex'];
    if not TryHexStringToBytes(LNativeHex, ANativeData) then
      Exit;
    if Length(ANativeData) = 0 then
      Exit;

    if LCreatedUnix > 0 then
      ACreationTime := UnixToDateTime(LCreatedUnix)
    else
      ACreationTime := 0;
    AProtocolVersion := TSSLProtocolVersion(LProtocolOrdinal);
    ACipherName := LData.Values['cipher'];
    Result := True;
  finally
    LData.Free;
  end;
end;

procedure TWolfSSLSession.ExtractSessionInfo;
var
  LSessionID: string;
  LCreationTime: TDateTime;
  LTimeout: Integer;
  LCipherName: string;
begin
  if FSession = nil then Exit;

  // 生成会话 ID
  FSessionID := GenerateSessionID;
  FCreationTime := DateTimeNow;
  if TryExtractNativeSessionID(FSession, LSessionID) then
    FSessionID := LSessionID;
  if TryExtractNativeSessionCreationTime(FSession, LCreationTime) then
    FCreationTime := LCreationTime;
  if TryExtractNativeSessionTimeout(FSession, LTimeout) then
    FTimeout := LTimeout;

  // WolfSSL 会话信息提取需要额外 API
  // 当前仍缺稳定 protocol getter；套件可直接读取 session getter。
  FProtocolVersion := sslProtocolUnknown;
  FCipherName := 'unknown';
  if TryExtractNativeSessionCipherName(FSession, LCipherName) then
    FCipherName := LCipherName;
end;

function TWolfSSLSession.GenerateSessionID: string;
var
  LGuid: TGUID;
begin
  // 生成唯一会话标识符
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
end;

function TWolfSSLSession.GetID: string;
begin
  Result := FSessionID;
end;

function TWolfSSLSession.GetCreationTime: TDateTime;
begin
  Result := FCreationTime;
end;

function TWolfSSLSession.GetTimeout: Integer;
begin
  Result := FTimeout;
end;

procedure TWolfSSLSession.SetTimeout(ATimeout: Integer);
begin
  FTimeout := ATimeout;
  if (FSession <> nil) and Assigned(wolfSSL_SSL_SESSION_set_timeout) then
    wolfSSL_SSL_SESSION_set_timeout(FSession, ATimeout);
end;

function TWolfSSLSession.IsValid: Boolean;
var
  LElapsed: Integer;
begin
  Result := False;
  if FSession = nil then Exit;

  // 检查会话是否过期
  LElapsed := DateTimeSecondsBetween(DateTimeNow, FCreationTime);
  Result := LElapsed < FTimeout;
end;

function TWolfSSLSession.IsResumable: Boolean;
begin
  Result := IsValid and (FSession <> nil);
end;

function TWolfSSLSession.GetProtocolVersion: TSSLProtocolVersion;
begin
  Result := FProtocolVersion;
end;

function TWolfSSLSession.GetCipherName: string;
begin
  Result := FCipherName;
end;

function TWolfSSLSession.GetPeerCertificate: ISSLCertificate;
begin
  if FPeerCertificate <> nil then
    Result := FPeerCertificate.Clone
  else
    Result := nil;
end;

function TWolfSSLSession.Serialize: TBytes;
var
  LLen: Integer;
  LBufPtr: PByte;
  LNativeData: TBytes;
begin
  if (Length(FSerializedData) > 0) and
     ((FSession = nil) or (not Assigned(wolfSSL_i2d_SSL_SESSION))) then
    Exit(Copy(FSerializedData));

  SetLength(Result, 0);
  if (FSession = nil) or (not Assigned(wolfSSL_i2d_SSL_SESSION)) then
    Exit;

  // 使用 WolfSSL 的 i2d 函数序列化会话
  // 优先输出当前 native session 的真实序列化结果，避免回放 stale cache bytes
  LLen := wolfSSL_i2d_SSL_SESSION(FSession, nil);
  if LLen > 0 then
  begin
    SetLength(Result, LLen);
    LBufPtr := @Result[0];
    LLen := wolfSSL_i2d_SSL_SESSION(FSession, @LBufPtr);
    if LLen <= 0 then
      SetLength(Result, 0)
    else
    begin
      SetLength(LNativeData, LLen);
      Move(Result[0], LNativeData[0], LLen);
      if FCipherName <> 'unknown' then
        Result := BuildSerializedSessionData(LNativeData)
      else
        Result := LNativeData;
      FSerializedData := Copy(Result);
    end;
  end;
end;

function TWolfSSLSession.Deserialize(const AData: TBytes): Boolean;
var
  LDataPtr: PByte;
  LSession: PWOLFSSL_SESSION;
  LNativeData: TBytes;
  LSessionID: string;
  LCreationTime: TDateTime;
  LTimeout: Integer;
  LProtocolVersion: TSSLProtocolVersion;
  LCipherName: string;
  LHasEnvelope: Boolean;
begin
  Result := False;
  if Length(AData) = 0 then Exit;

  if not TryLoadSerializedSessionData(AData, LNativeData, LSessionID,
    LCreationTime, LTimeout, LProtocolVersion, LCipherName, LHasEnvelope) then
  begin
    if LHasEnvelope then
      Exit;
    LNativeData := Copy(AData);
  end;

  // 使用 WolfSSL 的 d2i 函数反序列化会话
  if Assigned(wolfSSL_d2i_SSL_SESSION) then
  begin
    LDataPtr := @LNativeData[0];
    LSession := wolfSSL_d2i_SSL_SESSION(nil, @LDataPtr, Length(LNativeData));
    if LSession <> nil then
    begin
      // 仅在新会话成功后替换旧会话，避免失败时破坏已有状态
      if FOwnsSession and (FSession <> nil) then
      begin
        if Assigned(wolfSSL_SESSION_free) then
          wolfSSL_SESSION_free(FSession);
      end;

      FSession := LSession;
      FOwnsSession := True;
      ExtractSessionInfo;
      if LHasEnvelope then
      begin
        if LSessionID <> '' then
          FSessionID := LSessionID;
        if LCreationTime > 0 then
          FCreationTime := LCreationTime;
        if LTimeout > 0 then
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
  end
end;

function TWolfSSLSession.GetNativeHandle: Pointer;
begin
  Result := FSession;
end;

function TWolfSSLSession.GetBackendType: TSSLLibraryType;
begin
  Result := sslWolfSSL;
end;

function TWolfSSLSession.IsNativeHandleValid: Boolean;
begin
  Result := (FSession <> nil);
end;

function TWolfSSLSession.Clone: ISSLSession;
var
  LClone: TWolfSSLSession;
  LSerialized: TBytes;
begin
  Result := nil;
  LClone := TWolfSSLSession.Create;
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

class function TWolfSSLSession.FromConnection(ASSL: PWOLFSSL): ISSLSession;
var
  LSession: PWOLFSSL_SESSION;
  LOwnedSession: PWOLFSSL_SESSION;
  LVersion: PAnsiChar;
  LCipher: Pointer;
  LCipherName: PAnsiChar;
  LPeerCert: PWOLFSSL_X509;
  LWrapped: TWolfSSLSession;
begin
  Result := nil;
  if ASSL = nil then Exit;
  if not Assigned(wolfSSL_get_session) then Exit;

  LSession := wolfSSL_get_session(ASSL);
  if LSession <> nil then
  begin
    LOwnedSession := DuplicateWolfSSLSessionHandle(LSession);
    if LOwnedSession = nil then
      Exit;

    LWrapped := TWolfSSLSession.Create(LOwnedSession, True);

    if Assigned(wolfSSL_get_version) then
    begin
      LVersion := wolfSSL_get_version(ASSL);
      if LVersion <> nil then
        LWrapped.FProtocolVersion := ParseWolfSSLVersionString(string(LVersion));
    end;

    if Assigned(wolfSSL_get_current_cipher) and Assigned(wolfSSL_CIPHER_get_name) then
    begin
      LCipher := wolfSSL_get_current_cipher(ASSL);
      if LCipher <> nil then
      begin
        LCipherName := wolfSSL_CIPHER_get_name(LCipher);
        if LCipherName <> nil then
          LWrapped.FCipherName := string(LCipherName);
      end;
    end;

    if Assigned(wolfSSL_get_peer_certificate) then
    begin
      LPeerCert := wolfSSL_get_peer_certificate(ASSL);
      if LPeerCert <> nil then
        LWrapped.FPeerCertificate := MaterializeWolfSSLCertificate(LPeerCert);
    end;

    Result := LWrapped;
  end;
end;

end.
