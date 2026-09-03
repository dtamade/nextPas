unit nextpas.core.simd.dispatchapi.support;

{$I ../../src/nextpas.core.settings.inc}
{$CODEPAGE UTF8}
{$WARN 6060 OFF}

// Keep parity with the original testcase compilation behavior.
{$R-}{$Q-}

// Mirror the global conditions that make NEON asm compile in the backend unit.
{$IFDEF CPUAARCH64}
  {$IFDEF FPC}
    {$IF FPC_FULLVERSION >= 030301}
      {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
        {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
          {$IFDEF NEXTPAS_SIMD_ENABLE_NEON_ASM}
            {$IFDEF NEXTPAS_SIMD_NEON_ASM_COMPILER_READY}
              {$DEFINE NEXTPAS_SIMD_TEST_NEON_ASM_COMPILED}
            {$ENDIF}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

// Mirror the global conditions that make RISCVV asm compile in the backend unit.
{$IF DEFINED(CPURISCV64) OR DEFINED(CPURISCV32)}
  {$IFDEF FPC}
    {$IFNDEF SIMD_VECTOR_ASM_DISABLED}
      {$IFDEF NEXTPAS_SIMD_EXPERIMENTAL_BACKEND_ASM}
        {$IFDEF NEXTPAS_SIMD_ENABLE_RISCVV_ASM}
          {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_COMPILER_READY}
            {$IFDEF NEXTPAS_SIMD_RISCVV_ASM_OPCODE_READY}
              {$DEFINE NEXTPAS_SIMD_TEST_RISCVV_ASM_COMPILED}
            {$ENDIF}
          {$ENDIF}
        {$ENDIF}
      {$ENDIF}
    {$ENDIF}
  {$ENDIF}
{$ENDIF}

interface

uses
  nextpas.core.base,
  nextpas.core.math,
  nextpas.core.path,
  nextpas.core.fs,
  nextpas.core.text.conv,
  nextpas.core.platform.files,
  nextpas.core.platform.files.base,
  nextpas.core.platform.path,
  nextpas.core.test,
  nextpas.core.simd,
  nextpas.core.simd.testcase,
  nextpas.core.simd.base,
  nextpas.core.simd.bench,
  nextpas.core.simd.cpuinfo,
  nextpas.core.simd.cpuinfo.base,
  nextpas.core.simd.utils,
  nextpas.core.simd.ops,
  nextpas.core.simd.dispatch,
  nextpas.core.simd.dataplane,
  nextpas.core.simd.backend.priority,
  nextpas.core.simd.public_smoke_support,
  nextpas.core.simd.scalar;

type
  TSourceLinesEnumerator = record
  private
    FLines: TStringArray;
    FIndex: Integer;
  public
    class function Create(const ALines: TStringArray): TSourceLinesEnumerator; static;
    function MoveNext: Boolean;
    function GetCurrent: string;
    property Current: string read GetCurrent;
  end;

  TSourceLines = class
  private
    FLines: TStringArray;
    FText: string;
  public
    procedure LoadFromFile(const APath: string);
    function GetCount: Integer;
    function GetItem(AIndex: Integer): string;
    function GetEnumerator: TSourceLinesEnumerator;
    property Count: Integer read GetCount;
    property Items[AIndex: Integer]: string read GetItem; default;
    property Text: string read FText;
  end;

  TDispatchAPIStatefulTestCase = class(TSimdVectorAsmStatefulTestCase)
  end;

var
  GDispatchHookCountA: Integer = 0;
  GDispatchHookCountB: Integer = 0;
  GDispatchHookDisableBackendEnabled: Boolean = False;
  GDispatchHookDisableBackendArmed: Boolean = False;
  GDispatchHookDisableBackendDone: Boolean = False;
  GDispatchHookDisableBackendTarget: TSimdBackend = sbScalar;
  GDispatchHookDisableBackendOriginalTable: TSimdDispatchTable;
  GDispatchHookRestoreBackendEnabled: Boolean = False;
  GDispatchHookRestoreBackendStage: Integer = 0;
  GDispatchHookRestoreBackendTarget: TSimdBackend = sbScalar;
  GDispatchHookRestoreBackendOriginalTable: TSimdDispatchTable;
  GDispatchHookRollbackForceSuccessEnabled: Boolean = False;
  GDispatchHookRollbackForceSuccessStage: Integer = 0;
  GDispatchHookRollbackForceSuccessInMutation: Boolean = False;
  GDispatchHookRollbackForceSuccessTarget: TSimdBackend = sbScalar;
  GDispatchHookRollbackForceSuccessTargetTable: TSimdDispatchTable;
  GDispatchHookRollbackForceSuccessHigherCount: Integer = 0;
  GDispatchHookRollbackForceSuccessHigherBackends: array[0..Ord(High(TSimdBackend))] of TSimdBackend;
  GDispatchHookRollbackForceSuccessHigherTables: array[0..Ord(High(TSimdBackend))] of TSimdDispatchTable;
  GDispatchHookReForceBackendEnabled: Boolean = False;
  GDispatchHookReForceBackendStage: Integer = 0;
  GDispatchHookReForceBackendTarget: TSimdBackend = sbScalar;
  GDispatchHookResetToAutomaticEnabled: Boolean = False;
  GDispatchHookResetToAutomaticStage: Integer = 0;
  GDispatchHookResetLateForceEnabled: Boolean = False;
  GDispatchHookResetLateForceStage: Integer = 0;
  GDispatchHookResetLateForceTarget: TSimdBackend = sbScalar;
  GDispatchHookToggleRestoreResetEnabled: Boolean = False;
  GDispatchHookToggleRestoreResetStage: Integer = 0;
  GDispatchHookRollbackLateForceEnabled: Boolean = False;
  GDispatchHookRollbackLateForceStage: Integer = 0;
  GDispatchHookRollbackLateForceRequestedBackend: TSimdBackend = sbScalar;
  GDispatchHookRollbackLateForceRequestedTable: TSimdDispatchTable;
  GDispatchHookAutomaticRollbackLateForceEnabled: Boolean = False;
  GDispatchHookAutomaticRollbackLateForceStage: Integer = 0;
  GDispatchHookAutomaticRollbackLateForceRequestedBackend: TSimdBackend = sbScalar;
  GDispatchHookAutomaticRollbackLateForceRequestedTable: TSimdDispatchTable;
  GDispatchHookAutomaticRollbackRestoreLateForceEnabled: Boolean = False;
  GDispatchHookAutomaticRollbackRestoreLateForceStage: Integer = 0;
  GDispatchHookAutomaticRollbackRestoreLateForceRequestedBackend: TSimdBackend = sbScalar;
  GDispatchHookAutomaticRollbackRestoreLateForceRequestedTable: TSimdDispatchTable;
  GDispatchHookRegisterRestoreResetEnabled: Boolean = False;
  GDispatchHookRegisterRestoreResetStage: Integer = 0;
  GSimdRepoRootCache: string = '';

const
  DISPATCHAPI_PATH_BUF_SIZE = 1024;
  DISPATCHAPI_CWD_BUF_SIZE = 4096;

function IncludeTrailingPathDelimiter(const aPath: string): string; inline;
function GetCurrentDir: string; inline;
function ExpandFileName(const aPath: string): string;
function FileExists(const aPath: string): Boolean; inline;
function DirectoryExists(const aPath: string): Boolean; inline;
function ExtractFilePath(const aPath: string): string; inline;
function TrimLeft(const aValue: string): string; inline;
function DirectoryLooksLikeSimdRepoRoot(const aDir: string): Boolean;
function FindSimdRepoRootFrom(const aStartDir: string): string;
function GetSimdRepoRoot: string;
function ExpandSimdRepoPath(const aRelativePath: string): string;
function DispatchApiBackendName(const aBackend: TSimdBackend): string;
function SyntheticReduceAddF32x4CurrentDispatch(const a: TVecF32x4): Single;

implementation

{ TSourceLines — source-contract file loader without Classes }

class function TSourceLinesEnumerator.Create(const ALines: TStringArray): TSourceLinesEnumerator;
begin
  Result.FLines := ALines;
  Result.FIndex := -1;
end;

function TSourceLinesEnumerator.MoveNext: Boolean;
begin
  Inc(FIndex);
  Result := FIndex < Length(FLines);
end;

function TSourceLinesEnumerator.GetCurrent: string;
begin
  if (FIndex < 0) or (FIndex >= Length(FLines)) then
    Result := ''
  else
    Result := FLines[FIndex];
end;

procedure TSourceLines.LoadFromFile(const APath: string);
begin
  FText := ReadFileText(APath);
  FLines := ReadFileLines(APath);
end;

function TSourceLines.GetCount: Integer;
begin
  Result := Length(FLines);
end;

function TSourceLines.GetItem(AIndex: Integer): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FLines)) then
    Result := ''
  else
    Result := FLines[AIndex];
end;

function TSourceLines.GetEnumerator: TSourceLinesEnumerator;
begin
  Result := TSourceLinesEnumerator.Create(FLines);
end;

function IncludeTrailingPathDelimiter(const aPath: string): string; inline;
begin
  Result := aPath;
  if (Result <> '') and
    (Result[Length(Result)] <> PLATFORM_PATH_SEP) and
    (Result[Length(Result)] <> PLATFORM_PATH_ALT_SEP) then
    Result := Result + PLATFORM_PATH_SEP;
end;

function GetCurrentDir: string; inline;
var
  LBuf: array[0..DISPATCHAPI_CWD_BUF_SIZE - 1] of AnsiChar;
  LP: PAnsiChar;
begin
  if platform_file_getcwd(@LBuf[0], SizeOf(LBuf)) <> nil then
  begin
    LP := @LBuf[0];
    Result := AnsiString(LP);
  end
  else
    Result := '.';
end;

function ExpandFileName(const aPath: string): string;
var
  LStack: array[0..DISPATCHAPI_PATH_BUF_SIZE - 1] of AnsiChar;
  LHeap: array of AnsiChar;
  LNeed: Int32;
begin
  if aPath = '' then
    Exit('');

  LNeed := platform_path_resolve(PAnsiChar(aPath), @LStack[0], DISPATCHAPI_PATH_BUF_SIZE);
  if LNeed > 0 then
  begin
    if LNeed < DISPATCHAPI_PATH_BUF_SIZE then
      SetString(Result, PAnsiChar(@LStack[0]), LNeed)
    else
    begin
      SetLength(LHeap, LNeed + 1);
      platform_path_resolve(PAnsiChar(aPath), @LHeap[0], Length(LHeap));
      SetString(Result, PAnsiChar(@LHeap[0]), LNeed);
    end;
    Exit;
  end;

  if PathIsAbsolute(aPath) then
    Result := PathNormalize(aPath)
  else
    Result := PathNormalize(IncludeTrailingPathDelimiter(GetCurrentDir) + aPath);
end;

function FileExists(const aPath: string): Boolean; inline;
var
  LStat: TPlatformFileStat;
begin
  Result := (platform_file_stat(PAnsiChar(aPath), LStat) = 0) and
    (LStat.FileType = ftRegular);
end;

function DirectoryExists(const aPath: string): Boolean; inline;
var
  LStat: TPlatformFileStat;
begin
  Result := (platform_file_stat(PAnsiChar(aPath), LStat) = 0) and
    (LStat.FileType = ftDirectory);
end;

function ExtractFilePath(const aPath: string): string; inline;
begin
  Result := nextpas.core.path.ExtractFilePath(aPath);
end;

function TrimLeft(const aValue: string): string; inline;
begin
  Result := nextpas.core.text.conv.TrimLeft(aValue);
end;

function DirectoryLooksLikeSimdRepoRoot(const aDir: string): Boolean;
var
  LRoot: string;
begin
  LRoot := IncludeTrailingPathDelimiter(ExpandFileName(aDir));
  Result := FileExists(LRoot + 'src/nextpas.core.settings.inc')
    and DirectoryExists(LRoot + 'tests/nextpas.core.simd');
end;

function FindSimdRepoRootFrom(const aStartDir: string): string;
var
  LDir: string;
  LParentDir: string;
begin
  Result := '';
  if aStartDir = '' then
    Exit;

  LDir := ExpandFileName(aStartDir);
  while LDir <> '' do
  begin
    if DirectoryLooksLikeSimdRepoRoot(LDir) then
      Exit(LDir);

    LParentDir := ExpandFileName(IncludeTrailingPathDelimiter(LDir) + '..');
    if SameText(LParentDir, LDir) then
      Break;
    LDir := LParentDir;
  end;
end;

function GetSimdRepoRoot: string;
begin
  if GSimdRepoRootCache = '' then
  begin
    GSimdRepoRootCache := FindSimdRepoRootFrom(GetCurrentDir);
    if GSimdRepoRootCache = '' then
      GSimdRepoRootCache := FindSimdRepoRootFrom(ExtractFilePath(ParamStr(0)));
  end;
  Result := GSimdRepoRootCache;
end;

function ExpandSimdRepoPath(const aRelativePath: string): string;
var
  LRepoRoot: string;
begin
  LRepoRoot := GetSimdRepoRoot;
  if LRepoRoot <> '' then
    Result := ExpandFileName(IncludeTrailingPathDelimiter(LRepoRoot) + aRelativePath)
  else
    Result := ExpandFileName(IncludeTrailingPathDelimiter(ExtractFilePath(ParamStr(0))) + aRelativePath);
end;

function DispatchApiBackendName(const aBackend: TSimdBackend): string;
begin
  Result := GetBackendInfo(aBackend).Name;
end;

function SyntheticReduceAddF32x4CurrentDispatch(const a: TVecF32x4): Single;
begin
  Result := 42.25;
end;

end.
