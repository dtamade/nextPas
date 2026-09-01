unit nextpas.core.tar.fs;
{**
 * @desc Tar 与文件系统之间的便捷层：递归打包目录、解包归档到目录。
 * 复用 zip.fs 的 deferred-dir、排序、名安全、symlink 拒绝等模式，保持确定性与 fail-closed。
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.tar.base,
  nextpas.core.tar.writer;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
function TarPackDir(const ADir: string): TBytes;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);

implementation

uses
  nextpas.core.exception,
  nextpas.core.tar.common,
  nextpas.core.tar.reader,
  nextpas.core.fs,
  nextpas.core.io.intf,
  nextpas.core.io.base,
  nextpas.core.io.memory;

type
  TWalkEntry = record
    FRel: string;
    FFull: string;
    FIsDir: Boolean;
    FMtime: Int64;
    FMode: Word;
  end;
  TWalkArray = array of TWalkEntry;

  TDeferredDir = record
    FFull: string;
    FMode: Word;
    FMtimeNs: Int64;
  end;
  TDeferredDirArray = array of TDeferredDir;

procedure EnsureWalkCapacity(var A: TWalkArray; AMin: Integer); inline;
var
  LCap, LNew: Integer;
begin
  LCap := Length(A);
  if LCap >= AMin then Exit;
  if LCap = 0 then LCap := 16;
  LNew := LCap;
  while LNew < AMin do
    LNew := LNew * 2;
  SetLength(A, LNew);
end;

procedure WalkAppend(var A: TWalkArray; var ACount: Integer; const ARel, AFull: string; AIsDir: Boolean; AMtime: Int64; AMode: Word); inline;
begin
  EnsureWalkCapacity(A, ACount + 1);
  A[ACount].FRel := ARel;
  A[ACount].FFull := AFull;
  A[ACount].FIsDir := AIsDir;
  A[ACount].FMtime := AMtime;
  A[ACount].FMode := AMode;
  Inc(ACount);
end;

procedure SortDirEntries(var A: TDirEntryArray);
var
  LStackLo, LStackHi: array[0..63] of Integer;
  LSp, LLo, LHi, LI, LJ: Integer;
  LPivot: string;
  LTmp: TDirEntry;
begin
  if Length(A) < 2 then Exit;
  LSp := 0;
  LStackLo[LSp] := 0;
  LStackHi[LSp] := High(A);
  Inc(LSp);
  while LSp > 0 do
  begin
    Dec(LSp);
    LLo := LStackLo[LSp];
    LHi := LStackHi[LSp];
    if LLo >= LHi then Continue;
    LI := LLo;
    LJ := LHi;
    LPivot := A[(LLo + LHi) shr 1].Name;
    repeat
      while A[LI].Name < LPivot do Inc(LI);
      while A[LJ].Name > LPivot do Dec(LJ);
      if LI <= LJ then
      begin
        LTmp := A[LI];
        A[LI] := A[LJ];
        A[LJ] := LTmp;
        Inc(LI);
        Dec(LJ);
      end;
    until LI > LJ;
    if (LJ - LLo) > (LHi - LI) then
    begin
      if LLo < LJ then
      begin
        LStackLo[LSp] := LLo;
        LStackHi[LSp] := LJ;
        Inc(LSp);
      end;
      if LI < LHi then
      begin
        LStackLo[LSp] := LI;
        LStackHi[LSp] := LHi;
        Inc(LSp);
      end;
    end
    else
    begin
      if LI < LHi then
      begin
        LStackLo[LSp] := LI;
        LStackHi[LSp] := LHi;
        Inc(LSp);
      end;
      if LLo < LJ then
      begin
        LStackLo[LSp] := LLo;
        LStackHi[LSp] := LJ;
        Inc(LSp);
      end;
    end;
  end;
end;

procedure CollectLevel(const AAbsDir, ARelPrefix: string; var AOut: TWalkArray; var ACount: Integer);
var
  LEntries: TDirEntryArray;
  LI: Integer;
  LName, LChildAbs, LChildRel: string;
  LInfo: TFileInfo;
begin
  LEntries := ReadDir(AAbsDir);
  SortDirEntries(LEntries);
  for LI := 0 to High(LEntries) do
  begin
    LName := LEntries[LI].Name;
    if (LName = '.') or (LName = '..') then
      Continue;
    if ARelPrefix = '' then
      LChildRel := LName
    else
      LChildRel := ARelPrefix + '/' + LName;
    LChildAbs := AAbsDir + '/' + LName;
    LInfo := Stat(LChildAbs);
    if LEntries[LI].IsDir then
    begin
      WalkAppend(AOut, ACount, LChildRel, LChildAbs, True, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF);
      CollectLevel(LChildAbs, LChildRel, AOut, ACount);
    end
    else if LEntries[LI].FileType = ftRegular then
      WalkAppend(AOut, ACount, LChildRel, LChildAbs, False, LInfo.ModTime div 1000000000, Word(LInfo.Permission) and $0FFF);
  end;
end;

procedure TarPackDirInto(const ADir: string; const AWriter: TTarWriter);
var
  LRoot: TFileInfo;
  LWalks: TWalkArray;
  LI, LWalksCount: Integer;
  LData: TBytes;
  LHdr: TTarHeader;
begin
  if AWriter = nil then
    raise EArgumentError.Create('tar pack: writer is nil');
  LRoot := Stat(ADir);
  if not LRoot.IsDir then
    raise EArgumentError.Create('tar pack: not a directory: ' + ADir);
  SetLength(LWalks, 0);
  LWalksCount := 0;
  CollectLevel(ADir, '', LWalks, LWalksCount);
  SetLength(LWalks, LWalksCount);
  for LI := 0 to High(LWalks) do
  begin
    LHdr := Default(TTarHeader);
    LHdr.Name := LWalks[LI].FRel;
    LHdr.MTimeUnix := LWalks[LI].FMtime;
    if LWalks[LI].FIsDir then
    begin
      LHdr.Kind := tekDirectory;
      LHdr.Mode := TarDirectoryMode(LWalks[LI].FMode);
      AWriter.AddEntry(LHdr, nil);
    end
    else
    begin
      LHdr.Kind := tekRegular;
      LHdr.Mode := TarRegularMode(LWalks[LI].FMode);
      LData := ReadFile(LWalks[LI].FFull);
      LHdr.Size := Length(LData);
      AWriter.AddEntry(LHdr, LData);
    end;
  end;
  SetLength(LWalks, 0);
end;

function TarPackDir(const ADir: string): TBytes;
var
  S: IStream;
  W: TTarWriter;
begin
  Result := nil;
  S := CreateBytesStream;
  W := TTarWriter.Create(S as IWriter);
  try
    TarPackDirInto(ADir, W);
    W.Finish;
    SetLength(Result, S.Size);
    if Length(Result) > 0 then
    begin
      S.Seek(0, soBeginning);
      if S.Read(Result[0], Length(Result)) <> Length(Result) then
        raise EIOError.Create('tar pack: short snapshot');
    end;
  finally
    W.Free;
  end;
end;

procedure EnsureNoSymlinkInPath(const APath: string); inline;
var
  LI: Integer;
  LPrefix: string;
begin
  if APath = '' then Exit;
  for LI := 1 to Length(APath) do
  begin
    if (APath[LI] = '/') or (LI = Length(APath)) then
    begin
      if LI = Length(APath) then
        LPrefix := APath
      else
        LPrefix := Copy(APath, 1, LI - 1);
      if (LPrefix <> '') and IsSymlink(LPrefix) then
        raise EParseError.Create('tar extract: symlink in path: ' + LPrefix);
    end;
  end;
end;

procedure TarExtractToDirWithOptions(const AData: TBytes; const ADestDir: string; const AOptions: TTarExtractOptions);
var
  ROpts: TTarReadOptions;
  R: TTarReader;
  H: TTarHeader;
  LFull, LParent: string;
  LSep: Integer;
  LMode: Word;
  LPayload: TBytes;
  LDirs: TDeferredDirArray;
  LMaxEntry: SizeUInt;
  LMaxTotal: UInt64;
begin
  if AOptions.MaxEntrySize = 0 then
    LMaxEntry := C_TAR_DEFAULT_MAX_ENTRY
  else
    LMaxEntry := AOptions.MaxEntrySize;
  LMaxTotal := AOptions.MaxTotalSize;
  ROpts.MaxEntrySize := LMaxEntry;
  ROpts.MaxTotalSize := LMaxTotal;
  R := TTarReader.CreateWithOptions(AData, ROpts);
  try
    MkdirAll(ADestDir, PermDirDefault);
    EnsureNoSymlinkInPath(ADestDir);
    SetLength(LDirs, 0);
    try
      while R.Next(H) do
      begin
        GuardTarNameForRead(H.Name);
        if (H.Kind <> tekRegular) and (H.Kind <> tekDirectory) and AOptions.SkipSpecial then
          Continue;
        LFull := ADestDir;
        while (LFull <> '') and (LFull[Length(LFull)] = '/') do
          Delete(LFull, Length(LFull), 1);
        LFull := LFull + '/' + H.Name;
        while (LFull <> '') and (LFull[Length(LFull)] = '/') do
          Delete(LFull, Length(LFull), 1);
        LSep := Length(LFull);
        while (LSep > 0) and (LFull[LSep] <> '/') do
          Dec(LSep);
        if LSep > 0 then
        begin
          LParent := Copy(LFull, 1, LSep - 1);
          EnsureNoSymlinkInPath(LParent);
          MkdirAll(LParent, PermDirDefault);
        end;
        LMode := Word(H.Mode and $0FFF);
        if H.Kind = tekDirectory then
          MkdirAll(LFull, PermDirDefault)
        else if H.Kind = tekRegular then
        begin
          LPayload := R.EntryData;
          WriteFile(LFull, LPayload, PermDefault);
          if AOptions.RestoreMode and (LMode <> 0) then
            try Chmod(LFull, TFilePermission(LMode)); except on E: Exception do ; end;
          try Chtimes(LFull, H.MTimeUnix * 1000000000, H.MTimeUnix * 1000000000); except on E: Exception do ; end;
        end
        else
          Continue;
        if H.Kind = tekDirectory then
        begin
          SetLength(LDirs, Length(LDirs) + 1);
          LDirs[High(LDirs)].FFull := LFull;
          LDirs[High(LDirs)].FMode := LMode;
          LDirs[High(LDirs)].FMtimeNs := H.MTimeUnix * 1000000000;
        end;
      end;
    finally
      for LSep := High(LDirs) downto 0 do
      begin
        if AOptions.RestoreMode and (LDirs[LSep].FMode <> 0) then
          try Chmod(LDirs[LSep].FFull, TFilePermission(LDirs[LSep].FMode and $0FFF)); except on E: Exception do ; end;
        try Chtimes(LDirs[LSep].FFull, LDirs[LSep].FMtimeNs, LDirs[LSep].FMtimeNs); except on E: Exception do ; end;
      end;
    end;
  finally
    R.Free;
  end;
end;

procedure TarExtractToDir(const AData: TBytes; const ADestDir: string);
var
  O: TTarExtractOptions;
begin
  O := DefaultTarExtractOptions;
  TarExtractToDirWithOptions(AData, ADestDir, O);
end;

end.
