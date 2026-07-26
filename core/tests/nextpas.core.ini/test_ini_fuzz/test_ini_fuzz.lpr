program test_ini_fuzz;
{**
 * @desc INI 确定性 fuzz：随机/二进制/半合法输入下不崩溃、不挂起、不泄漏；
 *       TryLoadFromString 契约不外泄异常；write→ToString→reparse 往返一致。
 *       种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.ini,
  nextpas.core.test;

var
  T: TTestSuite;
  GSeed: UInt32 = 12345;

function Rng: UInt32;
begin
  { xorshift32 — 与 test_toml_fuzz 同款确定性序列 }
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
  { INI 敏感字符加权：段括号/等号/注释/空白 }
  CCharset: string = 'abc123[]=;# ' + #9 + #10 + #13 + '[]==';
begin
  Result := CCharset[RngRange(Length(CCharset)) + 1];
end;

function GenerateRandom(const ALen: Integer): string;
var
  LI: Integer;
begin
  SetLength(Result, ALen);
  for LI := 1 to ALen do
    Result[LI] := RngChar;
end;

function GenerateSemiValid(const ALen: Integer): string;
var
  LI: Integer;
begin
  Result := '';
  LI := 0;
  while LI < ALen do
  begin
    case RngRange(8) of
      0: { 段头 }
      begin
        Result := Result + '[s' + Chr(Ord('a') + RngRange(26)) + ']' + #10;
        Inc(LI, 5);
      end;
      1: { 键值对 }
      begin
        Result := Result + 'k' + Chr(Ord('a') + RngRange(26)) + ' = v'
          + Chr(Ord('0') + RngRange(10)) + #10;
        Inc(LI, 9);
      end;
      2: { 分号注释 }
      begin
        Result := Result + '; comment' + #10;
        Inc(LI, 10);
      end;
      3: { 井号注释 }
      begin
        Result := Result + '# hash comment' + #10;
        Inc(LI, 15);
      end;
      4: { 空行 }
      begin
        Result := Result + #10;
        Inc(LI, 1);
      end;
      5: { 未闭合段头（错误路径） }
      begin
        Result := Result + '[open' + #10;
        Inc(LI, 6);
      end;
      6: { 无等号裸行（错误路径） }
      begin
        Result := Result + 'bare line' + #10;
        Inc(LI, 10);
      end;
      7: { 空键/空值边界 }
      begin
        Result := Result + '=' + #10 + 'k=' + #10;
        Inc(LI, 5);
      end;
    end;
  end;
end;

{ FuzzOneInput — TryLoadFromString 契约：无异常外泄、失败时错误可读。
  返回 False 表示契约被破坏。 }
function FuzzOneInput(const AInput: string): Boolean;
var
  LIni: TIniFile;
  LError: TIniError;
  LOk: Boolean;
begin
  Result := True;
  LIni := TIniFile.Create;
  try
    try
      LOk := LIni.TryLoadFromString(AInput, LError);
      if not LOk then
        if LError.Message = '' then
          Exit(False); { 失败必须携带可读错误信息 }
    except
      Exit(False); { Try 契约：不允许异常外泄 }
    end;
  finally
    LIni.Free;
  end;
end;

procedure TestRandomInputNoCrash;
var
  LI: Integer;
begin
  for LI := 1 to 1000 do
    Check(FuzzOneInput(GenerateRandom(RngRange(200) + 1)),
      'random input honors Try contract');
end;

procedure TestBinaryGarbage;
var
  LInput: string;
  LI, LJ: Integer;
begin
  for LI := 1 to 200 do
  begin
    SetLength(LInput, RngRange(100) + 1);
    for LJ := 1 to Length(LInput) do
      LInput[LJ] := AnsiChar(Rng and $FF);
    Check(FuzzOneInput(LInput), 'binary garbage honors Try contract');
  end;
end;

procedure TestSemiValidNoCrash;
var
  LI, LClean: Integer;
  LIni: TIniFile;
  LError: TIniError;
begin
  LClean := 0;
  for LI := 1 to 500 do
  begin
    LIni := TIniFile.Create;
    try
      if LIni.TryLoadFromString(GenerateSemiValid(RngRange(500) + 10), LError) then
        Inc(LClean);
    finally
      LIni.Free;
    end;
  end;
  Check(LClean > 0, 'some semi-valid inputs load clean');
  Check(True, '500 semi-valid inputs no crash');
end;

procedure TestRepeatedStructures;
var
  LInput: string;
  LI: Integer;
begin
  { 大量嵌套无关但重复的结构：段头/等号/括号洪水 }
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[';
  Check(FuzzOneInput(LInput), '500 open brackets no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '=';
  Check(FuzzOneInput(LInput), '500 equals no crash');

  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[s]' + #10;
  Check(FuzzOneInput(LInput), '500 repeated section headers no crash');
end;

procedure TestRoundtripFuzz;
var
  LIni, LReparsed: TIniFile;
  LError: TIniError;
  LRound, LI: Integer;
  LSection, LKey, LValue: string;
  LSections: array of array of string; { [i]: section, key, value }
  LText: string;
begin
  { write→ToString→reparse：程序化写入的任意可打印值必须无损往返 }
  for LRound := 1 to 100 do
  begin
    LIni := TIniFile.Create;
    try
      SetLength(LSections, Integer(RngRange(5)) + 1);
      for LI := 0 to High(LSections) do
      begin
        SetLength(LSections[LI], 3);
        LSection := 'sec' + Chr(Ord('a') + RngRange(26)) + Chr(Ord('0') + UInt32(LI));
        LKey := 'key' + Chr(Ord('a') + RngRange(26));
        LValue := 'v' + Chr(Ord('!') + RngRange(90)) + Chr(Ord('!') + RngRange(90));
        LSections[LI][0] := LSection;
        LSections[LI][1] := LKey;
        LSections[LI][2] := LValue;
        LIni.WriteString(LSection, LKey, LValue);
      end;
      LText := LIni.ToString;
      LReparsed := TIniFile.Create;
      try
        Check(LReparsed.TryLoadFromString(LText, LError), 'roundtrip reparse ok');
        for LI := 0 to High(LSections) do
          CheckEqual(LSections[LI][2],
            LReparsed.ReadString(LSections[LI][0], LSections[LI][1], '<missing>'),
            'roundtrip value preserved');
      finally
        LReparsed.Free;
      end;
    finally
      LIni.Free;
    end;
  end;
  Check(True, '100 roundtrip fuzz rounds ok');
end;

procedure TestLargeValidDocument;
var
  LIni: TIniFile;
  LError: TIniError;
  LInput: string;
  LI: Integer;
begin
  LInput := '';
  for LI := 1 to 500 do
    LInput := LInput + '[section_' + Chr(Ord('a') + (LI mod 26))
      + Chr(Ord('a') + (LI div 26) mod 26) + Chr(Ord('0') + LI mod 10) + ']' + #10
      + 'value = ' + Chr(Ord('0') + LI mod 10) + #10;
  LIni := TIniFile.Create;
  try
    Check(LIni.TryLoadFromString(LInput, LError), 'large valid document ok');
    Check(Length(LIni.GetSections) > 0, 'sections materialized');
  finally
    LIni.Free;
  end;
end;

begin
  T := TTestSuite.Create('nextpas.core.ini fuzz');
  T.Test('random input no crash (1000)', @TestRandomInputNoCrash);
  T.Test('binary garbage no crash (200)', @TestBinaryGarbage);
  T.Test('semi-valid no crash (500)', @TestSemiValidNoCrash);
  T.Test('repeated structures', @TestRepeatedStructures);
  T.Test('roundtrip fuzz (100)', @TestRoundtripFuzz);
  T.Test('large valid document (500 sections)', @TestLargeValidDocument);
  if not T.Run then Halt(1);
end.
