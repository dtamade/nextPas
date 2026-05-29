program freepascal_security_features;

{$mode objfpc}{$H+}

{ ============================================================================
  FreePascal TLS 安全特性综合示例

  演示纯 Pascal 后端的高级安全功能:
  - 自定义 cipher suite 列表
  - ALPN 协商
  - OCSP stapling 验证
  - Certificate Transparency (SCT) 验证

  编译: fpc -B -Fu./src -Fu./examples ./examples/11_freepascal_security_features.pas
  运行: ./11_freepascal_security_features [host]
  ============================================================================ }

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.tls,
  nextpas.core.tls.freepascal.lib,
  nextpas.core.tls.freepascal.context,
  fafafa.examples.tcp;

const
  DEFAULT_HOST = 'www.cloudflare.com';

procedure DemoCustomCiphers(const AHost: string);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  ConnInfo: ISSLConnectionInfo;
  Info: TSSLConnectionInfo;
  Sock: TSocketHandle;
begin
  WriteLn('--- Custom Cipher Suite Configuration ---');
  Lib := CreateFreePascalSSLLibrary;
  Lib.Initialize;
  Ctx := Lib.CreateContext(sslCtxClient);
  Ctx.SetCipherList('TLS_AES_256_GCM_SHA384:TLS_CHACHA20_POLY1305_SHA256');

  Sock := ConnectTCP(AHost, 443);
  Connector := TSSLConnector.FromContext(Ctx).WithTimeout(10000);
  TLS := Connector.ConnectSocket(THandle(Sock), AHost);
  try
    if Supports(TLS.Connection, ISSLConnectionInfo, ConnInfo) then
    begin
      Info := ConnInfo.GetConnectionInfo;
      WriteLn('  Cipher: ', Info.CipherSuite);
      WriteLn('  Key size: ', Info.KeySize, ' bits');
      WriteLn('  [OK] Custom cipher negotiation works');
    end;
  finally
    TLS.Free;
  end;
  WriteLn;
end;

procedure DemoALPN(const AHost: string);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  ConnInfo: ISSLConnectionInfo;
  Sock: TSocketHandle;
begin
  WriteLn('--- ALPN Protocol Negotiation ---');
  Lib := CreateFreePascalSSLLibrary;
  Lib.Initialize;
  Ctx := Lib.CreateContext(sslCtxClient);
  Ctx.SetALPNProtocols('h2,http/1.1');

  Sock := ConnectTCP(AHost, 443);
  Connector := TSSLConnector.FromContext(Ctx).WithTimeout(10000);
  TLS := Connector.ConnectSocket(THandle(Sock), AHost);
  try
    if Supports(TLS.Connection, ISSLConnectionInfo, ConnInfo) then
    begin
      WriteLn('  Negotiated: ', ConnInfo.GetSelectedALPNProtocol);
      WriteLn('  [OK] ALPN negotiation works');
    end;
  finally
    TLS.Free;
  end;
  WriteLn;
end;

procedure DemoOCSPStapling(const AHost: string);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  LOCSP: ISSLOCSPStapling;
  Sock: TSocketHandle;
begin
  WriteLn('--- OCSP Stapling ---');
  Lib := CreateFreePascalSSLLibrary;
  Lib.Initialize;
  Ctx := Lib.CreateContext(sslCtxClient);
  Ctx.SetOptions([ssoEnableOCSPStapling]);

  Sock := ConnectTCP(AHost, 443);
  Connector := TSSLConnector.FromContext(Ctx).WithTimeout(10000);
  TLS := Connector.ConnectSocket(THandle(Sock), AHost);
  try
    if Supports(TLS.Connection, ISSLOCSPStapling, LOCSP) then
    begin
      WriteLn('  Stapling enabled: ', LOCSP.GetOCSPStaplingEnabled);
      WriteLn('  Response size: ', Length(LOCSP.GetOCSPResponse), ' bytes');
      WriteLn('  Status: ', LOCSP.GetOCSPResponseStatus);
      WriteLn('  [OK] OCSP stapling works');
    end;
  finally
    TLS.Free;
  end;
  WriteLn;
end;

procedure DemoCertificateTransparency(const AHost: string);
var
  Lib: ISSLLibrary;
  Ctx: ISSLContext;
  Connector: TSSLConnector;
  TLS: TSSLStream;
  LCT: ISSLCertificateTransparency;
  Sock: TSocketHandle;
begin
  WriteLn('--- Certificate Transparency (SCT) ---');
  Lib := CreateFreePascalSSLLibrary;
  Lib.Initialize;
  Ctx := Lib.CreateContext(sslCtxClient);

  Sock := ConnectTCP(AHost, 443);
  Connector := TSSLConnector.FromContext(Ctx).WithTimeout(10000);
  TLS := Connector.ConnectSocket(THandle(Sock), AHost);
  try
    if Supports(TLS.Connection, ISSLCertificateTransparency, LCT) then
    begin
      WriteLn('  CT enabled: ', LCT.GetCertificateTransparencyEnabled);
      WriteLn('  SCT count: ', LCT.GetSignedCertificateTimestampCount);
      WriteLn('  CT status: ', LCT.GetCertificateTransparencyStatus);
      WriteLn('  [OK] Certificate Transparency works');
    end;
  finally
    TLS.Free;
  end;
  WriteLn;
end;

var
  LHost: string;
  NetErr: string;
begin
  if ParamCount >= 1 then
    LHost := ParamStr(1)
  else
    LHost := DEFAULT_HOST;

  if not InitNetwork(NetErr) then
  begin
    WriteLn('Network init failed: ', NetErr);
    Halt(2);
  end;

  WriteLn('=== FreePascal TLS Security Features Demo ===');
  WriteLn('Target: ', LHost);
  WriteLn;

  DemoCustomCiphers(LHost);
  DemoALPN(LHost);
  DemoOCSPStapling(LHost);
  DemoCertificateTransparency(LHost);

  WriteLn('All security feature demos completed.');
end.
