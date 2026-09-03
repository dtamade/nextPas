program test_rsa;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.text.conv,
  nextpas.core.crypto.rsa,
  nextpas.core.test;

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
  LSuite := TTestSuite.Create('rsa');

  LSuite.Test('PKCS1v15 encode format', procedure
  var LMsg, LEncoded: TBytes; LError: string; LOk: Boolean;
  begin
    LMsg := HexToBytes('48656c6c6f');
    LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
    CheckTrue(LOk);
    CheckEqual(64, Length(LEncoded));
    CheckTrue((LEncoded[0] = $00) and (LEncoded[1] = $02));
    CheckTrue(LEncoded[64 - 5 - 1] = $00);
    CheckTrue((LEncoded[59] = $48) and (LEncoded[60] = $65) and
      (LEncoded[61] = $6c) and (LEncoded[62] = $6c) and (LEncoded[63] = $6f));
  end);

  LSuite.Test('PKCS1v15 padding non-zero', procedure
  var LMsg, LEncoded: TBytes; LError: string; LOk: Boolean; I: Integer; LAllNZ: Boolean;
  begin
    LMsg := HexToBytes('aa');
    LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
    CheckTrue(LOk);
    LAllNZ := True;
    for I := 2 to 64 - 1 - 1 - 1 do
      if LEncoded[I] = 0 then LAllNZ := False;
    CheckTrue(LAllNZ);
  end);

  LSuite.Test('message too long rejected', procedure
  var LMsg, LEncoded: TBytes; LError: string; LOk: Boolean;
  begin
    SetLength(LMsg, 54);
    LOk := TryRSAES_PKCS1v15_Encode(LMsg, 64, LEncoded, LError);
    CheckTrue(not LOk);
    CheckTrue(Pos('too long', LError) > 0);
  end);

  LSuite.Test('encrypt small key', procedure
  var LMsg, LMod, LExp, LCipher: TBytes; LError: string; LOk: Boolean;
  begin
    LMsg := HexToBytes('48656c6c6f');
    LMod := HexToBytes('D4BCD52406F2C926267E902E2B8F6B6B5B1B3A5412C4A7C8E0F8B2D3C4A5B6C7D8E9F0A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8091A2B3C4D5E6F70818293');
    LExp := HexToBytes('010001');
    LOk := TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher, LError);
    CheckTrue(LOk);
    CheckEqual(Length(LMod), Length(LCipher));
    CheckTrue(BytesToHex(LCipher) <> BytesToHex(LMsg));
  end);

  LSuite.Test('short modulus rejected', procedure
  var LMsg, LMod, LExp, LCipher: TBytes; LError: string; LOk: Boolean;
  begin
    LMsg := HexToBytes('aa');
    SetLength(LMod, 32);
    LExp := HexToBytes('010001');
    LOk := TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LCipher, LError);
    CheckTrue(not LOk);
  end);

  LSuite.Test('encrypt randomized', procedure
  var LMsg, LMod, LExp, LC1, LC2: TBytes; LError: string;
  begin
    LMsg := HexToBytes('48656c6c6f');
    LMod := HexToBytes('D4BCD52406F2C926267E902E2B8F6B6B5B1B3A5412C4A7C8E0F8B2D3C4A5B6C7D8E9F0A1B2C3D4E5F6A7B8C9D0E1F2A3B4C5D6E7F8091A2B3C4D5E6F70818293');
    LExp := HexToBytes('010001');
    TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LC1, LError);
    TryRSAES_PKCS1v15_Encrypt(LMsg, LMod, LExp, LC2, LError);
    CheckTrue(BytesToHex(LC1) <> BytesToHex(LC2));
  end);

  LRunner := TSuiteRunner.Create('nextpas.core.crypto.rsa');
  LRunner.Add(LSuite);
  LRunner.RunAll;
  LRunner.Summary;
  if not LRunner.AllPassed then Halt(1);
end.
