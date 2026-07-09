{ nextpas.core.test.helpers — shared test helpers
  =========================================================
  Reusable helpers for test programs.
  Import explicitly: uses nextpas.core.test.helpers;

  ExpectFail       — verify that a closure raises EAssertionFailed
  WithMock         — create+run+free a TMock in one call
  ExpectFailWithMock — mock lifecycle + assertion-failure check }
unit nextpas.core.test.helpers;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.system,
  nextpas.core.test.base,
  nextpas.core.test.check,
  nextpas.core.test.config,
  nextpas.core.test.mock;

type
  TMockProc = procedure(AMock: TMock);
  TTempDirProc = procedure(const ADir: string);

{ Verify closure raises EAssertionFailed.
  Optional AContains: substring check on the message. }
procedure ExpectFail(AProc: TTestClosure;
  const AContains: string = '');

{ Verify closure raises AExceptionClass (or subclass).
  Optional AContains: substring check on the message.
  Example:
    ExpectFailWith(procedure begin raise EConvertError.Create('bad'); end,
      EConvertError, 'bad'); }
procedure ExpectFailWith(AProc: TTestClosure;
  AExceptionClass: ExceptClass;
  const AContains: string = '');

{ Create TMock, run AProc, free mock — even on exception. }
procedure WithMock(AProc: TMockProc);

{ Create TMock, run AProc inside ExpectFail, free mock.
  Combines mock lifecycle with assertion-failure verification. }
procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string = '');

{ Create a TTestConfig with a fresh TBufferSink as OutSink+ErrSink and AnsiMode=amOff.
  Returns the sink so the caller can read captured output. }
function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;

{ Create a temporary directory, run AProc(dir), then delete it.
  The directory is always cleaned up, even on exception.
  Example:
    WithTempDir(procedure(const Dir: string)
    begin
      WriteFileContents(Dir + '/test.txt', 'hello');
      CheckTrue(FileExists(Dir + '/test.txt'));
    end); }
procedure WithTempDir(AProc: TTempDirProc);

implementation

uses
  SysUtils,
  nextpas.core.fs,
  nextpas.core.platform.env;

procedure ExpectFail(AProc: TTestClosure;
  const AContains: string);
var
  LRaised: Boolean = False;
begin
  try
    AProc;
  except
    on E: ETestSkipped do
      raise;
    on E: EAssertionFailed do
    begin
      LRaised := True;
      if AContains <> '' then
        Check(Pos(AContains, E.Message) > 0,
          'expected "' + AContains + '" in "' + E.Message + '"');
    end;
  end;
  if not LRaised then
    Fail('expected assertion failure but nothing raised');
end;

procedure ExpectFailWith(AProc: TTestClosure;
  AExceptionClass: ExceptClass;
  const AContains: string);
begin
  if AExceptionClass = nil then
    InternalFail('ExpectFailWith: AExceptionClass is nil');
  try
    AProc;
    Fail('expected ' + AExceptionClass.ClassName + ' but nothing raised');
  except
    on E: ETestSkipped do
      raise;
    on E: Exception do
    begin
      if not (E is AExceptionClass) then
        InternalFail('Expected ' + AExceptionClass.ClassName +
          ' but got ' + E.ClassName + ': ' + E.Message);
      if AContains <> '' then
        Check(Pos(AContains, E.Message) > 0,
          'expected "' + AContains + '" in "' + E.Message + '"');
    end;
  end;
end;

procedure WithMock(AProc: TMockProc);
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    AProc(LM);
  finally
    LM.Free;
  end;
end;

procedure ExpectFailWithMock(AProc: TMockProc;
  const AContains: string);
var
  LM: TMock;
begin
  LM := TMock.Create;
  try
    ExpectFail(procedure
    begin
      AProc(LM);
    end, AContains);
  finally
    LM.Free;
  end;
end;

function MakeBufferConfig(out ASink: TBufferSink): TTestConfig;
begin
  ASink := TBufferSink.Create;
  Result := DefaultConfig;
  Result.OutSink := ASink;
  Result.ErrSink := ASink;
  Result.AnsiMode := amOff;
end;

procedure WithTempDir(AProc: TTempDirProc);
var
  LBaseDir, LDir: string;
begin
  LBaseDir := platform_env_get_str('TMPDIR');
  if LBaseDir = '' then
    LBaseDir := '/tmp';
  LBaseDir := IncludeTrailingPathDelimiter(LBaseDir);
  { Use address + counter to avoid collisions across concurrent calls.
    Int64(@AProc) is unique per closure; GetTickCount64 adds temporal uniqueness. }
  LDir := LBaseDir + 'nextpas_tmp_' +
    IntToStr(Int64(@AProc)) + '_' +
    IntToStr(GetTickCount64);
  if not ForceDirectories(LDir) then
    InternalFail('WithTempDir: cannot create directory ' + LDir);
  try
    AProc(LDir);
  finally
    try
      RemoveAll(LDir);
    except
      { Cleanup failure should not mask the original test exception }
    end;
  end;
end;

end.
