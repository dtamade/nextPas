program test_backend_capabilities;

{$mode objfpc}{$H+}{$J-}

{**
 * Backend Capabilities Test Suite
 *
 * P2-2: 测试后端能力矩阵功能
 *
 * 验证 GetCapabilities 方法返回正确的后端能力信息。
 *
 * @author fafafa.ssl team
 * @version 1.0.0
 * @since 2025-12-24
 *}

uses
  SysUtils, Classes,
  nextpas.core.tls.base,
  nextpas.core.tls.factory,
  nextpas.core.tls.openssl.api,
  nextpas.core.tls.openssl.backed;

var
  Total, Passed, Failed: Integer;
  Section: string;

procedure BeginSection(const AName: string);
begin
  Section := AName;
  WriteLn;
  WriteLn('=== ', AName, ' ===');
end;

procedure Check(const AName: string; AOk: Boolean; const ADetails: string = '');
begin
  Inc(Total);
  Write('  [', Section, '] ', AName, ': ');
  if AOk then
  begin
    Inc(Passed);
    WriteLn('PASS');
  end
  else
  begin
    Inc(Failed);
    WriteLn('FAIL');
    if ADetails <> '' then
      WriteLn('    ', ADetails);
  end;
end;

procedure TestOpenSSLCapabilities;
var
  LLibrary: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  BeginSection('OpenSSL Capabilities');

  try
    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    Check('Library created', LLibrary <> nil);

    if LLibrary = nil then
      Exit;

    if not LLibrary.Initialize then
    begin
      Check('Library initialized', False, 'Failed to initialize');
      Exit;
    end;

    Check('Library initialized', True);

    LCaps := LLibrary.GetCapabilities;

    // OpenSSL 应该总是支持这些特性
    Check('Supports ALPN', LCaps.SupportsALPN);
    Check('Supports SNI', LCaps.SupportsSNI);
    Check('Supports Session Tickets', LCaps.SupportsSessionTickets);
    Check('Supports ECDHE', LCaps.SupportsECDHE);
    Check('Supports OCSP Stapling', LCaps.SupportsOCSPStapling);

    // TLS 版本检查
    Check('Max TLS >= TLS 1.2', Ord(LCaps.MaxTLSVersion) >= Ord(sslProtocolTLS12));
    Check('Min TLS is TLS 1.0', LCaps.MinTLSVersion = sslProtocolTLS10);

    // 检查 TLS 1.3 支持（取决于 OpenSSL 版本）
    WriteLn('    Info: TLS 1.3 support = ', BoolToStr(LCaps.SupportsTLS13, True));
    WriteLn('    Info: ChaCha20 support = ', BoolToStr(LCaps.SupportsChaChaPoly, True));
    WriteLn('    Info: CT support = ', BoolToStr(LCaps.SupportsCertificateTransparency, True));

    LLibrary.Finalize;
    Check('Library finalized', True);

  except
    on E: Exception do
      Check('OpenSSL capabilities', False, E.Message);
  end;
end;

procedure TestCapabilitiesConsistency;
var
  LLibrary: ISSLLibrary;
  LCaps1, LCaps2: TSSLBackendCapabilities;
begin
  BeginSection('Capabilities Consistency');

  try
    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (LLibrary = nil) or not LLibrary.Initialize then
    begin
      Check('Library ready', False);
      Exit;
    end;

    // 多次调用应该返回相同结果
    LCaps1 := LLibrary.GetCapabilities;
    LCaps2 := LLibrary.GetCapabilities;

    Check('TLS 1.3 consistent',
          LCaps1.SupportsTLS13 = LCaps2.SupportsTLS13);
    Check('ALPN consistent',
          LCaps1.SupportsALPN = LCaps2.SupportsALPN);
    Check('SNI consistent',
          LCaps1.SupportsSNI = LCaps2.SupportsSNI);
    Check('Max TLS consistent',
          LCaps1.MaxTLSVersion = LCaps2.MaxTLSVersion);
    Check('Min TLS consistent',
          LCaps1.MinTLSVersion = LCaps2.MinTLSVersion);

    LLibrary.Finalize;

  except
    on E: Exception do
      Check('Consistency test', False, E.Message);
  end;
end;

procedure TestCapabilitiesLogic;
var
  LLibrary: ISSLLibrary;
  LCaps: TSSLBackendCapabilities;
begin
  BeginSection('Capabilities Logic');

  try
    LLibrary := TSSLFactory.GetLibraryInstance(sslOpenSSL);
    if (LLibrary = nil) or not LLibrary.Initialize then
    begin
      Check('Library ready', False);
      Exit;
    end;

    LCaps := LLibrary.GetCapabilities;

    // 逻辑验证
    Check('Max TLS >= Min TLS',
          Ord(LCaps.MaxTLSVersion) >= Ord(LCaps.MinTLSVersion));

    // 如果支持 TLS 1.3，Max 应该是 TLS 1.3
    if LCaps.SupportsTLS13 then
      Check('TLS 1.3 implies Max=TLS1.3',
            LCaps.MaxTLSVersion = sslProtocolTLS13);

    // ChaCha20 通常与 TLS 1.3 一起支持
    if LCaps.SupportsTLS13 then
      Check('TLS 1.3 implies ChaCha20',
            LCaps.SupportsChaChaPoly,
            'ChaCha20 usually available with TLS 1.3');

    LLibrary.Finalize;

  except
    on E: Exception do
      Check('Logic test', False, E.Message);
  end;
end;

begin
  Total := 0;
  Passed := 0;
  Failed := 0;

  WriteLn('==========================================');
  WriteLn('  Backend Capabilities Tests (P2-2)');
  WriteLn('==========================================');

  try
    // 初始化 OpenSSL
    if not LoadOpenSSLLibrary then
    begin
      WriteLn('ERROR: Failed to load OpenSSL library');
      Halt(1);
    end;

    TestOpenSSLCapabilities;
    TestCapabilitiesConsistency;
    TestCapabilitiesLogic;

  except
    on E: Exception do
    begin
      WriteLn;
      WriteLn('ERROR: ', E.Message);
      Inc(Failed);
    end;
  end;

  WriteLn;
  WriteLn('==========================================');
  WriteLn(Format('Total: %d  Passed: %d  Failed: %d', [Total, Passed, Failed]));
  WriteLn('==========================================');

  if Failed > 0 then
    Halt(1);
end.
