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

  {** 单行解析函数类型 }
  TXLangLineParser = function(const ALine: string): TBenchResult;

  {** 行匹配函数类型 }
  TXLangLineMatcher = function(const ALine: string): Boolean;

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

  {** 通用行解析函数
   *  @param AOutput 原始输出文本
   *  @param ALineParser 单行解析函数
   *  @param ALineMatcher 行匹配函数（返回 True 表示该行需要解析）
   *  @return 解析结果数组 }
  function ParseLines(const AOutput: string;
    ALineParser: TXLangLineParser;
    ALineMatcher: TXLangLineMatcher): TBenchResultArray;

implementation

uses
  nextpas.core.text.base,
  nextpas.core.text.conv,
  nextpas.core.text.strings,
  nextpas.core.math.scalar;

threadvar
  GLastParseSkippedCount: Integer;

function GetLastParseSkippedCount: Integer;
begin
  Result := GLastParseSkippedCount;
end;

{ Helper: Split by line endings (#10 and #13) }

function SplitLines(const AText: string): TStringArray;
var
  LNormalized: string;
  LLen, I, LOut: Integer;
  LHasCR: Boolean;
begin
  LLen := Length(AText);
  if LLen = 0 then
  begin
    Result := nil;
    Exit;
  end;

  { Fast path: check if any CR exists; if not, split directly }
  LHasCR := False;
  for I := 1 to LLen do
    if AText[I] = #13 then
    begin
      LHasCR := True;
      Break;
    end;
  if not LHasCR then
  begin
    Result := StringsSplit(AText, #10);
    Exit;
  end;

  // CR/LF normalization pass
  SetLength(LNormalized, LLen);
  LOut := 0;
  I := 1;
  while I <= LLen do
  begin
    Inc(LOut);
    if (AText[I] = #13) and (I < LLen) and (AText[I + 1] = #10) then
    begin
      LNormalized[LOut] := #10;
      Inc(I, 2);
    end
    else if AText[I] = #13 then
    begin
      LNormalized[LOut] := #10;
      Inc(I);
    end
    else
    begin
      LNormalized[LOut] := AText[I];
      Inc(I);
    end;
  end;
  SetLength(LNormalized, LOut);
  Result := StringsSplit(LNormalized, #10);
end;

{ Helper: Trim and check empty — avoid allocation for common case }

function IsEmptyOrComment(const ALine: string): Boolean;
var
  LLen, LStart: Integer;
begin
  LLen := Length(ALine);
  { Skip leading whitespace }
  LStart := 1;
  while (LStart <= LLen) and (ALine[LStart] in [' ', #9, #10, #13]) do
    Inc(LStart);
  if LStart > LLen then
    Exit(True);  { empty or all-whitespace }
  Result := ALine[LStart] = '#';
end;

function ParseLines(const AOutput: string;
  ALineParser: TXLangLineParser;
  ALineMatcher: TXLangLineMatcher): TBenchResultArray;
var
  LLines: TStringArray;
  LLine: string;
  LList: array of TBenchResult;
  LCount: Integer;
  LCapacity: Integer;
begin
  GLastParseSkippedCount := 0;
  LList := nil;
  LCount := 0;
  LCapacity := 0;
  LLines := SplitLines(AOutput);
  for LLine in LLines do
  begin
    if IsEmptyOrComment(LLine) then Continue;
    if not ALineMatcher(LLine) then Continue;

    try
      if LCount >= LCapacity then
      begin
        if LCapacity = 0 then LCapacity := 8
        else LCapacity := LCapacity * 2;
        SetLength(LList, LCapacity);
      end;
      LList[LCount] := ALineParser(LLine);
      Inc(LCount);
    except
      Inc(GLastParseSkippedCount);
    end;
  end;
  SetLength(LList, LCount);
  Result := LList;
end;

{ Helper: Safely compute TotalNs = NsPerOp * Iterations
  Raises EParseError on overflow or non-finite input (CR-17). }

function SafeDeriveTotalNs(ANsPerOp: Double; AIterations: Int64): UInt64;
var
  LProduct: Double;
begin
  if (ANsPerOp <= 0) or (AIterations <= 0) then
    Exit(0);
  if IsNan(ANsPerOp) or IsInfinite(ANsPerOp) then
    raise EParseError.Create('Non-finite NsPerOp');

  LProduct := ANsPerOp * Double(AIterations);

  { Double can represent integers up to 2^53 exactly.
    Round() in FPC raises EInvalidOp when the value exceeds High(Int64).
    Guard with a safe upper bound. }
  if IsNan(LProduct) or IsInfinite(LProduct) or (LProduct > 9.2e18) then
    raise EParseError.CreateFmt(
      'TotalNs overflow: NsPerOp=%.1f * Iterations=%d exceeds representable range',
      [ANsPerOp, AIterations]);

  Result := UInt64(Round(LProduct));
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
  LPos := 1;
  while LPos <= Length(ALine) do
  begin
    LPos := Pos(LKeyEq, ALine, LPos);
    if LPos = 0 then
      Break;
    { Anchored: preceding char must be space or line start }
    if (LPos = 1) or (ALine[LPos - 1] = ' ') then
    begin
      LStart := LPos + Length(LKeyEq);
      LEnd := LStart;
      while (LEnd <= Length(ALine)) and (ALine[LEnd] <> ' ') do
        Inc(LEnd);
      Exit(Copy(ALine, LStart, LEnd - LStart));
    end;
    Inc(LPos);
  end;
  Result := '';
end;

{ Helper: Parse Go number with unit suffix (e.g., "1234 ns/op", "456 B/op") }

function ParseGoTime(const AStr: string): Double;
var
  LParts: TStringArray;
  LValue: Double;
  LUnit: string;
  LCombinedValue: string;
  LCombinedUnit: string;
  LI: Integer;
begin
  Result := 0;
  LParts := StringsSplit(AStr, ' ', True);
  if Length(LParts) < 2 then
  begin
    { GL-01: Handle Go's glued format "1.50µs/op" (no space between value and unit).
      Go's testing package outputs µs/op as a single token when time > 1µs.
      Scan backwards to find where digits/dot/±/e end and the unit begins. }
    if Length(LParts) = 1 then
    begin
      LI := Length(LParts[0]);
      while (LI >= 1) and not (LParts[0][LI] in ['0'..'9', '.', '+', '-', 'e', 'E']) do
        Dec(LI);
      if LI >= 1 then
      begin
        LCombinedValue := Copy(LParts[0], 1, LI);
        LCombinedUnit := Copy(LParts[0], LI + 1, MaxInt);
        LValue := StrToFloatDef(LCombinedValue, 0);
        if LCombinedUnit = 'ns/op' then
          Result := LValue
        else if (LCombinedUnit = 'us/op') or (LCombinedUnit = 'µs/op') then
          Result := LValue * 1000
        else if LCombinedUnit = 'ms/op' then
          Result := LValue * 1000000
        else if LCombinedUnit = 's/op' then
          Result := LValue * NANOSECONDS_PER_SECOND;
      end;
    end;
    Exit;
  end;

  LValue := StrToFloatDef(LParts[0], 0);
  LUnit := LParts[1];

  if LUnit = 'ns/op' then
    Result := LValue
  else if (LUnit = 'us/op') or (LUnit = 'µs/op') then
    Result := LValue * 1000
  else if LUnit = 'ms/op' then
    Result := LValue * 1000000
  else if LUnit = 's/op' then
    Result := LValue * NANOSECONDS_PER_SECOND;
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
  { Remove "-N" GOMAXPROCS suffix by scanning from end for pattern -\d+$ }
  I := Length(LName);
  { Skip trailing digits }
  while (I > 1) and (LName[I] in ['0'..'9']) do
    Dec(I);
  { Check if we stopped at a dash and there were digits after it }
  if (I >= 1) and (I < Length(LName)) and (LName[I] = '-') then
    LName := Copy(LName, 1, I - 1);

  LIterations := StrToInt64Def(LParts[1], 0);
  if LIterations < 0 then
    LIterations := 0; { guard against negative iterations }

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
  Result.Executed := True;
  Result.Iterations := LIterations;
  Result.TotalNs := SafeDeriveTotalNs(LNsPerOp, LIterations);
  Result.NsPerOp := LNsPerOp;
  if LNsPerOp > 0 then
    Result.OpsPerSec := NANOSECONDS_PER_SECOND / LNsPerOp
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

{ 行匹配器 }

function GoLineMatcher(const ALine: string): Boolean;
begin
  Result := Pos('Benchmark', ALine) = 1;
end;

function RustLineMatcher(const ALine: string): Boolean;
begin
  Result := Pos('time:', ALine) > 0;
end;

function FPCLineMatcher(const ALine: string): Boolean;
begin
  Result := Pos('NsPerOp', ALine) > 0;
end;

function ParseGoBenchOutput(const AOutput: string): TBenchResultArray;
begin
  Result := ParseLines(AOutput, @ParseGoBenchLine, @GoLineMatcher);
end;

{ ParseRustBenchLine }

function ParseRustBenchLine(const ALine: string): TBenchResult;
var
  LLine: string;
  LName: string;
  LTimeStr: string;
  LParts: TStringArray;
  LMean: Double;
  LUpper: Double;
  LUnit: string;
  LMultiplier: Double;
begin
  Result := Default(TBenchResult);

  // Rust criterion format: "name    time:   [lower mean upper unit]"
  // Example: "BenchmarkFoo    time:   [1.234 us 1.256 us 1.279 us]"
  LLine := nextpas.core.text.conv.Trim(ALine);
  if Pos('time:', LLine) = 0 then
    raise EParseError.CreateFmt('Invalid Rust bench line: %s', [ALine]);

  // Extract name
  LName := nextpas.core.text.conv.Trim(Copy(LLine, 1, Pos('time:', LLine) - 1));

  // Extract time range
  LTimeStr := Copy(LLine, Pos('[', LLine) + 1, Pos(']', LLine) - Pos('[', LLine) - 1);
  LParts := StringsSplit(LTimeStr, ' ', True);

  if Length(LParts) >= 6 then
  begin
    // 6-token format: ["1.234", "us", "1.256", "us", "1.279", "us"]
    StrToFloatDef(LParts[0], 0); { lower bound parsed but not stored }
    LUnit := LParts[1];
    LMean := StrToFloatDef(LParts[2], 0);
    LUpper := StrToFloatDef(LParts[4], 0);
  end
  else if Length(LParts) >= 4 then
  begin
    // 4-token format: ["1.234", "1.256", "1.279", "us"]
    StrToFloatDef(LParts[0], 0); { lower bound parsed but not stored }
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
  else if LUnit = 's' then LMultiplier := NANOSECONDS_PER_SECOND
  else raise EParseError.CreateFmt('Unknown Rust bench time unit "%s": %s', [LUnit, ALine]);

  // Validate mean > 0 after unit conversion (TG-15)
  // A zero or negative mean indicates invalid/meaningless benchmark data.
  // Raising EParseError causes the output parser to count it as skipped.
  if LMean * LMultiplier <= 0 then
    raise EParseError.CreateFmt('Rust bench mean is zero or negative: %s', [ALine]);

  Result.Name := LName;
  Result.Executed := True;
  Result.NsPerOp := LMean * LMultiplier;
  Result.Median := Result.NsPerOp;
  Result.StdDev := 0;
  { Rust provides [lower, mean, upper] CI. Use upper as P95 approx.
    Go/FPC only provide mean, so P95 = mean there. This is a cross-format
    limitation: P95 semantics differ between parsers. }
  Result.P95 := LUpper * LMultiplier;
  Result.P99 := Result.P95;
  Result.Outliers := 0;
  Result.SampleCount := 1;
  if Result.NsPerOp > 0 then
    Result.OpsPerSec := NANOSECONDS_PER_SECOND / Result.NsPerOp
  else
    Result.OpsPerSec := 0;
end;

{ ParseRustBenchOutput }

function ParseRustBenchOutput(const AOutput: string): TBenchResultArray;
begin
  Result := ParseLines(AOutput, @ParseRustBenchLine, @RustLineMatcher);
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

  LName := nextpas.core.text.conv.Trim(ExtractValue(ALine, 'Name'));
  if LName = '' then
    raise EParseError.CreateFmt('Missing Name in FPC bench line: %s', [ALine]);

  LNsPerOpStr := nextpas.core.text.conv.Trim(ExtractValue(ALine, 'NsPerOp'));
  LNsPerOp := StrToFloatDef(LNsPerOpStr, 0);

  LIterationsStr := nextpas.core.text.conv.Trim(ExtractValue(ALine, 'Iterations'));
  LIterations := StrToInt64Def(LIterationsStr, 1);

  Result.Name := LName;
  Result.Executed := True;
  Result.NsPerOp := LNsPerOp;
  Result.Median := LNsPerOp;
  Result.StdDev := 0;
  Result.P95 := LNsPerOp;
  Result.P99 := LNsPerOp;
  Result.Outliers := 0;
  Result.SampleCount := 1;
  Result.Iterations := LIterations;
  Result.TotalNs := SafeDeriveTotalNs(LNsPerOp, LIterations);
  if LNsPerOp > 0 then
    Result.OpsPerSec := NANOSECONDS_PER_SECOND / LNsPerOp
  else
    Result.OpsPerSec := 0;
end;

{ ParseFPCBenchOutput }

function ParseFPCBenchOutput(const AOutput: string): TBenchResultArray;
begin
  Result := ParseLines(AOutput, @ParseFPCBenchLine, @FPCLineMatcher);
end;

{ ParseBenchOutput }

function ParseBenchOutput(const AOutput: string; AParser: TXLangParser): TBenchResultArray;
begin
  { 测试契约：非法强转的解析器类型必须抛 EParseError（见 test_bench_xlang），
    故用 if 链保留运行时防御，放弃 case 的穷尽性静态检查。 }
  if AParser = xlGo then
    Result := ParseGoBenchOutput(AOutput)
  else if AParser = xlRust then
    Result := ParseRustBenchOutput(AOutput)
  else if AParser = xlFPC then
    Result := ParseFPCBenchOutput(AOutput)
  else
    raise EParseError.Create('Unknown parser type');
end;

end.
