{**
 * @desc 跨语言基准测试解析器
 *
 * 支持解析 Go testing.B、Rust criterion、FPC RTL bench 输出，
 * 并统一转换为 TBenchResult 格式。
 *}
unit nextpas.core.bench.xlang;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  nextpas.core.exception,
  nextpas.core.bench.base;

type
  {** 从 base 模块 re-export 数组类型 }
  TBenchResultArray = nextpas.core.bench.base.TBenchResultArray;

  {**
   * 解析器类型
   *}
  TXLangParser = (xlGo, xlRust, xlFPC);

  {** 解析错误（re-export 自 nextpas.core.exception） }
  EParseError = nextpas.core.exception.EParseError;

  {**
   * 解析单行 Go bench 输出
   * 示例: "BenchmarkFoo-8   1000000   1234 ns/op   456 B/op   7 allocs/op"
   *}
  function ParseGoBenchLine(const ALine: string): TBenchResult;

  {**
   * 解析多行 Go bench 输出
   *}
  function ParseGoBenchOutput(const AOutput: string): TBenchResultArray;

  {**
   * 解析单行 Rust criterion 输出
   * 示例: "BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]"
   *}
  function ParseRustBenchLine(const ALine: string): TBenchResult;

  {**
   * 解析多行 Rust criterion 输出
   *}
  function ParseRustBenchOutput(const AOutput: string): TBenchResultArray;

  {**
   * 解析 FPC RTL bench 输出
   * 格式: "Name=Foo  Iterations=1000  NsPerOp=1234.56"
   *}
  function ParseFPCBenchLine(const ALine: string): TBenchResult;

  {**
   * 解析多行 FPC RTL bench 输出
   *}
  function ParseFPCBenchOutput(const AOutput: string): TBenchResultArray;

  {**
   * 自动检测并解析基准输出
   *}
  function ParseBenchOutput(const AOutput: string; AParser: TXLangParser): TBenchResultArray;

  {** 获取上次解析时跳过的行数 }
  function GetLastParseSkippedCount: Integer;

implementation

uses
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.text.strings;

var
  GLastParseSkippedCount: Integer = 0;

function GetLastParseSkippedCount: Integer;
begin
  Result := GLastParseSkippedCount;
end;

{ Helper: Split by line endings (#10 and #13) }

function SplitLines(const AText: string): TStringArray;
var
  LNormalized: string;
begin
  LNormalized := StringReplace(AText, #13#10, #10, True);
  LNormalized := StringReplace(LNormalized, #13, #10, True);
  Result := StringsSplit(LNormalized, #10);
end;

{ Helper: Trim and check empty }

function IsEmptyOrComment(const ALine: string): Boolean;
begin
  Result := (Trim(ALine) = '') or (Trim(ALine)[1] = '#');
end;

{ Helper: Parse "key=value" pairs }

function ExtractValue(const ALine, AKey: string): string;
var
  LPos: Integer;
  LKeyEq: string;
  LStart: Integer;
  LEnd: Integer;
begin
  LKeyEq := AKey + '=';
  LPos := Pos(LKeyEq, ALine);
  if LPos > 0 then
  begin
    LStart := LPos + Length(LKeyEq);
    // Find next space or end of string
    LEnd := LStart;
    while (LEnd <= Length(ALine)) and (ALine[LEnd] <> ' ') do
      Inc(LEnd);
    Result := Copy(ALine, LStart, LEnd - LStart);
  end
  else
    Result := '';
end;

{ Helper: Parse Go number with unit suffix (e.g., "1234 ns/op", "456 B/op") }

function ParseGoTime(const AStr: string): Double;
var
  LParts: TStringArray;
  LValue: Double;
  LUnit: string;
begin
  Result := 0;
  LParts := StringsSplit(AStr, ' ', True);
  if Length(LParts) < 2 then Exit;

  LValue := StrToFloatDef(LParts[0], 0);
  LUnit := LParts[1];

  if LUnit = 'ns/op' then
    Result := LValue
  else if LUnit = 'us/op' then
    Result := LValue * 1000
  else if LUnit = 'ms/op' then
    Result := LValue * 1000000
  else if LUnit = 's/op' then
    Result := LValue * 1000000000;
end;

{ ParseGoBenchLine }

function ParseGoBenchLine(const ALine: string): TBenchResult;
var
  LParts: TStringArray;
  I: Integer;
  LName: string;
  LIterations: Int64;
  LNsPerOp: Double;
  LBytesPerOp: Int64;
  LAllocsPerOp: Int64;
  LTimeStr: string;
begin
  Result := Default(TBenchResult);
  LParts := StringsSplit(ALine, ' ', True);
  if Length(LParts) < 3 then
    raise EParseError.CreateFmt('Invalid Go bench line: %s', [ALine]);

  LName := LParts[0];
  // Remove "-N" suffix (GOMAXPROCS)
  if Pos('-', LName) > 0 then
    LName := Copy(LName, 1, Pos('-', LName) - 1);

  LIterations := StrToInt64Def(LParts[1], 0);

  // Go format: "1234 ns/op" or "1.234 us/op"
  // Parts are split: ["1234", "ns/op"] or ["1.234", "us/op"]
  if Length(LParts) >= 4 then
    LTimeStr := LParts[2] + ' ' + LParts[3]
  else
    LTimeStr := LParts[2];
  LNsPerOp := ParseGoTime(LTimeStr);

  LBytesPerOp := 0;
  LAllocsPerOp := 0;

  // Parse optional fields
  // Format: "456 B/op" or "7 allocs/op" are split into two parts
  for I := 0 to High(LParts) do
  begin
    if (LParts[I] = 'B/op') and (I > 0) then
      LBytesPerOp := StrToInt64Def(LParts[I - 1], 0)
    else if (LParts[I] = 'allocs/op') and (I > 0) then
      LAllocsPerOp := StrToInt64Def(LParts[I - 1], 0);
  end;

  Result.Name := LName;
  Result.Iterations := LIterations;
  Result.TotalNs := Round(LNsPerOp * LIterations);
  Result.NsPerOp := LNsPerOp;
  if LNsPerOp > 0 then
    Result.OpsPerSec := 1000000000 / LNsPerOp
  else
    Result.OpsPerSec := 0;
  Result.BytesPerOp := LBytesPerOp;
  Result.AllocsPerOp := LAllocsPerOp;
  Result.StdDev := 0;
  Result.Median := LNsPerOp;
  Result.P95 := LNsPerOp;
  Result.P99 := LNsPerOp;
  Result.Outliers := 0;
  Result.SampleCount := 1;
end;

{ ParseGoBenchOutput }

function ParseGoBenchOutput(const AOutput: string): TBenchResultArray;
var
  LLines: TStringArray;
  LLine: string;
  LList: array of TBenchResult;
begin
  GLastParseSkippedCount := 0;
  LList := nil;
  LLines := SplitLines(AOutput);
  for LLine in LLines do
  begin
    if IsEmptyOrComment(LLine) then Continue;
    if Pos('Benchmark', LLine) <> 1 then Continue;

    try
      SetLength(LList, Length(LList) + 1);
      LList[High(LList)] := ParseGoBenchLine(LLine);
    except
      Inc(GLastParseSkippedCount);
    end;
  end;
  Result := LList;
end;

{ ParseRustBenchLine }

function ParseRustBenchLine(const ALine: string): TBenchResult;
var
  LLine: string;
  LName: string;
  LTimeStr: string;
  LParts: TStringArray;
  LLower: Double;
  LMean: Double;
  LUpper: Double;
  LUnit: string;
  LMultiplier: Double;
begin
  Result := Default(TBenchResult);

  // Rust criterion format: "name    time:   [lower mean upper unit]"
  // Example: "BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]"
  LLine := Trim(ALine);
  if Pos('time:', LLine) = 0 then
    raise EParseError.CreateFmt('Invalid Rust bench line: %s', [ALine]);

  // Extract name
  LName := Trim(Copy(LLine, 1, Pos('time:', LLine) - 1));

  // Extract time range
  LTimeStr := Copy(LLine, Pos('[', LLine) + 1, Pos(']', LLine) - Pos('[', LLine) - 1);
  LParts := StringsSplit(LTimeStr, ' ', True);

  if Length(LParts) >= 6 then
  begin
    // 6-token format: ["1.234", "us", "1.256", "us", "1.279", "us"]
    LLower := StrToFloatDef(LParts[0], 0);
    LUnit := LParts[1];
    LMean := StrToFloatDef(LParts[2], 0);
    LUpper := StrToFloatDef(LParts[4], 0);
  end
  else if Length(LParts) >= 4 then
  begin
    // 4-token format: ["1.234", "1.256", "1.279", "us"]
    LLower := StrToFloatDef(LParts[0], 0);
    LMean := StrToFloatDef(LParts[1], 0);
    LUpper := StrToFloatDef(LParts[2], 0);
    LUnit := LParts[3];
  end
  else
    raise EParseError.CreateFmt('Invalid Rust bench time range: %s', [LTimeStr]);

  // Convert to nanoseconds
  LMultiplier := 1;
  if LUnit = 'ps' then LMultiplier := 0.001
  else if LUnit = 'ns' then LMultiplier := 1
  else if LUnit = 'us' then LMultiplier := 1000
  else if LUnit = 'ms' then LMultiplier := 1000000
  else if LUnit = 's' then LMultiplier := 1000000000;

  Result.Name := LName;
  Result.NsPerOp := LMean * LMultiplier;
  Result.Median := Result.NsPerOp;
  Result.StdDev := 0;
  Result.P95 := LUpper * LMultiplier;
  Result.P99 := Result.P95;
  Result.Outliers := 0;
  Result.SampleCount := 1;
  if Result.NsPerOp > 0 then
    Result.OpsPerSec := 1000000000 / Result.NsPerOp
  else
    Result.OpsPerSec := 0;
end;

{ ParseRustBenchOutput }

function ParseRustBenchOutput(const AOutput: string): TBenchResultArray;
var
  LLines: TStringArray;
  LLine: string;
  LList: array of TBenchResult;
begin
  GLastParseSkippedCount := 0;
  LList := nil;
  LLines := SplitLines(AOutput);
  for LLine in LLines do
  begin
    if IsEmptyOrComment(LLine) then Continue;
    if Pos('time:', LLine) = 0 then Continue;

    try
      SetLength(LList, Length(LList) + 1);
      LList[High(LList)] := ParseRustBenchLine(LLine);
    except
      Inc(GLastParseSkippedCount);
    end;
  end;
  Result := LList;
end;

{ ParseFPCBenchLine }

function ParseFPCBenchLine(const ALine: string): TBenchResult;
var
  LName: string;
  LNsPerOpStr: string;
  LNsPerOp: Double;
  LIterationsStr: string;
  LIterations: Int64;
begin
  Result := Default(TBenchResult);

  if Pos('NsPerOp', ALine) = 0 then
    raise EParseError.CreateFmt('Invalid FPC bench line: %s', [ALine]);

  LName := Trim(ExtractValue(ALine, 'Name'));
  if LName = '' then
    raise EParseError.CreateFmt('Missing Name in FPC bench line: %s', [ALine]);

  LNsPerOpStr := Trim(ExtractValue(ALine, 'NsPerOp'));
  LNsPerOp := StrToFloatDef(LNsPerOpStr, 0);

  LIterationsStr := Trim(ExtractValue(ALine, 'Iterations'));
  LIterations := StrToInt64Def(LIterationsStr, 1);

  Result.Name := LName;
  Result.NsPerOp := LNsPerOp;
  Result.Median := LNsPerOp;
  Result.StdDev := 0;
  Result.P95 := LNsPerOp;
  Result.P99 := LNsPerOp;
  Result.Outliers := 0;
  Result.SampleCount := 1;
  Result.Iterations := LIterations;
  Result.TotalNs := Round(LNsPerOp * LIterations);
  if LNsPerOp > 0 then
    Result.OpsPerSec := 1000000000 / LNsPerOp
  else
    Result.OpsPerSec := 0;
end;

{ ParseFPCBenchOutput }

function ParseFPCBenchOutput(const AOutput: string): TBenchResultArray;
var
  LLines: TStringArray;
  LLine: string;
  LList: array of TBenchResult;
begin
  GLastParseSkippedCount := 0;
  LList := nil;
  LLines := SplitLines(AOutput);
  for LLine in LLines do
  begin
    if IsEmptyOrComment(LLine) then Continue;
    if Pos('NsPerOp', LLine) = 0 then Continue;

    try
      SetLength(LList, Length(LList) + 1);
      LList[High(LList)] := ParseFPCBenchLine(LLine);
    except
      Inc(GLastParseSkippedCount);
    end;
  end;
  Result := LList;
end;

{ ParseBenchOutput }

function ParseBenchOutput(const AOutput: string; AParser: TXLangParser): TBenchResultArray;
begin
  case AParser of
    xlGo:   Result := ParseGoBenchOutput(AOutput);
    xlRust: Result := ParseRustBenchOutput(AOutput);
    xlFPC:  Result := ParseFPCBenchOutput(AOutput);
  else
    raise EParseError.Create('Unknown parser type');
  end;
end;

end.
