program test_type_safety;

{$I nextpas.core.settings.inc}
{$J-}

uses
  nextpas.core.tls.safety,
  nextpas.core.test, nextpas.core.base, nextpas.core.math;

type
  TIntSecureData = specialize TSecureData<Integer>;
  TStringSecureData = specialize TSecureData<string>;
  TIntStringResult = specialize TResult<Integer, string>;
  TBytesStringResult = specialize TResult<TBytes, string>;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls.type_safety');

  LSuite.Test('SSLVersion enum', procedure begin
    CheckEqual('TLS 1.2', SSLVersionToString(sslv_TLS12));
    CheckEqual('TLS 1.3', SSLVersionToString(sslv_TLS13));
    CheckTrue(StringToSSLVersion('TLS 1.2') = sslv_TLS12);
    CheckTrue(StringToSSLVersion('TLS1.3') = sslv_TLS13);
    CheckTrue(StringToSSLVersion('tlsv13') = sslv_TLS13);
  end);

  LSuite.Test('KeyType enum', procedure begin
    CheckEqual('RSA', KeyTypeToString(kt_RSA));
    CheckEqual('EC', KeyTypeToString(kt_EC));
    CheckEqual('Ed25519', KeyTypeToString(kt_Ed25519));
  end);

  LSuite.Test('CertificateFormat enum', procedure begin
    CheckEqual('PEM', CertificateFormatToString(cf_PEM));
    CheckEqual('DER', CertificateFormatToString(cf_DER));
    CheckEqual('PKCS12', CertificateFormatToString(cf_PKCS12));
  end);

  LSuite.Test('TKeySize unit type', procedure
  var LS1, LS2, LS3: TKeySize; LErr: Boolean;
  begin
    LS1 := TKeySize.Bits(256);
    CheckTrue(LS1.ToBits = 256); CheckTrue(LS1.ToBytes = 32);
    LS2 := TKeySize.Bytes(32);
    CheckTrue(LS2.ToBits = 256); CheckTrue(LS2.ToBytes = 32);
    CheckTrue(LS1.IsEqual(LS2));
    LS3 := TKeySize.Bits(128);
    CheckTrue(LS3.Compare(LS1) < 0); CheckTrue(LS1.Compare(LS3) > 0);
    CheckTrue(LS1.IsValid);
    LErr := False; try LS1 := TKeySize.Bits(127); except LErr := True; end;
    CheckTrue(LErr);
    LErr := False; try LS1 := TKeySize.Bytes(-1); except LErr := True; end;
    CheckTrue(LErr);
  end);

  LSuite.Test('TTimeoutDuration unit type', procedure
  var LT1, LT2, LT3: TTimeoutDuration;
  begin
    LT1 := TTimeoutDuration.Milliseconds(5000);
    CheckTrue(LT1.ToMilliseconds = 5000);
    CheckTrue(Abs(LT1.ToSeconds - 5.0) < 0.001);
    LT2 := TTimeoutDuration.Seconds(5);
    CheckTrue(LT2.ToMilliseconds = 5000); CheckTrue(LT1.IsEqual(LT2));
    LT3 := TTimeoutDuration.Minutes(2);
    CheckTrue(LT3.ToMilliseconds = 120000);
    CheckTrue(Abs(LT3.ToSeconds - 120.0) < 0.001);
    LT1 := TTimeoutDuration.Infinite;
    CheckTrue(LT1.IsInfinite);
    LT1 := TTimeoutDuration.Seconds(10); LT2 := TTimeoutDuration.Seconds(5);
    CheckTrue(LT1.Compare(LT2) > 0); CheckTrue(LT2.Compare(LT1) < 0);
  end);

  LSuite.Test('TBufferSize unit type', procedure
  var LS1, LS2, LS3: TBufferSize;
  begin
    LS1 := TBufferSize.Bytes(2048);
    CheckTrue(LS1.ToBytes = 2048); CheckTrue(LS1.ToKB = 2);
    LS2 := TBufferSize.KB(2);
    CheckTrue(LS2.ToBytes = 2048); CheckTrue(LS1.IsEqual(LS2));
    LS3 := TBufferSize.MB(1);
    CheckTrue(LS3.ToBytes = 1048576); CheckTrue(LS3.ToKB = 1024);
    CheckTrue(LS3.ToMB = 1);
    CheckTrue(LS3.Compare(LS1) > 0); CheckTrue(LS1.Compare(LS3) < 0);
  end);

  LSuite.Test('TSecureData<T> Some/None', procedure
  var LD: TIntSecureData;
  begin
    LD := TIntSecureData.Some(42);
    CheckTrue(LD.IsValid); CheckTrue(LD.IsSome); CheckTrue(not LD.IsNone);
    CheckTrue(LD.Unwrap = 42);
    LD := TIntSecureData.None('Test error');
    CheckTrue(not LD.IsValid); CheckTrue(LD.IsNone); CheckTrue(not LD.IsSome);
    CheckEqual('Test error', LD.ErrorMessage);
  end);

  LSuite.Test('TSecureData<T> UnwrapOr', procedure
  var LD: TIntSecureData;
  begin
    LD := TIntSecureData.Some(42);
    CheckTrue(LD.UnwrapOr(100) = 42);
    LD := TIntSecureData.None;
    CheckTrue(LD.UnwrapOr(100) = 100);
  end);

  LSuite.Test('TSecureData<T> Unwrap error', procedure
  var LD: TIntSecureData; LErr: Boolean;
  begin
    LD := TIntSecureData.None('No value');
    LErr := False; try LD.Unwrap; except LErr := True; end;
    CheckTrue(LErr);
  end);

  LSuite.Test('TResult<T,E> Ok/Err', procedure
  var LR: TIntStringResult;
  begin
    LR := TIntStringResult.Ok(42);
    CheckTrue(LR.IsOk); CheckTrue(not LR.IsErr);
    CheckTrue(LR.Unwrap = 42);
    LR := TIntStringResult.Err('Operation failed');
    CheckTrue(LR.IsErr); CheckTrue(not LR.IsOk);
    CheckEqual('Operation failed', LR.UnwrapErr);
  end);

  LSuite.Test('TResult<T,E> UnwrapOr', procedure
  var LR: TIntStringResult;
  begin
    LR := TIntStringResult.Ok(42);
    CheckTrue(LR.UnwrapOr(100) = 42);
    LR := TIntStringResult.Err('Error');
    CheckTrue(LR.UnwrapOr(100) = 100);
  end);

  LSuite.Test('TResult<T,E> Unwrap errors', procedure
  var LR: TIntStringResult; LErr: Boolean;
  begin
    LR := TIntStringResult.Err('Failed');
    LErr := False; try LR.Unwrap; except LErr := True; end;
    CheckTrue(LErr);
    LR := TIntStringResult.Ok(42);
    LErr := False; try LR.UnwrapErr; except LErr := True; end;
    CheckTrue(LErr);
  end);

  LSuite.Test('EllipticCurve NID', procedure begin
    CheckTrue(EllipticCurveToNID(ec_P256) = 415);
    CheckTrue(EllipticCurveToNID(ec_P384) = 715);
    CheckTrue(EllipticCurveToNID(ec_X25519) = 1034);
    CheckEqual('P-256', EllipticCurveToString(ec_P256));
    CheckEqual('Brainpool P-384', EllipticCurveToString(ec_BrainpoolP384));
  end);

  LSuite.Test('CipherMode enum', procedure begin
    CheckEqual('GCM', CipherModeToString(cm_GCM));
    CheckEqual('CBC', CipherModeToString(cm_CBC));
    CheckEqual('CTR', CipherModeToString(cm_CTR));
  end);

  LSuite.Test('TSecureData<string> practical', procedure
  var LD: TStringSecureData;
  begin
    LD := TStringSecureData.Some('localhost');
    CheckTrue(LD.IsSome);
    CheckEqual('localhost', LD.UnwrapOr('default.server.com'));
    LD := TStringSecureData.None('Config not found');
    CheckTrue(LD.IsNone);
    CheckEqual('default.server.com', LD.UnwrapOr('default.server.com'));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.type_safety');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
