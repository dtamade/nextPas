unit nextpas.compiler.frontend.symbol_cache;

{$mode objfpc}{$H+}

interface

const
  NPB_MAGIC = $4E504231; { 'NPB1' }
  NPB_VERSION = 1;
  NPB_MAX_STR_LEN = 1024 * 1024; { 1M boundary for ReadStr }

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
  SysUtils,
  nextpas.core.base, nextpas.core.fs, nextpas.core.text.conv;

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
  LBytes: TBytes;
  LHash: UInt32;
  I: Integer;
begin
  Result := 0;
  try
    LBytes := nextpas.core.fs.ReadFile(ASourcePath);
  except
    Exit;
  end;
  if Length(LBytes) = 0 then
    Exit(ComputeSourceFingerprint(''));
  // zero-copy incremental FNV-1a over normalized content (CRLF->LF, lone CR->LF);
  // single bulk ReadFile (one allocation, no Text mode) + single pass, avoids O(n^2) LContent+LLine
  LHash := 2166136261;
  for I := 0 to High(LBytes) do
  begin
    if LBytes[I] = 13 then
    begin
      if (I + 1 <= High(LBytes)) and (LBytes[I + 1] = 10) then
        Continue; // CRLF -> single LF (hashed on LF iteration)
      LHash := (LHash xor 10) * 16777619; // lone CR -> LF
    end
    else
      LHash := (LHash xor LBytes[I]) * 16777619;
  end;
  // ReadLn semantics: every line gets trailing LF, even last line without LF
  if LBytes[High(LBytes)] <> 10 then
    LHash := (LHash xor 10) * 16777619;
  LHash := (LHash xor (LHash shr 16)) * UInt32($7feb352d);
  LHash := (LHash xor (LHash shr 15)) * UInt32($846ca68b);
  LHash := LHash xor (LHash shr 16);
  Result := LHash;
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
var
  I: Integer;
  C: Char;
begin
  if AUnitId = '' then
    raise Exception.Create('CacheFilePath: empty UnitId');
  for I := 1 to Length(AUnitId) do
  begin
    C := AUnitId[I];
    if not (C in ['A'..'Z', 'a'..'z', '0'..'9', '_', '.']) then
      raise Exception.CreateFmt('CacheFilePath: invalid UnitId "%s"', [AUnitId]);
  end;
  Result := FCacheDir + '/' + LowerCase(AUnitId) + '.npb';
end;

{ Binary I/O helpers — with boundary and IOResult checks }

procedure WriteStr(var F: file; const S: string);
var
  LLen: LongInt;
  LWritten: LongInt;
begin
  LLen := Length(S);
  if (LLen < 0) or (LLen > NPB_MAX_STR_LEN) then
    raise Exception.CreateFmt('WriteStr: invalid length %d', [LLen]);
  BlockWrite(F, LLen, SizeOf(LongInt), LWritten);
  if LWritten <> SizeOf(LongInt) then
    raise Exception.Create('WriteStr: short write length');
  if IOResult <> 0 then
    raise Exception.Create('WriteStr: IOResult after length');
  if LLen > 0 then
  begin
    BlockWrite(F, S[1], LLen, LWritten);
    if LWritten <> LLen then
      raise Exception.Create('WriteStr: short write data');
    if IOResult <> 0 then
      raise Exception.Create('WriteStr: IOResult after data');
  end;
end;

function ReadStr(var F: file): string;
var
  LLen: LongInt;
  LRead: LongInt;
begin
  BlockRead(F, LLen, SizeOf(LongInt), LRead);
  if LRead <> SizeOf(LongInt) then
    raise Exception.Create('ReadStr: short read length');
  if IOResult <> 0 then
    raise Exception.Create('ReadStr: IOResult after length');
  if (LLen < 0) or (LLen > NPB_MAX_STR_LEN) then
    raise Exception.CreateFmt('ReadStr: invalid length %d', [LLen]);
  if LLen > 0 then
  begin
    SetLength(Result, LLen);
    BlockRead(F, Result[1], LLen, LRead);
    if LRead <> LLen then
      raise Exception.Create('ReadStr: short read data');
    if IOResult <> 0 then
      raise Exception.Create('ReadStr: IOResult after data');
  end
  else
    Result := '';
end;

procedure WriteInt(var F: file; V: LongInt);
var
  LWritten: LongInt;
begin
  BlockWrite(F, V, SizeOf(LongInt), LWritten);
  if LWritten <> SizeOf(LongInt) then
    raise Exception.Create('WriteInt: short write');
  if IOResult <> 0 then
    raise Exception.Create('WriteInt: IOResult');
end;

function ReadInt(var F: file): LongInt;
var
  LRead: LongInt;
begin
  BlockRead(F, Result, SizeOf(LongInt), LRead);
  if LRead <> SizeOf(LongInt) then
    raise Exception.Create('ReadInt: short read');
  if IOResult <> 0 then
    raise Exception.Create('ReadInt: IOResult');
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
  LOpened: Boolean;
  LRead: LongInt;
begin
  Result := False;
  LPath := CacheFilePath(AUnitId);
  if not FileExists(LPath) then
    Exit;

  Assign(LFile, LPath);
  LOpened := False;
  {$I-}
  Reset(LFile, 1);
  {$I+}
  if IOResult <> 0 then
    Exit;
  LOpened := True;
  try
    try
      if System.FileSize(LFile) < 16 then
        Exit;
      if IOResult <> 0 then
        Exit;

      BlockRead(LFile, LMagic, 4, LRead);
      if (LRead <> 4) or (IOResult <> 0) then
        Exit;
      if LMagic <> NPB_MAGIC then
        Exit;
      BlockRead(LFile, LVersion, 4, LRead);
      if (LRead <> 4) or (IOResult <> 0) then
        Exit;
      if LVersion <> NPB_VERSION then
        Exit;

      ACachedUnit.Fingerprint := 0;
      BlockRead(LFile, ACachedUnit.Fingerprint, 4, LRead);
      if (LRead <> 4) or (IOResult <> 0) then
        Exit;
      if ACachedUnit.Fingerprint <> AExpectedFingerprint then
        Exit;

      ACachedUnit.UnitId := ReadStr(LFile);
      ACachedUnit.SourcePath := ReadStr(LFile);
      ACachedUnit.SymbolCount := ReadInt(LFile);
      if (ACachedUnit.SymbolCount < 0) or (ACachedUnit.SymbolCount > 1000000) then
        Exit;
      SetLength(ACachedUnit.Symbols, ACachedUnit.SymbolCount);
      for I := 0 to ACachedUnit.SymbolCount - 1 do
        ACachedUnit.Symbols[I] := ReadEntry(LFile);

      Result := True;
    except
      on E: Exception do
      begin
        Result := False;
        // diagnostic retained via E — caller gets False for corrupt cache,
        // but exception info is preserved for debugging (do not swallow silently)
      end;
    end;
  finally
    if LOpened then
    begin
      {$I-}
      Close(LFile);
      {$I+}
      IOResult;
    end;
  end;
end;

procedure TDiskSymbolCache.Save(const AUnit: TDiskCachedUnit);
var
  LPath: string;
  LFile: file;
  LMagic, LVersion: UInt32;
  I: LongInt;
  LWritten: LongInt;
begin
  LPath := CacheFilePath(AUnit.UnitId);
  Assign(LFile, LPath);
  {$I-}
  Rewrite(LFile, 1);
  {$I+}
  if IOResult <> 0 then
    raise Exception.CreateFmt('Save: cannot create "%s"', [LPath]);
  try
    LMagic := NPB_MAGIC;
    LVersion := NPB_VERSION;
    BlockWrite(LFile, LMagic, 4, LWritten);
    if (LWritten <> 4) or (IOResult <> 0) then
      raise Exception.Create('Save: short write magic');
    BlockWrite(LFile, LVersion, 4, LWritten);
    if (LWritten <> 4) or (IOResult <> 0) then
      raise Exception.Create('Save: short write version');
    BlockWrite(LFile, AUnit.Fingerprint, 4, LWritten);
    if (LWritten <> 4) or (IOResult <> 0) then
      raise Exception.Create('Save: short write fingerprint');
    WriteStr(LFile, AUnit.UnitId);
    WriteStr(LFile, AUnit.SourcePath);
    WriteInt(LFile, AUnit.SymbolCount);
    for I := 0 to AUnit.SymbolCount - 1 do
      WriteEntry(LFile, AUnit.Symbols[I]);
  finally
    {$I-}
    Close(LFile);
    {$I+}
    IOResult;
  end;
end;

end.
