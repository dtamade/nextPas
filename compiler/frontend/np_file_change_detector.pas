{**
 * np_file_change_detector.pas — File Change Detector
 *
 * 文件变更检测接口。使用 mtime 机制追踪文件变更。
 * 支持目录扫描和文件级变更检测。
 *
 * 对标 Go 的 build cache mtime 检查
 *}

unit np_file_change_detector;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.core.text.strings,
  nextpas.core.collections.vec;

type
  TFileSnapshot = record
    Path: string;
    ModifiedTime: TDateTime;
    FileSize: Int64;
  end;

  TStringArray = array of string;
  TFileSnapshotVec = specialize TVec<TFileSnapshot>;
  TChangedFileVec = specialize TVec<string>;

  TFileChangeDetector = class
  private
    FSnapshots: TFileSnapshotVec;
    FChangedFiles: TChangedFileVec;
    function FindSnapshotIndex(const APath: string): LongInt;
    function GetFileSnapshot(const APath: string): TFileSnapshot;
    function MatchesExtension(const AFileName: string;
      const AExtensions: TStringArray): Boolean;
    procedure HandleScannedFile(const AFilePath: string;
      AInitialSnapshotCount: LongInt);
    procedure ScanDirectoryRecursive(const ADir: string;
      const AExtensions: TStringArray; AInitialSnapshotCount: LongInt);
  public
    constructor Create;
    destructor Destroy; override;
    function SnapshotCount: LongInt;
    function AnyChanged: Boolean;
    function ChangedFiles: TStringArray;
    procedure InvalidatePrefix(const APrefix: string);
    procedure TakeSnapshot(const ARootPath: string; const AExtensions: TStringArray);
    procedure TrackFile(const APath: string);
    function IsFileChanged(const APath: string): Boolean;
  end;

implementation

constructor TFileChangeDetector.Create;
begin
  inherited Create;
  FSnapshots := TFileSnapshotVec.Create;
  FChangedFiles := TChangedFileVec.Create;
  FSnapshots.EnsureCapacity(64);
  FChangedFiles.EnsureCapacity(16);
end;

destructor TFileChangeDetector.Destroy;
begin
  FChangedFiles.Free;
  FSnapshots.Free;
  inherited Destroy;
end;

function TFileChangeDetector.FindSnapshotIndex(const APath: string): LongInt;
var
  I: LongInt;
begin
  for I := 0 to LongInt(FSnapshots.Count) - 1 do
    if SameText(FSnapshots[I].Path, APath) then
      Exit(I);
  Result := -1;
end;

function TFileChangeDetector.GetFileSnapshot(const APath: string): TFileSnapshot;
var
  SR: TSearchRec;
begin
  Result.Path := APath;
  if FindFirst(APath, faAnyFile, SR) = 0 then
  begin
    Result.ModifiedTime := SR.TimeStamp;
    Result.FileSize := SR.Size;
    FindClose(SR);
  end
  else
  begin
    Result.ModifiedTime := 0;
    Result.FileSize := -1;
  end;
end;

function TFileChangeDetector.SnapshotCount: LongInt;
begin
  Result := LongInt(FSnapshots.Count);
end;

function TFileChangeDetector.AnyChanged: Boolean;
begin
  Result := FChangedFiles.Count > 0;
end;

function TFileChangeDetector.ChangedFiles: TStringArray;
var
  I: LongInt;
begin
  SetLength(Result, LongInt(FChangedFiles.Count));
  for I := 0 to LongInt(FChangedFiles.Count) - 1 do
    Result[I] := FChangedFiles[I];
end;

procedure TFileChangeDetector.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
begin
  for I := LongInt(FSnapshots.Count) - 1 downto 0 do
    if Pos(APrefix, FSnapshots[I].Path) = 1 then
      FSnapshots.DeleteSwap(SizeUInt(I));
end;

function TFileChangeDetector.MatchesExtension(const AFileName: string;
  const AExtensions: TStringArray): Boolean;
var
  Ext: string;
  I: LongInt;
begin
  if Length(AExtensions) = 0 then
    Exit(True);
  Ext := ExtractFileExt(AFileName);
  for I := 0 to High(AExtensions) do
    if SameText(Ext, AExtensions[I]) then
      Exit(True);
  Result := False;
end;

procedure TFileChangeDetector.HandleScannedFile(const AFilePath: string;
  AInitialSnapshotCount: LongInt);
var
  Snapshot: TFileSnapshot;
  Idx: LongInt;
begin
  Snapshot := GetFileSnapshot(AFilePath);
  Idx := FindSnapshotIndex(AFilePath);
  if Idx >= 0 then
  begin
    if (FSnapshots[Idx].ModifiedTime <> Snapshot.ModifiedTime) or
       (FSnapshots[Idx].FileSize <> Snapshot.FileSize) then
    begin
      FChangedFiles.Push(AFilePath);
      FSnapshots[Idx] := Snapshot;
    end;
  end
  else
  begin
    if AInitialSnapshotCount > 0 then
      FChangedFiles.Push(AFilePath);
    FSnapshots.Push(Snapshot);
  end;
end;

procedure TFileChangeDetector.ScanDirectoryRecursive(const ADir: string;
  const AExtensions: TStringArray; AInitialSnapshotCount: LongInt);
var
  SR: TSearchRec;
  FullPath: string;
begin
  if FindFirst(ADir + '/*', faAnyFile, SR) <> 0 then
    Exit;
  try
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;
      FullPath := ADir + '/' + SR.Name;
      if (SR.Attr and faDirectory) <> 0 then
        ScanDirectoryRecursive(FullPath, AExtensions, AInitialSnapshotCount)
      else
      begin
        if not MatchesExtension(SR.Name, AExtensions) then
          Continue;
        HandleScannedFile(FullPath, AInitialSnapshotCount);
      end;
    until FindNext(SR) <> 0;
  finally
    FindClose(SR);
  end;
end;

procedure TFileChangeDetector.TakeSnapshot(const ARootPath: string;
  const AExtensions: TStringArray);
var
  InitialCount: LongInt;
  I: LongInt;
  Probe: TFileSnapshot;
begin
  FChangedFiles.Clear;
  InitialCount := LongInt(FSnapshots.Count);
  ScanDirectoryRecursive(ARootPath, AExtensions, InitialCount);
  for I := LongInt(FSnapshots.Count) - 1 downto 0 do
  begin
    if Pos(ARootPath, FSnapshots[I].Path) <> 1 then
      Continue;
    Probe := GetFileSnapshot(FSnapshots[I].Path);
    if Probe.FileSize = -1 then
    begin
      FChangedFiles.Push(FSnapshots[I].Path);
      FSnapshots.DeleteSwap(SizeUInt(I));
    end;
  end;
end;

procedure TFileChangeDetector.TrackFile(const APath: string);
var
  Snapshot: TFileSnapshot;
  Idx: LongInt;
begin
  Snapshot := GetFileSnapshot(APath);
  Idx := FindSnapshotIndex(APath);
  if Idx >= 0 then
    FSnapshots[Idx] := Snapshot
  else
    FSnapshots.Push(Snapshot);
end;

function TFileChangeDetector.IsFileChanged(const APath: string): Boolean;
var
  Idx: LongInt;
  Current: TFileSnapshot;
begin
  Idx := FindSnapshotIndex(APath);
  if Idx < 0 then
    Exit(True);
  Current := GetFileSnapshot(APath);
  Result := (FSnapshots[Idx].ModifiedTime <> Current.ModifiedTime) or
            (FSnapshots[Idx].FileSize <> Current.FileSize);
end;

end.
