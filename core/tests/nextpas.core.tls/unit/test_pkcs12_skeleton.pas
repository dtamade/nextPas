program test_pkcs12_skeleton;

{$mode objfpc}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.pkcs12;

var
  LTotal, LPassed: Integer;

procedure Check(ACondition: Boolean; const AName: string);
begin
  Inc(LTotal);
  if ACondition then
  begin
    Inc(LPassed);
    WriteLn('  PASS: ', AName);
  end
  else
  begin
    WriteLn('  FAIL: ', AName);
    Halt(1);
  end;
end;

procedure TestTooShort;
var
  LData: TBytes;
  LResult: TPKCS12ParseResult;
  LError: string;
begin
  WriteLn('TestTooShort');
  SetLength(LData, 5);
  Check(not TryParsePKCS12(LData, '', LResult, LError), 'Too short rejected');
  Check(Pos('too short', LError) > 0, 'Error mentions too short');
end;

procedure TestInvalidASN1;
var
  LData: TBytes;
  LResult: TPKCS12ParseResult;
  LError: string;
begin
  WriteLn('TestInvalidASN1');
  LData := TBytes.Create($FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF, $FF);
  Check(not TryParsePKCS12(LData, '', LResult, LError), 'Invalid ASN1 rejected');
  Check(Pos('ASN.1', LError) > 0, 'Error mentions ASN.1');
end;

procedure TestValidMinimalPKCS12;
var
  LData: TBytes;
  LResult: TPKCS12ParseResult;
  LError: string;
begin
  WriteLn('TestValidMinimalPKCS12');
  // Minimal PKCS#12: SEQUENCE { INTEGER 3, SEQUENCE { OID pkcs7-data, [0] OCTET STRING {} } }
  LData := TBytes.Create(
    $30, $1E,                   // SEQUENCE
      $02, $01, $03,            // INTEGER 3 (version)
      $30, $19,                 // SEQUENCE (authSafe)
        $06, $09,               // OID
          $2A, $86, $48, $86, $F7, $0D, $01, $07, $01,  // 1.2.840.113549.1.7.1
        $A0, $0C,               // [0] EXPLICIT
          $04, $0A,             // OCTET STRING
            $30, $08,           // SEQUENCE (SafeContents)
              $30, $06,         // SEQUENCE (SafeBag)
                $06, $01, $00,  // OID (dummy)
                $A0, $01, $00   // [0] value
  );
  Check(TryParsePKCS12(LData, '', LResult, LError), 'Minimal PKCS#12 accepted: ' + LError);
end;

procedure TestWrongVersion;
var
  LData: TBytes;
  LResult: TPKCS12ParseResult;
  LError: string;
begin
  WriteLn('TestWrongVersion');
  // SEQUENCE { INTEGER 2, SEQUENCE {} }
  LData := TBytes.Create(
    $30, $07,
      $02, $01, $02,  // version 2 (unsupported)
      $30, $02,
        $05, $00      // NULL
  );
  Check(not TryParsePKCS12(LData, '', LResult, LError), 'Version 2 rejected');
  Check(Length(LError) > 0, 'Error message not empty: ' + LError);
end;

procedure TestResultRecordInit;
var
  LResult: TPKCS12ParseResult;
begin
  WriteLn('TestResultRecordInit');
  FillChar(LResult, SizeOf(LResult), 0);
  Check(Length(LResult.Certificate) = 0, 'Certificate empty');
  Check(Length(LResult.PrivateKey) = 0, 'PrivateKey empty');
  Check(Length(LResult.CACertificates) = 0, 'CACertificates empty');
  Check(LResult.FriendlyName = '', 'FriendlyName empty');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestTooShort;
  TestInvalidASN1;
  TestValidMinimalPKCS12;
  TestWrongVersion;
  TestResultRecordInit;

  WriteLn;
  WriteLn('PKCS#12 tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
