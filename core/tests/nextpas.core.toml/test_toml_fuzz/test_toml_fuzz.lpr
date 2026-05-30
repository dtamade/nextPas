program test_toml_fuzz;

{$I nextpas.core.settings.inc}

uses
  nextpas.core.text.view,
  nextpas.core.toml.base,
  nextpas.core.toml,
  nextpas.core.testing;

var
  T: TTestRunner;
  GSeed: UInt32 = 12345;

function Rng: UInt32;
begin
  GSeed := GSeed xor (GSeed shl 13);
  GSeed := GSeed xor (GSeed shr 17);
  GSeed := GSeed xor (GSeed shl 5);
  Result := GSeed;
end;

function RngRange(AMax: UInt32): UInt32;
begin
  Result := Rng mod AMax;
end;

function RngChar: AnsiChar;
const
  CHARS = 'abcdefghijklmnopqrstuvwxyz0123456789-_"''=[]{}.,#'#10#13#9' \/:+';
begin
  Result := CHARS[1 + RngRange(Length(CHARS))];
end;

function GenerateRandom(ALen: Integer): string;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 1 to ALen do
    Result[LI] := RngChar;
end;

function GenerateSemiValid(ALen: Integer): string;
var
  LI: Integer;
  LChoice: UInt32;
begin
  Result := '';
  LI := 0;
  while LI < ALen do
  begin
    LChoice := RngRange(10);
    case LChoice of
      0..3: // key = "value"\n
      begin
        Result := Result + 'k' + Chr(Ord('a') + RngRange(26)) + ' = "v' + Chr(Ord('a') + RngRange(26)) + '"' + #10;
        Inc(LI, 12);
      end;
      4: // key = 123\n
      begin
        Result := Result + 'n' + Chr(Ord('a') + RngRange(26)) + ' = ' + Chr(Ord('0') + RngRange(10)) + #10;
        Inc(LI, 8);
      end;
      5: // [table]\n
      begin
        Result := Result + '[t' + Chr(Ord('a') + RngRange(26)) + ']' + #10;
        Inc(LI, 6);
      end;
      6: // # comment\n
      begin
        Result := Result + '# comment' + #10;
        Inc(LI, 10);
      end;
      7: // array
      begin
        Result := Result + 'a' + Chr(Ord('a') + RngRange(26)) + ' = [1, 2, 3]' + #10;
        Inc(LI, 16);
      end;
      8: // inline table
      begin
        Result := Result + 'i' + Chr(Ord('a') + RngRange(26)) + ' = {x = 1}' + #10;
        Inc(LI, 14);
      end;
      9: // empty line
      begin
        Result := Result + #10;
        Inc(LI, 1);
      end;
    end;
  end;
end;

procedure TestRandomInputNoCrash;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  for LI := 1 to 1000 do
  begin
    LInput := GenerateRandom(RngRange(200) + 1);
    LDoc := TomlParse(LInput);
  end;
  Check(True, '1000 random inputs no crash');
end;

procedure TestSemiValidNoCrash;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
  LPassed: Integer;
begin
  LPassed := 0;
  for LI := 1 to 500 do
  begin
    LInput := GenerateSemiValid(RngRange(500) + 10);
    LDoc := TomlParse(LInput);
    if not LDoc.HasError then
      Inc(LPassed);
  end;
  Check(LPassed > 0, 'some semi-valid inputs parse ok');
  Check(True, '500 semi-valid inputs no crash');
end;

procedure TestBinaryGarbage;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI, LJ: Integer;
begin
  for LI := 1 to 200 do
  begin
    SetLength(LInput, RngRange(100) + 1);
    for LJ := 1 to Length(LInput) do
      LInput[LJ] := AnsiChar(Rng and $FF);
    LDoc := TomlParse(LInput);
  end;
  Check(True, '200 binary garbage inputs no crash');
end;

procedure TestRepeatedStructures;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  // Many opening brackets
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'many [ rejected');

  // Many quotes
  LInput := 'x = ';
  for LI := 1 to 500 do
    LInput := LInput + '"';
  LDoc := TomlParse(LInput);

  // Many equals
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '= ';
  LDoc := TomlParse(LInput);
  Check(LDoc.HasError, 'many = rejected');

  // Many newlines with keys
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + 'k = 1' + #10;
  LDoc := TomlParse(LInput);
  // This should fail due to duplicate key 'k'
  Check(LDoc.HasError, 'duplicate k rejected');

  Check(True, 'repeated structures no crash');
end;

procedure TestLargeValidDocument;
var
  LDoc: ITomlDocument;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[section_' + Chr(Ord('a') + (LI mod 26)) + Chr(Ord('a') + (LI div 26) mod 26) + Chr(Ord('0') + LI mod 10) + ']' + #10 +
      'value = ' + Chr(Ord('0') + LI mod 10) + #10;
  LDoc := TomlParse(LInput);
  Check(not LDoc.HasError, 'large valid document ok');
end;

begin
  T := TTestRunner.Create('nextpas.core.toml fuzz');
  T.Run('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Run('semi-valid no crash (500)', @TestSemiValidNoCrash);
  T.Run('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Run('repeated structures', @TestRepeatedStructures);
  T.Run('large valid document (500 sections)', @TestLargeValidDocument);
  T.Summary;
  if not T.AllPassed then Halt(1);
end.
