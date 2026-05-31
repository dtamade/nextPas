program test_http_h1scan;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.testing,
  nextpas.core.http.impl.h1.scan;

var
  T: TTestRunner;

procedure TestFindCRLF_AtStart;
var LBuf: string;
begin
  LBuf := #13#10'Hello';
  CheckEqual(Int64(0), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'CRLF at pos 0');
end;

procedure TestFindCRLF_AtMiddle;
var LBuf: string;
begin
  LBuf := 'Hello'#13#10'World';
  CheckEqual(Int64(5), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'CRLF at pos 5');
end;

procedure TestFindCRLF_AtEnd;
var LBuf: string;
begin
  LBuf := 'Hello World'#13#10;
  CheckEqual(Int64(11), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'CRLF at end');
end;

procedure TestFindCRLF_NotFound;
var LBuf: string;
begin
  LBuf := 'Hello World';
  CheckEqual(Int64(-1), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'no CRLF');
end;

procedure TestFindCRLF_LoneCR;
var LBuf: string;
begin
  LBuf := 'Hello'#13'World';
  CheckEqual(Int64(-1), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'lone CR no LF');
end;

procedure TestFindDoubleCRLF_Found;
var LBuf: string;
begin
  LBuf := 'Host: localhost'#13#10#13#10'body';
  CheckEqual(Int64(15), Int64(ScanFindDoubleCRLF(PAnsiChar(LBuf), Length(LBuf))), 'double CRLF found');
end;

procedure TestFindDoubleCRLF_NotFound;
var LBuf: string;
begin
  LBuf := 'Host: localhost'#13#10'Next: val'#13#10;
  CheckEqual(Int64(-1), Int64(ScanFindDoubleCRLF(PAnsiChar(LBuf), Length(LBuf))), 'no double CRLF');
end;

procedure TestFindDoubleCRLF_AtEnd;
var LBuf: string;
begin
  LBuf := 'GET / HTTP/1.1'#13#10'Host: x'#13#10#13#10;
  CheckEqual(Int64(23), Int64(ScanFindDoubleCRLF(PAnsiChar(LBuf), Length(LBuf))), 'double CRLF at end');
end;

procedure TestFindColon_Found;
var LBuf: string;
begin
  LBuf := 'Content-Type: text/plain';
  CheckEqual(Int64(12), Int64(ScanFindColon(PAnsiChar(LBuf), Length(LBuf))), 'colon at 12');
end;

procedure TestFindColon_NotFound;
var LBuf: string;
begin
  LBuf := 'no colon here';
  CheckEqual(Int64(-1), Int64(ScanFindColon(PAnsiChar(LBuf), Length(LBuf))), 'no colon');
end;

procedure TestValidateToken_Valid;
var LBuf: string;
begin
  LBuf := 'Content-Type';
  Check(ScanValidateToken(PAnsiChar(LBuf), Length(LBuf)), 'valid token');
end;

procedure TestValidateToken_InvalidSpace;
var LBuf: string;
begin
  LBuf := 'Content Type';
  Check(not ScanValidateToken(PAnsiChar(LBuf), Length(LBuf)), 'space is invalid');
end;

procedure TestValidateToken_InvalidCTL;
var LBuf: string;
begin
  LBuf := 'Content'#0'Type';
  Check(not ScanValidateToken(PAnsiChar(LBuf), Length(LBuf)), 'CTL is invalid');
end;

procedure TestEmpty_CRLF;
begin
  CheckEqual(Int64(-1), Int64(ScanFindCRLF(nil, 0)), 'empty CRLF');
end;

procedure TestEmpty_DoubleCRLF;
begin
  CheckEqual(Int64(-1), Int64(ScanFindDoubleCRLF(nil, 0)), 'empty double CRLF');
end;

procedure TestEmpty_Colon;
begin
  CheckEqual(Int64(-1), Int64(ScanFindColon(nil, 0)), 'empty colon');
end;

procedure TestEmpty_ValidateToken;
begin
  Check(ScanValidateToken(nil, 0), 'empty token is valid');
end;

procedure TestLargeInput_CRLF;
var
  LBuf: string;
  LI: Integer;
begin
  { 80 bytes of 'A' then CRLF — forces multiple SIMD passes }
  SetLength(LBuf, 82);
  for LI := 1 to 80 do
    LBuf[LI] := 'A';
  LBuf[81] := #13;
  LBuf[82] := #10;
  CheckEqual(Int64(80), Int64(ScanFindCRLF(PAnsiChar(LBuf), Length(LBuf))), 'CRLF after 80 bytes');
end;

procedure TestLargeInput_DoubleCRLF;
var
  LBuf: string;
  LI: Integer;
begin
  { 80 bytes of 'A' then \r\n\r\n }
  SetLength(LBuf, 84);
  for LI := 1 to 80 do
    LBuf[LI] := 'A';
  LBuf[81] := #13;
  LBuf[82] := #10;
  LBuf[83] := #13;
  LBuf[84] := #10;
  CheckEqual(Int64(80), Int64(ScanFindDoubleCRLF(PAnsiChar(LBuf), Length(LBuf))), 'double CRLF after 80 bytes');
end;

begin
  T := TTestRunner.Create('nextpas.core.http.impl.h1.scan');
  T.Run('FindCRLF at start', @TestFindCRLF_AtStart);
  T.Run('FindCRLF at middle', @TestFindCRLF_AtMiddle);
  T.Run('FindCRLF at end', @TestFindCRLF_AtEnd);
  T.Run('FindCRLF not found', @TestFindCRLF_NotFound);
  T.Run('FindCRLF lone CR', @TestFindCRLF_LoneCR);
  T.Run('FindDoubleCRLF found', @TestFindDoubleCRLF_Found);
  T.Run('FindDoubleCRLF not found', @TestFindDoubleCRLF_NotFound);
  T.Run('FindDoubleCRLF at end', @TestFindDoubleCRLF_AtEnd);
  T.Run('FindColon found', @TestFindColon_Found);
  T.Run('FindColon not found', @TestFindColon_NotFound);
  T.Run('ValidateToken valid', @TestValidateToken_Valid);
  T.Run('ValidateToken invalid space', @TestValidateToken_InvalidSpace);
  T.Run('ValidateToken invalid CTL', @TestValidateToken_InvalidCTL);
  T.Run('Empty CRLF', @TestEmpty_CRLF);
  T.Run('Empty DoubleCRLF', @TestEmpty_DoubleCRLF);
  T.Run('Empty Colon', @TestEmpty_Colon);
  T.Run('Empty ValidateToken', @TestEmpty_ValidateToken);
  T.Run('Large input CRLF', @TestLargeInput_CRLF);
  T.Run('Large input DoubleCRLF', @TestLargeInput_DoubleCRLF);
  T.Summary;
end.
