program test_config_cross_fuzz;
{**
 * @desc config 跨格式差分 fuzz：同一逻辑配置经 json/toml/yaml/ini 四种
 *       格式加载后，键集/原始值/typed getter 结果必须四路全等（家族
 *       "统一 flat key/value 模型"价值主张的可执行验证）；导出往返环
 *       （ToXxx → AddXxx → 键值保真 + 文本幂等）覆盖 export 面。
 *       种子固定，失败可复现。
 *}

{$I nextpas.core.settings.inc}

uses
  nextpas.core.base,
  nextpas.core.errors,
  nextpas.core.text.conv,
  nextpas.core.config,
  nextpas.core.test;

type
  TEntryKind = (ekStr, ekInt, ekBool, ekFloat);
  TEntry = record
    Key: string;     { 完整 config 键：'ta' 或 'sa.kb' }
    Section: string; { '' = 顶层 }
    Local: string;
    Kind: TEntryKind;
    S: string;
    I: Int64;
    B: Boolean;
    F: Double;
  end;
  TLogical = record
    Entries: array of TEntry;
    Sections: TStringArray;
  end;

var
  T: TTestSuite;
  GSeed: UInt32 = 12345;

function Rng: UInt32;
begin
  { xorshift32 — 与家族 fuzz 套件同款确定性序列 }
  GSeed := GSeed xor (GSeed shl 13);
  GSeed := GSeed xor (GSeed shr 17);
  GSeed := GSeed xor (GSeed shl 5);
  Result := GSeed;
end;

function RngRange(AMax: UInt32): UInt32;
begin
  Result := Rng mod AMax;
end;

function SafeString: string;
var
  LI, LLen: Integer;
begin
  LLen := Integer(RngRange(8)) + 3;
  SetLength(Result, LLen);
  for LI := 1 to LLen do
    Result[LI] := Chr(Ord('a') + RngRange(26));
end;

function TortureString: string;
const
  { 各格式敏感字符交集攻击面（无换行/反斜杠/前导空格：INI 无转义语法） }
  CAttack: string = '";''#=,[]{}$:() .-_ab3';
var
  LI, LLen: Integer;
begin
  LLen := Integer(RngRange(12)) + 1;
  SetLength(Result, LLen);
  Result[1] := Chr(Ord('a') + RngRange(26)); { 首字符字母：INI 值 TrimLeft }
  for LI := 2 to LLen do
    Result[LI] := CAttack[RngRange(Length(CAttack)) + 1];
end;

function FloatLit(const AF: Double): string;
var
  LWhole: Int64;
  LFrac: Integer;
begin
  { 值域构造保证非负、frac 为 0/.25/.5/.75，二进制精确 }
  LWhole := Trunc(AF);
  LFrac := Round((AF - LWhole) * 100);
  case LFrac of
    25: Result := IntToStr(LWhole) + '.25';
    50: Result := IntToStr(LWhole) + '.5';
    75: Result := IntToStr(LWhole) + '.75';
  else
    Result := IntToStr(LWhole) + '.0';
  end;
end;

procedure FillValue(var AE: TEntry; ATorture: Boolean);
begin
  AE.Kind := TEntryKind(RngRange(4));
  if ATorture then
    AE.Kind := ekStr; { 酷刑轮全字符串 }
  case AE.Kind of
    ekStr:
      if ATorture then
        AE.S := TortureString
      else
        AE.S := SafeString;
    ekInt:
      AE.I := Int64(RngRange(2000000000)) - 1000000000;
    ekBool:
      AE.B := (Rng and 1) = 0;
    ekFloat:
      AE.F := Double(RngRange(100)) + Double(RngRange(4)) * 0.25;
  end;
end;

function GenLogical(ATorture: Boolean): TLogical;
var
  LTop, LSecs, LKeys, LI, LJ, LN: Integer;
  LE: TEntry;
begin
  Result.Entries := nil;
  Result.Sections := nil;
  LN := 0;
  LTop := Integer(RngRange(3)); { 0-2 顶层键 }
  for LI := 0 to LTop - 1 do
  begin
    LE.Section := '';
    LE.Local := 't' + Chr(Ord('a') + LI);
    LE.Key := LE.Local;
    FillValue(LE, ATorture);
    SetLength(Result.Entries, LN + 1);
    Result.Entries[LN] := LE;
    Inc(LN);
  end;
  LSecs := Integer(RngRange(3)) + 1; { 1-3 段 }
  SetLength(Result.Sections, LSecs);
  for LI := 0 to LSecs - 1 do
  begin
    Result.Sections[LI] := 's' + Chr(Ord('a') + LI);
    LKeys := Integer(RngRange(3)) + 1; { 每段 1-3 键 }
    for LJ := 0 to LKeys - 1 do
    begin
      LE.Section := Result.Sections[LI];
      LE.Local := 'k' + Chr(Ord('a') + LJ);
      LE.Key := LE.Section + '.' + LE.Local;
      FillValue(LE, ATorture);
      SetLength(Result.Entries, LN + 1);
      Result.Entries[LN] := LE;
      Inc(LN);
    end;
  end;
end;

function EscQuoted(const AStr: string): string;
var
  LI: Integer;
begin
  { json/toml basic/yaml 双引号标量共用：\" 与 \\ }
  Result := '"';
  for LI := 1 to Length(AStr) do
    case AStr[LI] of
      '"': Result := Result + '\"';
      '\': Result := Result + '\\';
    else
      Result := Result + AStr[LI];
    end;
  Result := Result + '"';
end;

function RenderScalar(const AE: TEntry; AQuoted: Boolean): string;
begin
  case AE.Kind of
    ekStr:
      if AQuoted then
        Result := EscQuoted(AE.S)
      else
        Result := AE.S;
    ekInt: Result := IntToStr(AE.I);
    ekBool: if AE.B then Result := 'true' else Result := 'false';
    ekFloat: Result := FloatLit(AE.F);
  end;
end;

function SerJson(const AL: TLogical): string;
var
  LI, LJ: Integer;
  LFirst: Boolean;
begin
  Result := '{';
  LFirst := True;
  for LI := 0 to High(AL.Entries) do
    if AL.Entries[LI].Section = '' then
    begin
      if not LFirst then Result := Result + ',';
      Result := Result + '"' + AL.Entries[LI].Local + '":'
        + RenderScalar(AL.Entries[LI], True);
      LFirst := False;
    end;
  for LJ := 0 to High(AL.Sections) do
  begin
    if not LFirst then Result := Result + ',';
    Result := Result + '"' + AL.Sections[LJ] + '":{';
    LFirst := True;
    for LI := 0 to High(AL.Entries) do
      if AL.Entries[LI].Section = AL.Sections[LJ] then
      begin
        if not LFirst then Result := Result + ',';
        Result := Result + '"' + AL.Entries[LI].Local + '":'
          + RenderScalar(AL.Entries[LI], True);
        LFirst := False;
      end;
    Result := Result + '}';
    LFirst := False;
  end;
  Result := Result + '}';
end;

function SerToml(const AL: TLogical): string;
var
  LI, LJ: Integer;
begin
  Result := '';
  for LI := 0 to High(AL.Entries) do
    if AL.Entries[LI].Section = '' then
      Result := Result + AL.Entries[LI].Local + ' = '
        + RenderScalar(AL.Entries[LI], True) + #10;
  for LJ := 0 to High(AL.Sections) do
  begin
    Result := Result + '[' + AL.Sections[LJ] + ']' + #10;
    for LI := 0 to High(AL.Entries) do
      if AL.Entries[LI].Section = AL.Sections[LJ] then
        Result := Result + AL.Entries[LI].Local + ' = '
          + RenderScalar(AL.Entries[LI], True) + #10;
  end;
end;

function SerYaml(const AL: TLogical): string;
var
  LI, LJ: Integer;
begin
  { 块风格；标量统一双引号，规避裸标量歧义（#注释、: 冒号等） }
  Result := '';
  for LI := 0 to High(AL.Entries) do
    if AL.Entries[LI].Section = '' then
      Result := Result + AL.Entries[LI].Local + ': '
        + RenderScalar(AL.Entries[LI], True) + #10;
  for LJ := 0 to High(AL.Sections) do
  begin
    Result := Result + AL.Sections[LJ] + ':' + #10;
    for LI := 0 to High(AL.Entries) do
      if AL.Entries[LI].Section = AL.Sections[LJ] then
        Result := Result + '  ' + AL.Entries[LI].Local + ': '
          + RenderScalar(AL.Entries[LI], True) + #10;
  end;
end;

function SerIni(const AL: TLogical): string;
var
  LI, LJ: Integer;
begin
  Result := '';
  for LI := 0 to High(AL.Entries) do
    if AL.Entries[LI].Section = '' then
      Result := Result + AL.Entries[LI].Local + '='
        + RenderScalar(AL.Entries[LI], False) + #10;
  for LJ := 0 to High(AL.Sections) do
  begin
    Result := Result + '[' + AL.Sections[LJ] + ']' + #10;
    for LI := 0 to High(AL.Entries) do
      if AL.Entries[LI].Section = AL.Sections[LJ] then
        Result := Result + AL.Entries[LI].Local + '='
          + RenderScalar(AL.Entries[LI], False) + #10;
  end;
end;

procedure CheckEntryAcross(const AE: TEntry; const ACfgs: array of IConfig);
var
  LK: Integer;
  LRaw0, LRaw, LStr0: string;
  LInt: Int64;
  LBool: Boolean;
  LFloat: Double;
begin
  LRaw0 := ACfgs[0].GetRawString(AE.Key, '<missing>');
  LStr0 := ACfgs[0].GetString(AE.Key, '<missing>');
  for LK := 0 to High(ACfgs) do
  begin
    Check(ACfgs[LK].Has(AE.Key), 'key present in every format');
    LRaw := ACfgs[LK].GetRawString(AE.Key, '<missing>');
    { raw 跨格式等值仅对无歧义表示成立：float 文本表示各格式不同
      （ini "50" vs json "50.0"，数值断言见下）；含 " 或 \ 的字符串因
      json/toml/yaml 转义语法而 raw 不同（解码后 GetString 断言见下）。 }
    if (AE.Kind <> ekFloat) and
       ((AE.Kind <> ekStr) or
        ((Pos('"', AE.S) = 0) and (Pos('\', AE.S) = 0))) then
      CheckEqual(LRaw0, LRaw, 'raw string equal across formats');
    { interpolated 表示对 float 因格式规范化而异（ini "50" vs json "50.0"），
      数值一致性由 TryGetFloat 断言覆盖 }
    if AE.Kind <> ekFloat then
      CheckEqual(LStr0, ACfgs[LK].GetString(AE.Key, '<missing>'),
        'interpolated string equal across formats');
    case AE.Kind of
      ekStr:
        CheckEqual(AE.S, LRaw, 'raw string matches source value');
      ekInt:
      begin
        Check(ACfgs[LK].TryGetInt(AE.Key, LInt), 'TryGetInt succeeds');
        CheckEqual(AE.I, LInt, 'int value matches across formats');
      end;
      ekBool:
      begin
        Check(ACfgs[LK].TryGetBool(AE.Key, LBool), 'TryGetBool succeeds');
        CheckEqual(AE.B, LBool, 'bool value matches across formats');
      end;
      ekFloat:
      begin
        Check(ACfgs[LK].TryGetFloat(AE.Key, LFloat), 'TryGetFloat succeeds');
        Check(Abs(LFloat - AE.F) < 1e-9, 'float value matches across formats');
      end;
    end;
  end;
end;

procedure RunCrossRounds(ARounds: Integer; ATorture: Boolean; const ALabel: string);
var
  LR, LI: Integer;
  LL: TLogical;
  LCfgs: array[0..3] of IConfig;
begin
  for LR := 1 to ARounds do
  begin
    LL := GenLogical(ATorture);
    LCfgs[0] := ConfigBuilder.AddJson(SerJson(LL)).Build;
    LCfgs[1] := ConfigBuilder.AddToml(SerToml(LL)).Build;
    LCfgs[2] := ConfigBuilder.AddYaml(SerYaml(LL)).Build;
    LCfgs[3] := ConfigBuilder.AddIni(SerIni(LL)).Build;
    CheckEqual(Int64(Length(LL.Entries)), Int64(LCfgs[0].Count),
      ALabel + ': json entry count');
    for LI := 1 to 3 do
      CheckEqual(Int64(LCfgs[0].Count), Int64(LCfgs[LI].Count),
        ALabel + ': entry count equal across formats');
    for LI := 0 to High(LL.Entries) do
      CheckEntryAcross(LL.Entries[LI], LCfgs);
  end;
end;

procedure TestCrossFormatTyped;
begin
  RunCrossRounds(200, False, 'typed');
end;

procedure TestCrossFormatTorture;
begin
  RunCrossRounds(100, True, 'torture');
end;

procedure RunExportRoundtrip(ARounds: Integer; ATorture: Boolean; const ALabel: string);
var
  LR, LI, LF: Integer;
  LL: TLogical;
  LBase, LRe: IConfig;
  LText, LText2, LKey: string;
begin
  for LR := 1 to ARounds do
  begin
    LL := GenLogical(ATorture);
    LBase := ConfigBuilder.AddJson(SerJson(LL)).Build;
    for LF := 0 to 3 do
    begin
      case LF of
        0: LText := LBase.ToIni;
        1: LText := LBase.ToJson;
        2: LText := LBase.ToYaml;
      else
        LText := LBase.ToToml;
      end;
      case LF of
        0: LRe := ConfigBuilder.AddIni(LText).Build;
        1: LRe := ConfigBuilder.AddJson(LText).Build;
        2: LRe := ConfigBuilder.AddYaml(LText).Build;
      else
        LRe := ConfigBuilder.AddToml(LText).Build;
      end;
      CheckEqual(Int64(LBase.Count), Int64(LRe.Count),
        ALabel + ': roundtrip preserves entry count');
      for LI := 0 to High(LL.Entries) do
      begin
        LKey := LL.Entries[LI].Key;
        { 含转义字符字符串的 raw 经导出/重载后因格式转义语法而异，
          此处跳过（文本幂等断言仍覆盖导出面）；其余类型 raw 保真必查。 }
        if (LL.Entries[LI].Kind <> ekStr) or
           ((Pos('"', LL.Entries[LI].S) = 0) and
            (Pos('\', LL.Entries[LI].S) = 0)) then
          CheckEqual(LBase.GetRawString(LKey, '<missing>'),
            LRe.GetRawString(LKey, '<missing>'),
            ALabel + ': roundtrip preserves raw value');
      end;
      case LF of
        0: LText2 := LRe.ToIni;
        1: LText2 := LRe.ToJson;
        2: LText2 := LRe.ToYaml;
      else
        LText2 := LRe.ToToml;
      end;
      CheckEqual(LText, LText2, ALabel + ': export is idempotent');
    end;
  end;
end;

procedure TestExportRoundtrip;
begin
  RunExportRoundtrip(100, False, 'export');
end;

procedure TestExportRoundtripTorture;
begin
  RunExportRoundtrip(100, True, 'export-torture');
end;

begin
  T := TTestSuite.Create('nextpas.core.config cross-format fuzz');
  T.Test('cross-format typed equality (200)', @TestCrossFormatTyped);
  T.Test('cross-format string torture (100)', @TestCrossFormatTorture);
  T.Test('export roundtrip x4 (100)', @TestExportRoundtrip);
  T.Test('export roundtrip torture x4 (100)', @TestExportRoundtripTorture);
  if not T.Run then Halt(1);
end.
