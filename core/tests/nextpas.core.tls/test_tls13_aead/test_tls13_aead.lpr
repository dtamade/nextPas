program test_tls13_aead;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.tls13.aead,
  nextpas.core.tls.tls13.wire,
  nextpas.core.test, nextpas.core.base, nextpas.core.text, nextpas.core.text.conv;

function HexToBytes(const AHex: string): TBytes;
var I: Integer;
begin SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do Result[I] := StrToInt('$' + Copy(AHex, I*2+1, 2));
end;

function BytesToHex(const AData: TBytes): string;
var I: Integer;
begin Result := '';
  for I := 0 to High(AData) do Result := Result + LowerCase(IntToHex(AData[I], 2));
end;

const
  CS_AES128_GCM = $1301;
  CS_AES256_GCM = $1302;
  CS_CHACHA20   = $1303;

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.aead');

  LSuite.Test('supported ciphers', procedure begin
    CheckTrue(TLS13AEADIsSupported(CS_AES128_GCM));
    CheckTrue(TLS13AEADIsSupported(CS_AES256_GCM));
    CheckTrue(TLS13AEADIsSupported(CS_CHACHA20));
    CheckTrue(not TLS13AEADIsSupported($FFFF));
  end);

  LSuite.Test('tag length', procedure begin
    CheckEqual(16, TLS13AEADTagLength(CS_AES128_GCM));
    CheckEqual(16, TLS13AEADTagLength(CS_AES256_GCM));
    CheckEqual(16, TLS13AEADTagLength(CS_CHACHA20));
  end);

  LSuite.Test('AES-128-GCM roundtrip', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
    LNonce := HexToBytes('5d313eb2671276ee13000b30');
    LAAD := HexToBytes('1703030020');
    LPlain := HexToBytes('48656c6c6f20544c532031');
    LOk := TryTLS13AEADEncrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
    CheckTrue(LOk);
    CheckEqual(Length(LPlain) + 16, Length(LEncrypted));
    LOk := TryTLS13AEADDecrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('AES-256-GCM roundtrip', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000001');
    LAAD := HexToBytes('17030300ff');
    LPlain := HexToBytes('deadbeefcafebabe01020304');
    LOk := TryTLS13AEADEncrypt(CS_AES256_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
    CheckTrue(LOk);
    LOk := TryTLS13AEADDecrypt(CS_AES256_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('ChaCha20-Poly1305 roundtrip', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LKey := HexToBytes('0102030405060708091011121314151617181920212223242526272829303132');
    LNonce := HexToBytes('000000000000000000000002');
    LAAD := HexToBytes('1703030010');
    LPlain := HexToBytes('48656c6c6f');
    LOk := TryTLS13AEADEncrypt(CS_CHACHA20, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
    CheckTrue(LOk);
    LOk := TryTLS13AEADDecrypt(CS_CHACHA20, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
    CheckTrue(LOk);
    CheckEqual(BytesToHex(LPlain), BytesToHex(LDecrypted));
  end);

  LSuite.Test('tampered encrypted rejected', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted, LDecrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
    LNonce := HexToBytes('5d313eb2671276ee13000b30');
    LAAD := HexToBytes('1703030010');
    LPlain := HexToBytes('aabbccdd');
    TryTLS13AEADEncrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
    LEncrypted[0] := LEncrypted[0] xor $FF;
    LOk := TryTLS13AEADDecrypt(CS_AES128_GCM, LKey, LNonce, LAAD, LEncrypted, LDecrypted, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('unsupported cipher rejected', procedure
  var LKey, LNonce, LAAD, LPlain, LEncrypted: TBytes; LError: string; LOk: Boolean;
  begin
    LKey := HexToBytes('3fce516009c21727d0f2e4e86ee403bc');
    LNonce := HexToBytes('5d313eb2671276ee13000b30');
    SetLength(LAAD, 0);
    LPlain := HexToBytes('aa');
    LOk := TryTLS13AEADEncrypt($FFFF, LKey, LNonce, LAAD, LPlain, LEncrypted, LError);
    CheckTrue(not LOk);
    CheckTrue(Pos('upport', LError) > 0);
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.aead');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
