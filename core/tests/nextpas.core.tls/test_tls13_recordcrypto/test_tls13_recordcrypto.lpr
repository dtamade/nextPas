program test_tls13_recordcrypto;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.tls.tls13.recordcrypto,
  nextpas.core.test, nextpas.core.base, nextpas.core.text.conv;

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

var
  LRunner: TSuiteRunner;
  LSuite: TTestSuite;
begin
  LSuite := TTestSuite.Create('tls13.recordcrypto');

  LSuite.Test('build AAD', procedure
  var LAAD: TBytes;
  begin
    LAAD := BuildTLS13RecordAAD(256);
    CheckEqual(5, Length(LAAD));
    CheckTrue(LAAD[0] = $17);
    CheckTrue((LAAD[1] = $03) and (LAAD[2] = $03));
    CheckTrue((LAAD[3] = $01) and (LAAD[4] = $00));
    LAAD := BuildTLS13RecordAAD(42);
    CheckTrue((LAAD[3] = $00) and (LAAD[4] = $2A));
  end);

  LSuite.Test('build nonce', procedure
  var LIV, LNonce: TBytes;
  begin
    LIV := HexToBytes('000000000000000000000001');
    LNonce := BuildTLS13RecordNonce(LIV, 0);
    CheckEqual(12, Length(LNonce));
    CheckEqual('000000000000000000000001', BytesToHex(LNonce));
    LNonce := BuildTLS13RecordNonce(LIV, 1);
    CheckEqual('000000000000000000000000', BytesToHex(LNonce));
    LIV := HexToBytes('abcdef0123456789abcdef01');
    LNonce := BuildTLS13RecordNonce(LIV, $0102030405060708);
    CheckEqual('abcdef012247648daecbe809', BytesToHex(LNonce));
  end);

  LSuite.Test('inner plaintext', procedure
  var LFragment, LInner, LParsedFragment: TBytes; LContentType: Byte; LOk: Boolean;
  begin
    LFragment := HexToBytes('48656c6c6f');
    LInner := BuildTLS13InnerPlaintext(LFragment, $17);
    CheckTrue(Length(LInner) >= 6);
    CheckTrue((LInner[0] = $48) and (LInner[1] = $65));
    LOk := TryParseTLS13InnerPlaintext(LInner, LParsedFragment, LContentType);
    CheckTrue(LOk);
    CheckTrue(LContentType = $17);
    CheckEqual('48656c6c6f', BytesToHex(LParsedFragment));
  end);

  LSuite.Test('inner plaintext empty', procedure
  var LFragment, LInner, LParsedFragment: TBytes; LContentType: Byte; LOk: Boolean;
  begin
    SetLength(LFragment, 0);
    LInner := BuildTLS13InnerPlaintext(LFragment, $16);
    CheckTrue(Length(LInner) >= 1);
    LOk := TryParseTLS13InnerPlaintext(LInner, LParsedFragment, LContentType);
    CheckTrue(LOk);
    CheckTrue(LContentType = $16);
    CheckEqual(0, Length(LParsedFragment));
  end);

  LSuite.Test('sequence increment', procedure
  var LSeq: QWord;
  begin
    LSeq := 0;
    CheckTrue(IncrementTLS13Sequence(LSeq));
    CheckTrue(LSeq = 1);
    LSeq := $FFFFFFFFFFFFFFFE;
    CheckTrue(IncrementTLS13Sequence(LSeq));
    CheckTrue(LSeq = $FFFFFFFFFFFFFFFF);
    CheckTrue(not IncrementTLS13Sequence(LSeq));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.tls.tls13.recordcrypto');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
