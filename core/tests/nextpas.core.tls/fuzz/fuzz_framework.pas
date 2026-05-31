unit fuzz_framework;

{$mode objfpc}{$H+}

{**
 * Fuzz Testing Framework for fafafa.ssl
 *
 * Provides infrastructure for fuzzing security-critical functions:
 * - Random input generation with various strategies
 * - Mutation-based fuzzing
 * - Crash detection and logging
 * - Statistics tracking
 *
 * Usage:
 *   Fuzzer := TFuzzer.Create;
 *   Fuzzer.RegisterTarget('pem_decode', @FuzzPEMDecode);
 *   Fuzzer.Run(10000);  // 10000 iterations
 *}

interface

uses
  SysUtils, Classes, DateUtils, Math;

type
  { Fuzz target procedure type }
  TFuzzTarget = procedure(const AInput: TBytes);

  { Fuzz input generation strategy }
  TFuzzStrategy = (
    fsRandom,           // Pure random bytes
    fsMutate,           // Mutate valid inputs
    fsBoundary,         // Boundary values (0, 1, max, etc.)
    fsFormatted         // Format-aware (PEM, ASN1, etc.)
  );

  { Fuzz result for a single run }
  TFuzzResult = record
    Success: Boolean;
    ExceptionClass: string;
    ExceptionMessage: string;
    InputSize: Integer;
    ExecutionTimeMs: Double;
  end;

  { Statistics for a fuzz target }
  TFuzzStats = record
    TargetName: string;
    TotalRuns: Integer;
    Successes: Integer;
    Failures: Integer;
    UniqueExceptions: Integer;
    TotalTimeMs: Double;
    MinInputSize: Integer;
    MaxInputSize: Integer;
    CrashInputs: TStringList;  // Hex-encoded crash inputs
  end;

  { Main fuzzer class }
  TFuzzer = class
  private
    FTargets: TStringList;
    FStats: array of TFuzzStats;
    FLogFile: TextFile;
    FLogFileName: string;
    FVerbose: Boolean;
    FSeed: Cardinal;
    FMaxInputSize: Integer;
    FMinInputSize: Integer;

    function GetTargetIndex(const AName: string): Integer;
    procedure LogMessage(const AMsg: string);
    procedure LogCrash(const ATargetName: string; const AInput: TBytes;
      const AException: string);
  public
    constructor Create;
    destructor Destroy; override;

    { Target registration }
    procedure RegisterTarget(const AName: string; ATarget: TFuzzTarget);

    { Input generation }
    function GenerateRandomInput(ASize: Integer): TBytes;
    function GenerateBoundaryInput: TBytes;
    function MutateInput(const AInput: TBytes): TBytes;
    function GeneratePEMLikeInput: TBytes;
    function GenerateASN1LikeInput: TBytes;

    { Execution }
    function RunOnce(const ATargetName: string; const AInput: TBytes): TFuzzResult;
    procedure Run(AIterations: Integer = 10000);
    procedure RunTarget(const ATargetName: string; AIterations: Integer = 10000);
    procedure RunWithCorpus(const ATargetName: string; const ACorpusPath: string);

    { Results }
    function GetStats(const ATargetName: string): TFuzzStats;
    procedure PrintStats;
    procedure SaveStatsToFile(const AFileName: string);

    { Configuration }
    property Verbose: Boolean read FVerbose write FVerbose;
    property Seed: Cardinal read FSeed write FSeed;
    property MaxInputSize: Integer read FMaxInputSize write FMaxInputSize;
    property MinInputSize: Integer read FMinInputSize write FMinInputSize;
  end;

{ Global fuzzer instance }
function GetFuzzer: TFuzzer;

{ Utility functions }
function BytesToHex(const ABytes: TBytes): string;
function HexToBytes(const AHex: string): TBytes;

implementation

var
  GFuzzer: TFuzzer = nil;

function GetFuzzer: TFuzzer;
begin
  if GFuzzer = nil then
    GFuzzer := TFuzzer.Create;
  Result := GFuzzer;
end;

function BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ABytes) do
    Result := Result + IntToHex(ABytes[I], 2);
end;

function HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

{ TFuzzer }

constructor TFuzzer.Create;
begin
  inherited Create;
  FTargets := TStringList.Create;
  FTargets.Sorted := True;
  FTargets.Duplicates := dupError;
  FVerbose := False;
  FSeed := Cardinal(GetTickCount64);
  RandSeed := FSeed;
  FMaxInputSize := 4096;
  FMinInputSize := 0;
  FLogFileName := 'fuzz_' + FormatDateTime('yyyymmdd_hhnnss', Now) + '.log';
end;

destructor TFuzzer.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FStats) do
    if FStats[I].CrashInputs <> nil then
      FStats[I].CrashInputs.Free;
  FTargets.Free;
  inherited Destroy;
end;

function TFuzzer.GetTargetIndex(const AName: string): Integer;
begin
  Result := FTargets.IndexOf(AName);
end;

procedure TFuzzer.LogMessage(const AMsg: string);
begin
  if FVerbose then
    WriteLn(AMsg);
end;

procedure TFuzzer.LogCrash(const ATargetName: string; const AInput: TBytes;
  const AException: string);
var
  CrashFile: TextFile;
  CrashFileName: string;
begin
  CrashFileName := Format('crash_%s_%s.txt', [ATargetName,
    FormatDateTime('yyyymmdd_hhnnss', Now)]);

  AssignFile(CrashFile, CrashFileName);
  try
    Rewrite(CrashFile);
    WriteLn(CrashFile, 'Target: ', ATargetName);
    WriteLn(CrashFile, 'Exception: ', AException);
    WriteLn(CrashFile, 'Input size: ', Length(AInput));
    WriteLn(CrashFile, 'Input (hex): ', BytesToHex(AInput));
    WriteLn(CrashFile, '');
    WriteLn(CrashFile, 'Timestamp: ', DateTimeToStr(Now));
  finally
    CloseFile(CrashFile);
  end;

  WriteLn('[CRASH] ', ATargetName, ': ', AException);
  WriteLn('  Saved to: ', CrashFileName);
end;

procedure TFuzzer.RegisterTarget(const AName: string; ATarget: TFuzzTarget);
var
  Idx: Integer;
begin
  Idx := Length(FStats);
  SetLength(FStats, Idx + 1);
  FStats[Idx].TargetName := AName;
  FStats[Idx].TotalRuns := 0;
  FStats[Idx].Successes := 0;
  FStats[Idx].Failures := 0;
  FStats[Idx].UniqueExceptions := 0;
  FStats[Idx].TotalTimeMs := 0;
  FStats[Idx].MinInputSize := MaxInt;
  FStats[Idx].MaxInputSize := 0;
  FStats[Idx].CrashInputs := TStringList.Create;

  FTargets.AddObject(AName, TObject(ATarget));
end;

function TFuzzer.GenerateRandomInput(ASize: Integer): TBytes;
var
  I: Integer;
begin
  if ASize < 0 then
    ASize := FMinInputSize + Random(FMaxInputSize - FMinInputSize + 1);
  SetLength(Result, ASize);
  for I := 0 to ASize - 1 do
    Result[I] := Random(256);
end;

function TFuzzer.GenerateBoundaryInput: TBytes;
var
  Strategy: Integer;
begin
  Strategy := Random(6);
  case Strategy of
    0: SetLength(Result, 0);  // Empty
    1: begin  // Single byte
         SetLength(Result, 1);
         Result[0] := Random(256);
       end;
    2: begin  // All zeros
         SetLength(Result, Random(100) + 1);
         FillChar(Result[0], Length(Result), 0);
       end;
    3: begin  // All 0xFF
         SetLength(Result, Random(100) + 1);
         FillChar(Result[0], Length(Result), $FF);
       end;
    4: begin  // Maximum size
         Result := GenerateRandomInput(FMaxInputSize);
       end;
    5: begin  // Near power of 2
         Result := GenerateRandomInput((1 shl Random(12)) + Random(3) - 1);
       end;
  end;
end;

function TFuzzer.MutateInput(const AInput: TBytes): TBytes;
var
  MutationType, Pos, Len, I: Integer;
begin
  Result := Copy(AInput);
  if Length(Result) = 0 then
  begin
    Result := GenerateRandomInput(Random(100) + 1);
    Exit;
  end;

  MutationType := Random(7);
  case MutationType of
    0: begin  // Flip random bit
         Pos := Random(Length(Result));
         Result[Pos] := Result[Pos] xor (1 shl Random(8));
       end;
    1: begin  // Replace random byte
         Pos := Random(Length(Result));
         Result[Pos] := Random(256);
       end;
    2: begin  // Insert random bytes
         Pos := Random(Length(Result) + 1);
         Len := Random(10) + 1;
         SetLength(Result, Length(Result) + Len);
         Move(Result[Pos], Result[Pos + Len], Length(Result) - Pos - Len);
         for I := 0 to Len - 1 do
           Result[Pos + I] := Random(256);
       end;
    3: begin  // Delete random bytes
         if Length(Result) > 1 then
         begin
           Pos := Random(Length(Result));
           Len := Random(Min(10, Length(Result) - Pos)) + 1;
           Move(Result[Pos + Len], Result[Pos], Length(Result) - Pos - Len);
           SetLength(Result, Length(Result) - Len);
         end;
       end;
    4: begin  // Duplicate chunk
         if Length(Result) > 1 then
         begin
           Pos := Random(Length(Result));
           Len := Random(Min(20, Length(Result) - Pos)) + 1;
           SetLength(Result, Length(Result) + Len);
           Move(Result[Pos], Result[Length(Result) - Len], Len);
         end;
       end;
    5: begin  // Replace with special values
         Pos := Random(Length(Result));
         case Random(4) of
           0: Result[Pos] := 0;
           1: Result[Pos] := $FF;
           2: Result[Pos] := $7F;
           3: Result[Pos] := $80;
         end;
       end;
    6: begin  // Swap bytes
         if Length(Result) > 1 then
         begin
           Pos := Random(Length(Result) - 1);
           Result[Pos] := Result[Pos] xor Result[Pos + 1];
           Result[Pos + 1] := Result[Pos] xor Result[Pos + 1];
           Result[Pos] := Result[Pos] xor Result[Pos + 1];
         end;
       end;
  end;
end;

function TFuzzer.GeneratePEMLikeInput: TBytes;
var
  S: string;
  Content: string;
  I, Len: Integer;
begin
  // Generate PEM-like structure with random content
  Len := Random(100) + 10;
  SetLength(Content, Len);
  for I := 1 to Len do
    Content[I] := Chr(Random(64) + 32);  // Printable ASCII

  case Random(4) of
    0: S := '-----BEGIN CERTIFICATE-----'#10 + Content + #10'-----END CERTIFICATE-----';
    1: S := '-----BEGIN RSA PRIVATE KEY-----'#10 + Content + #10'-----END RSA PRIVATE KEY-----';
    2: S := '-----BEGIN PUBLIC KEY-----'#10 + Content + #10'-----END PUBLIC KEY-----';
    3: S := Content;  // No headers
  end;

  SetLength(Result, Length(S));
  if Length(S) > 0 then
    Move(S[1], Result[0], Length(S));
end;

function TFuzzer.GenerateASN1LikeInput: TBytes;
var
  Tag, Len: Integer;
begin
  // Generate ASN.1-like structure
  Tag := Random(31);  // Universal tags
  Len := Random(200);

  if Len < 128 then
  begin
    SetLength(Result, 2 + Len);
    Result[0] := Tag;
    Result[1] := Len;
  end
  else
  begin
    SetLength(Result, 4 + Len);
    Result[0] := Tag;
    Result[1] := $82;  // 2-byte length
    Result[2] := (Len shr 8) and $FF;
    Result[3] := Len and $FF;
  end;

  // Fill with random content
  if Len > 0 then
  begin
    if Length(Result) > 4 then
      FillChar(Result[4], Len, Random(256))
    else
      FillChar(Result[2], Len, Random(256));
  end;
end;

function TFuzzer.RunOnce(const ATargetName: string; const AInput: TBytes): TFuzzResult;
var
  Idx: Integer;
  Target: TFuzzTarget;
  StartTime: TDateTime;
begin
  Result.Success := False;
  Result.ExceptionClass := '';
  Result.ExceptionMessage := '';
  Result.InputSize := Length(AInput);
  Result.ExecutionTimeMs := 0;

  Idx := GetTargetIndex(ATargetName);
  if Idx < 0 then
  begin
    Result.ExceptionMessage := 'Target not found: ' + ATargetName;
    Exit;
  end;

  Target := TFuzzTarget(FTargets.Objects[Idx]);
  StartTime := Now;

  try
    Target(AInput);
    Result.Success := True;
  except
    on E: Exception do
    begin
      Result.ExceptionClass := E.ClassName;
      Result.ExceptionMessage := E.Message;
    end;
  end;

  Result.ExecutionTimeMs := MilliSecondsBetween(Now, StartTime);
end;

procedure TFuzzer.RunTarget(const ATargetName: string; AIterations: Integer);
var
  Idx, I: Integer;
  Input: TBytes;
  Res: TFuzzResult;
begin
  Idx := GetTargetIndex(ATargetName);
  if Idx < 0 then
  begin
    WriteLn('Error: Target not found: ', ATargetName);
    Exit;
  end;

  WriteLn('Fuzzing: ', ATargetName, ' (', AIterations, ' iterations)');

  for I := 1 to AIterations do
  begin
    // Simple random input generation
    Input := GenerateRandomInput(-1);

    Res := RunOnce(ATargetName, Input);

    // Update stats
    Inc(FStats[Idx].TotalRuns);
    FStats[Idx].TotalTimeMs := FStats[Idx].TotalTimeMs + Res.ExecutionTimeMs;

    if Res.InputSize < FStats[Idx].MinInputSize then
      FStats[Idx].MinInputSize := Res.InputSize;
    if Res.InputSize > FStats[Idx].MaxInputSize then
      FStats[Idx].MaxInputSize := Res.InputSize;

    if Res.Success then
      Inc(FStats[Idx].Successes)
    else
      Inc(FStats[Idx].Failures);

    // Progress indicator
    if (I mod 500 = 0) or (I = AIterations) then
      Write(#13, '  Progress: ', I, '/', AIterations, ' (',
        FStats[Idx].Failures, ' failures)    ');
  end;

  WriteLn;
end;

procedure TFuzzer.Run(AIterations: Integer);
var
  I: Integer;
begin
  WriteLn('=== Fuzz Testing Started ===');
  WriteLn('Seed: ', FSeed);
  WriteLn('Targets: ', FTargets.Count);
  WriteLn;

  for I := 0 to FTargets.Count - 1 do
    RunTarget(FTargets[I], AIterations);

  WriteLn;
  PrintStats;
end;

procedure TFuzzer.RunWithCorpus(const ATargetName: string; const ACorpusPath: string);
var
  SR: TSearchRec;
  FS: TFileStream;
  Input: TBytes;
  Res: TFuzzResult;
  FileCount: Integer;
begin
  FileCount := 0;
  WriteLn('Fuzzing with corpus: ', ACorpusPath);

  if FindFirst(ACorpusPath + '/*', faAnyFile, SR) = 0 then
  try
    repeat
      if (SR.Attr and faDirectory) = 0 then
      begin
        try
          FS := TFileStream.Create(ACorpusPath + '/' + SR.Name, fmOpenRead);
          try
            SetLength(Input, FS.Size);
            if FS.Size > 0 then
              FS.Read(Input[0], FS.Size);
          finally
            FS.Free;
          end;

          Res := RunOnce(ATargetName, Input);
          Inc(FileCount);

          if not Res.Success then
            WriteLn('  [FAIL] ', SR.Name, ': ', Res.ExceptionClass);
        except
          on E: Exception do
            WriteLn('  [ERROR] ', SR.Name, ': ', E.Message);
        end;
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;

  WriteLn('Processed ', FileCount, ' corpus files');
end;

function TFuzzer.GetStats(const ATargetName: string): TFuzzStats;
var
  Idx: Integer;
begin
  Idx := GetTargetIndex(ATargetName);
  if Idx >= 0 then
    Result := FStats[Idx]
  else
    FillChar(Result, SizeOf(Result), 0);
end;

procedure TFuzzer.PrintStats;
var
  I: Integer;
  AvgTime: Double;
begin
  WriteLn('=== Fuzz Testing Results ===');
  WriteLn;

  for I := 0 to High(FStats) do
  begin
    WriteLn('Target: ', FStats[I].TargetName);
    WriteLn('  Total runs:        ', FStats[I].TotalRuns);
    WriteLn('  Successes:         ', FStats[I].Successes);
    WriteLn('  Failures:          ', FStats[I].Failures);

    if FStats[I].TotalRuns > 0 then
    begin
      AvgTime := FStats[I].TotalTimeMs / FStats[I].TotalRuns;
      WriteLn('  Avg time:          ', AvgTime:0:3, ' ms');
    end;

    WriteLn('  Input size range:  ', FStats[I].MinInputSize, ' - ', FStats[I].MaxInputSize);
    WriteLn;
  end;
end;

procedure TFuzzer.SaveStatsToFile(const AFileName: string);
var
  F: TextFile;
  I: Integer;
begin
  AssignFile(F, AFileName);
  Rewrite(F);
  try
    WriteLn(F, 'Fuzz Testing Report');
    WriteLn(F, 'Generated: ', DateTimeToStr(Now));
    WriteLn(F, 'Seed: ', FSeed);
    WriteLn(F, '');

    for I := 0 to High(FStats) do
    begin
      WriteLn(F, '## ', FStats[I].TargetName);
      WriteLn(F, 'Runs: ', FStats[I].TotalRuns);
      WriteLn(F, 'Pass: ', FStats[I].Successes);
      WriteLn(F, 'Fail: ', FStats[I].Failures);
      WriteLn(F, 'Unique: ', FStats[I].UniqueExceptions);
      WriteLn(F, '');
    end;
  finally
    CloseFile(F);
  end;
end;

end.
