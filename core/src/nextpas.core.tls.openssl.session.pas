{
  nextpas.core.tls.openssl.session - OpenSSL 会话实现
  版本: 1.0 (简化版)
}

unit nextpas.core.tls.openssl.session;

{$mode ObjFPC}{$H+}
{$WARN 5093 off}  // Function result variable of managed type does not seem initialized

interface

uses
  SysUtils, ctypes,
  nextpas.core.tls.base,
  nextpas.core.tls.openssl.base,
  nextpas.core.tls.openssl.api.core,
  nextpas.core.tls.openssl.api.ssl,
  nextpas.core.tls.openssl.api.bio,
  nextpas.core.tls.openssl.api.consts,
  nextpas.core.tls.openssl.native_handle,
  nextpas.core.tls.openssl.certificate;

const
  HexDigits: array[0..15] of Char = '0123456789ABCDEF';

type
  TOpenSSLSession = class(TInterfacedObject, ISSLSession, ISSLNativeHandleAccess)
  private
    FSession: PSSL_SESSION;
    FOwnsHandle: Boolean;
  public
    constructor Create(ASession: PSSL_SESSION; AOwnsHandle: Boolean = True);
    destructor Destroy; override;
    
    function GetID: string;
    function GetCreationTime: TDateTime;
    function GetTimeout: Integer;
    procedure SetTimeout(ATimeout: Integer);
    function IsValid: Boolean;
    function IsResumable: Boolean;
    function GetProtocolVersion: TSSLProtocolVersion;
    function GetCipherName: string;
    function GetPeerCertificate: ISSLCertificate;
    function Serialize: TBytes;
    function Deserialize(const AData: TBytes): Boolean;
    function Clone: ISSLSession;

    // ISSLNativeHandleAccess implementation
    function GetNativeHandle: Pointer;
    function GetBackendType: TSSLLibraryType;
    function IsNativeHandleValid: Boolean;
  end;

implementation

function HasSessionSerializeHelpers: Boolean;
begin
  Result := Assigned(i2d_SSL_SESSION_bio) and
            Assigned(BIO_new) and
            Assigned(BIO_s_mem) and
            Assigned(BIO_free);
end;

function HasSessionDeserializeHelpers: Boolean;
begin
  Result := Assigned(d2i_SSL_SESSION_bio) and
            Assigned(BIO_new_mem_buf) and
            Assigned(BIO_free);
end;

constructor TOpenSSLSession.Create(ASession: PSSL_SESSION; AOwnsHandle: Boolean = True);
begin
  inherited Create;
  FSession := ASession;
  FOwnsHandle := AOwnsHandle;
end;

destructor TOpenSSLSession.Destroy;
begin
  if FOwnsHandle and (FSession <> nil) then
    SSL_SESSION_free(FSession);
  inherited;
end;

function TOpenSSLSession.GetID: string;
var
  IDPtr: PByte;
  IDLen: Cardinal;
  I: Integer;
begin
  Result := '';
  
  if FSession = nil then
    Exit;
  
  if not Assigned(SSL_SESSION_get_id) then
    Exit;
  
  IDPtr := SSL_SESSION_get_id(FSession, @IDLen);
  if (IDPtr = nil) or (IDLen = 0) then
    Exit;
  
  // 转换为十六进制字符串
  SetLength(Result, IDLen * 2);
  for I := 0 to IDLen - 1 do
  begin
    Result[I * 2 + 1] := HexDigits[(PByte(IDPtr + I)^ shr 4) and $0F];
    Result[I * 2 + 2] := HexDigits[PByte(IDPtr + I)^ and $0F];
  end;
end;

function TOpenSSLSession.GetCreationTime: TDateTime;
var
  UnixTime: clong;
begin
  Result := 0;
  
  if FSession = nil then
    Exit;
  
  if not Assigned(SSL_SESSION_get_time) then
    Exit;
  
  UnixTime := SSL_SESSION_get_time(FSession);
  if UnixTime > 0 then
    // 25569 = Days between 1899-12-30 and 1970-01-01
    Result := 25569 + (UnixTime / 86400);
end;

function TOpenSSLSession.GetTimeout: Integer;
begin
  if FSession = nil then Exit(0);
  Result := SSL_SESSION_get_timeout(FSession);
end;

procedure TOpenSSLSession.SetTimeout(ATimeout: Integer);
begin
  if FSession = nil then Exit;
  SSL_SESSION_set_timeout(FSession, ATimeout);
end;

function TOpenSSLSession.IsValid: Boolean;
begin
  Result := (FSession <> nil);
end;

function TOpenSSLSession.IsResumable: Boolean;
begin
  Result := IsValid;
end;

function TOpenSSLSession.GetProtocolVersion: TSSLProtocolVersion;
var
  Version: Integer;
begin
  Result := sslProtocolTLS12; // 默认值
  
  if FSession = nil then
    Exit;
  
  if not Assigned(SSL_SESSION_get_protocol_version) then
    Exit;
  
  Version := SSL_SESSION_get_protocol_version(FSession);

  // P3-19: 添加完整的协议版本处理以保持与 WinSSL 一致
  case Version of
    SSL2_VERSION: Result := sslProtocolSSL2;
    SSL3_VERSION: Result := sslProtocolSSL3;
    TLS1_VERSION: Result := sslProtocolTLS10;
    TLS1_1_VERSION: Result := sslProtocolTLS11;
    TLS1_2_VERSION: Result := sslProtocolTLS12;
    TLS1_3_VERSION: Result := sslProtocolTLS13;
  else
    Result := sslProtocolTLS12; // 未知版本时默认为 TLS 1.2
  end;
end;

function TOpenSSLSession.GetCipherName: string;
var
  Cipher: PSSL_CIPHER;
  NamePtr: PAnsiChar;
begin
  Result := '';
  
  if FSession = nil then
    Exit;
  
  if not Assigned(SSL_SESSION_get0_cipher) or not Assigned(SSL_CIPHER_get_name) then
    Exit;
  
  Cipher := SSL_SESSION_get0_cipher(FSession);
  if Cipher = nil then
    Exit;
  
  NamePtr := SSL_CIPHER_get_name(Cipher);
  if NamePtr <> nil then
    Result := string(NamePtr);
end;

function TOpenSSLSession.GetPeerCertificate: ISSLCertificate;
var
  X509Cert: PX509;
begin
  Result := nil;
  
  if FSession = nil then
    Exit;
  
  if not Assigned(SSL_SESSION_get0_peer) then
    Exit;
  
  X509Cert := SSL_SESSION_get0_peer(FSession);
  if X509Cert = nil then
    Exit;
  
  // 创建证书对象（不拥有所有权，因为 get0 不增加引用计数）
  Result := TOpenSSLCertificate.Create(X509Cert, False);
end;

function TOpenSSLSession.Serialize: TBytes;
var
  BIO: PBIO;
  Len: Integer;
  Buf: PAnsiChar;
begin
  SetLength(Result, 0);
  
  if FSession = nil then
    Exit;

  if not HasSessionSerializeHelpers() then
    Exit;
  
  BIO := BIO_new(BIO_s_mem());
  if BIO = nil then
    Exit;
  
  try
    if i2d_SSL_SESSION_bio(BIO, FSession) > 0 then
    begin
      Len := BIO_get_mem_data(BIO, @Buf);
      if Len > 0 then
      begin
        SetLength(Result, Len);
        Move(Buf^, Result[0], Len);
      end;
    end;
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLSession.Deserialize(const AData: TBytes): Boolean;
var
  BIO: PBIO;
  NewSession: PSSL_SESSION;
begin
  Result := False;
  
  if Length(AData) = 0 then
    Exit;

  if not HasSessionDeserializeHelpers() then
    Exit;
  
  BIO := BIO_new_mem_buf(@AData[0], Length(AData));
  if BIO = nil then
    Exit;
  
  try
    NewSession := d2i_SSL_SESSION_bio(BIO, nil);
    if NewSession <> nil then
    begin
      if FOwnsHandle and (FSession <> nil) then
        SSL_SESSION_free(FSession);
      
      FSession := NewSession;
      FOwnsHandle := True;
      Result := True;
    end;
  finally
    BIO_free(BIO);
  end;
end;

function TOpenSSLSession.GetNativeHandle: Pointer;
begin
  Result := FSession;
end;

function TOpenSSLSession.GetBackendType: TSSLLibraryType;
begin
  Result := sslOpenSSL;
end;

function TOpenSSLSession.IsNativeHandleValid: Boolean;
begin
  Result := (FSession <> nil);
end;

function TOpenSSLSession.Clone: ISSLSession;
begin
  if FSession <> nil then
  begin
    SSL_SESSION_up_ref(FSession);
    Result := TOpenSSLSession.Create(FSession, True);
  end
  else
    Result := nil;
end;

end.
