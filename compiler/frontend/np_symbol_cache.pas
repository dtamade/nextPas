unit np_symbol_cache;

{$mode objfpc}{$H+}

interface

const
  NPB_MAGIC = $4E504231; { 'NPB1' }
  NPB_VERSION = 1;

type
  { Persistent cache entry for an imported unit's symbol table.
    Mirrors TCachedSymbolEntry in np_semantic_analyzer but adds TypeRefName
    for cross-session type resolution. }
  TDiskCachedSymbolEntry = record
    Name: string;
    Kind: string;
    OwnerUnitId: string;
    ParamCount: LongInt;
    MinParamCount: LongInt;
    ParamSignature: string;
    TypeRefName: string;
    ByteOffset: LongInt;
  end;

  TDiskCachedUnit = record
    UnitId: string;
    SourcePath: string;
    Fingerprint: UInt32;
    Symbols: array of TDiskCachedSymbolEntry;
    SymbolCount: LongInt;
  end;

  TDiskSymbolCache = class
  private
    FCacheDir: string;
    function CacheFilePath(const AUnitId: string): string;
  public
    constructor Create(const ACacheDir: string);
    function TryLoad(const AUnitId: string; AExpectedFingerprint: UInt32;
      out ACachedUnit: TDiskCachedUnit): Boolean;
    procedure Save(const AUnit: TDiskCachedUnit);
    property CacheDir: string read FCacheDir;
  end;

function ComputeSourceFingerprint(const ASourceText: string): UInt32;
function ComputeSourceFingerprintFromFile(const ASourcePath: string): UInt32;

implementation

uses
  SysUtils;

{ FNV-1a hash — same algorithm as SwissTable.HashStr }

function ComputeSourceFingerprint(const ASourceText: string): UInt32;
var
  I: Integer;
begin
  Result := 2166136261;
  for I := 1 to Length(ASourceText) do
    Result := (Result xor Ord(ASourceText[I])) * 16777619;
  Result := (Result xor (Result shr 16)) * UInt32($7feb352d);
  Result := (Result xor (Result shr 15)) * UInt32($846ca68b);
  Result := Result xor (Result shr 16);
end;

function ComputeSourceFingerprintFromFile(const ASourcePath: string): UInt32;
var
  LContent: string;
  LFile: Text;
  LLine: string;
begin
  Result := 0;
  if not FileExists(ASourcePath) then
    Exit;

  LContent := '';
  Assign(LFile, ASourcePath);
  Reset(LFile);
  try
    while not EOF(LFile) do
    begin
      ReadLn(LFile, LLine);
      LContent := LContent + LLine + #10;
    end;
  finally
    Close(LFile);
  end;

  Result := ComputeSourceFingerprint(LContent);
end;

{ TDiskSymbolCache }

constructor TDiskSymbolCache.Create(const ACacheDir: string);
begin
  inherited Create;
  FCacheDir := ACacheDir;
  if not DirectoryExists(FCacheDir) then
    ForceDirectories(FCacheDir);
end;

function TDiskSymbolCache.CacheFilePath(const AUnitId: string): string;
begin
  Result := FCacheDir + '/' + LowerCase(AUnitId) + '.npb';
end;

{ Binary I/O helpers }

procedure WriteStr(var F: file; const S: string);
var
  LLen: LongInt;
begin
  LLen := Length(S);
  BlockWrite(F, LLen, SizeOf(LongInt));
  if LLen > 0 then
    BlockWrite(F, S[1], LLen);
end;

function ReadStr(var F: file): string;
var
  LLen: LongInt;
begin
  BlockRead(F, LLen, SizeOf(LongInt));
  if LLen > 0 then
  begin
    SetLength(Result, LLen);
    BlockRead(F, Result[1], LLen);
  end
  else
    Result := '';
end;

procedure WriteInt(var F: file; V: LongInt);
begin
  BlockWrite(F, V, SizeOf(LongInt));
end;

function ReadInt(var F: file): LongInt;
begin
  BlockRead(F, Result, SizeOf(LongInt));
end;

procedure WriteEntry(var F: file; const E: TDiskCachedSymbolEntry);
begin
  WriteStr(F, E.Name);
  WriteStr(F, E.Kind);
  WriteStr(F, E.OwnerUnitId);
  WriteInt(F, E.ParamCount);
  WriteInt(F, E.MinParamCount);
  WriteStr(F, E.ParamSignature);
  WriteStr(F, E.TypeRefName);
  WriteInt(F, E.ByteOffset);
end;

function ReadEntry(var F: file): TDiskCachedSymbolEntry;
begin
  Result.Name := ReadStr(F);
  Result.Kind := ReadStr(F);
  Result.OwnerUnitId := ReadStr(F);
  Result.ParamCount := ReadInt(F);
  Result.MinParamCount := ReadInt(F);
  Result.ParamSignature := ReadStr(F);
  Result.TypeRefName := ReadStr(F);
  Result.ByteOffset := ReadInt(F);
end;

function TDiskSymbolCache.TryLoad(const AUnitId: string;
  AExpectedFingerprint: UInt32; out ACachedUnit: TDiskCachedUnit): Boolean;
var
  LPath: string;
  LFile: file;
  LMagic, LVersion: UInt32;
  I: LongInt;
begin
  Result := False;
  LPath := CacheFilePath(AUnitId);
  if not FileExists(LPath) then
    Exit;

  Assign(LFile, LPath);
  Reset(LFile, 1);
  try
    if FileSize(LFile) < 16 then
      Exit;

    BlockRead(LFile, LMagic, 4);
    if LMagic <> NPB_MAGIC then
      Exit;
    BlockRead(LFile, LVersion, 4);
    if LVersion <> NPB_VERSION then
      Exit;

    ACachedUnit.Fingerprint := 0;
    BlockRead(LFile, ACachedUnit.Fingerprint, 4);
    if ACachedUnit.Fingerprint <> AExpectedFingerprint then
      Exit;

    ACachedUnit.UnitId := ReadStr(LFile);
    ACachedUnit.SourcePath := ReadStr(LFile);
    ACachedUnit.SymbolCount := ReadInt(LFile);
    SetLength(ACachedUnit.Symbols, ACachedUnit.SymbolCount);
    for I := 0 to ACachedUnit.SymbolCount - 1 do
      ACachedUnit.Symbols[I] := ReadEntry(LFile);

    Result := True;
  except
    Result := False;
  end;

  Close(LFile);
end;

procedure TDiskSymbolCache.Save(const AUnit: TDiskCachedUnit);
var
  LPath: string;
  LFile: file;
  LMagic, LVersion: UInt32;
  I: LongInt;
begin
  LPath := CacheFilePath(AUnit.UnitId);
  Assign(LFile, LPath);
  Rewrite(LFile, 1);
  try
    LMagic := NPB_MAGIC;
    LVersion := NPB_VERSION;
    BlockWrite(LFile, LMagic, 4);
    BlockWrite(LFile, LVersion, 4);
    BlockWrite(LFile, AUnit.Fingerprint, 4);
    WriteStr(LFile, AUnit.UnitId);
    WriteStr(LFile, AUnit.SourcePath);
    WriteInt(LFile, AUnit.SymbolCount);
    for I := 0 to AUnit.SymbolCount - 1 do
      WriteEntry(LFile, AUnit.Symbols[I]);
  finally
    Close(LFile);
  end;
end;

end.
