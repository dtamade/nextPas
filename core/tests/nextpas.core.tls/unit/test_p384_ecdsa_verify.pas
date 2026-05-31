program test_p384_ecdsa_verify;

{$mode ObjFPC}{$H+}{$J-}

uses
  {$IFDEF UNIX}cthreads,{$ENDIF}
  SysUtils, nextpas.core.tls.crypto.p384;

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

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

function OpenSSLP384PublicKey: TP384Point;
const
  PUBLIC_POINT =
    '04FB42B3BF2E08FB5CAB85A10ACD66028415C8EAFAD654508D045E7E1409235225C940E4F9FB1B7594F71E8FABA37BB8893344A02' +
    '6E6F0A12E6D0901AC9A2479BECEF256EC353D9F5236BC655279460E41A49F900C336DE9DE06756AD4F383E2B5';
var
  LPoint: TBytes;
begin
  LPoint := HexToBytes(PUBLIC_POINT);
  Result.X := Copy(LPoint, 1, 48);
  Result.Y := Copy(LPoint, 49, 48);
end;

procedure TestDEROpenSSLVectorNormal;
var
  LHash, LSignature: TBytes;
  LError: string;
begin
  WriteLn('TestDEROpenSSLVectorNormal');
  LHash := HexToBytes(
    '8C36572035F38997F90F9FBB69374E9BC41483CC77C487EBC3FC1182191A79825E350585181AF2271449FBFB99078AD9');
  LSignature := HexToBytes(
    '3064023023FFF7E21B8009076D24C5F74B161B768B40AE5343D5B0F2AE9CEC3D47A512A17EF0FBB520528F7555DEA3E3E7B39F50' +
    '02306CB7B78EA8321EB275C7AB2F43C64D0A4C50EA85D14241093B16FF13EF2D6C01FC1BB59FC1C6A85086D55CC5CF291025');
  Check(TryP384ECDSAVerifyDER(LHash, LSignature, OpenSSLP384PublicKey, LError),
    'OpenSSL normal DER signature verifies: ' + LError);
end;

procedure TestDEROpenSSLVectorWithPositiveIntegerPadding;
var
  LHash, LSignature: TBytes;
  LError: string;
begin
  WriteLn('TestDEROpenSSLVectorWithPositiveIntegerPadding');
  LHash := HexToBytes(
    'BD45B931E0F3DC162D1D7BCD040628E7C6F8F4BA03EBE7A33A92F4CD0A0AE8CF84988957810E9FF47402E65B308CC7B4');
  LSignature := HexToBytes(
    '3065023100FB436E13331C5B2197F65187F7A848E5355B81AD0E3B7612494F407718172CC53A45FED541DEAE0833B889A292281776' +
    '02300A4DC24C68BB3AA741B1BC1CD5D8416F94672671BEBAEC67567AB9F0415AF7569940D16177F2A0E8F5DEFFF29B55F968');
  Check(TryP384ECDSAVerifyDER(LHash, LSignature, OpenSSLP384PublicKey, LError),
    'OpenSSL DER signature with INTEGER padding verifies: ' + LError);
end;

procedure TestDEROpenSSLVectorWithShortS;
var
  LHash, LSignature: TBytes;
  LError: string;
begin
  WriteLn('TestDEROpenSSLVectorWithShortS');
  LHash := HexToBytes(
    '3AD3CF98FC125188C87601A320B6D350CF2BDC64D4F577DA7DC334BFFA352AF2D0A93A3D3AE0018BF277563D8307532D');
  LSignature := HexToBytes(
    '3064023100B2CD8D5F11F6948D5F7C496EDC6E891E3BE3CB005D0039F3678EFA5600613FA12CB7FD806173FA02C927617A7957701F' +
    '022F26F501070A8D89544E59200A6B6C35A0772EFC49EB55079D3CCC32E76D72F67FE8F5DEEC4EAA9FAD7811F1727F7017');
  Check(TryP384ECDSAVerifyDER(LHash, LSignature, OpenSSLP384PublicKey, LError),
    'OpenSSL DER signature with short s verifies: ' + LError);
end;

procedure TestInvalidSignatureRejected;
var
  LHash, LSignature: TBytes;
  LError: string;
begin
  WriteLn('TestInvalidSignatureRejected');
  LHash := HexToBytes(
    '8C36572035F38997F90F9FBB69374E9BC41483CC77C487EBC3FC1182191A79825E350585181AF2271449FBFB99078AD9');
  LSignature := HexToBytes(
    '3064023023FFF7E21B8009076D24C5F74B161B768B40AE5343D5B0F2AE9CEC3D47A512A17EF0FBB520528F7555DEA3E3E7B39F51' +
    '02306CB7B78EA8321EB275C7AB2F43C64D0A4C50EA85D14241093B16FF13EF2D6C01FC1BB59FC1C6A85086D55CC5CF291025');
  Check(not TryP384ECDSAVerifyDER(LHash, LSignature, OpenSSLP384PublicKey, LError),
    'Modified DER signature rejected');
end;

procedure TestMalformedDERRejected;
var
  LHash, LSignature: TBytes;
  LError: string;
begin
  WriteLn('TestMalformedDERRejected');
  LHash := HexToBytes(
    '8C36572035F38997F90F9FBB69374E9BC41483CC77C487EBC3FC1182191A79825E350585181AF2271449FBFB99078AD9');
  LSignature := HexToBytes('3006020101020102FF');
  Check(not TryP384ECDSAVerifyDER(LHash, LSignature, OpenSSLP384PublicKey, LError),
    'Trailing data in DER signature rejected');
end;

begin
  LTotal := 0;
  LPassed := 0;

  TestDEROpenSSLVectorNormal;
  TestDEROpenSSLVectorWithPositiveIntegerPadding;
  TestDEROpenSSLVectorWithShortS;
  TestInvalidSignatureRejected;
  TestMalformedDERRejected;

  WriteLn;
  WriteLn('P-384 ECDSA DER tests: ', LPassed, '/', LTotal, ' passed');
  if LPassed <> LTotal then Halt(1);
end.
