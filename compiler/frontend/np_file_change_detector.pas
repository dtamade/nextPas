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

interface

uses
  SysUtils,
  nextpas.core.text.strings;

type
  TFileSnapshot = record
    Path: string;
    ModifiedTime: TDateTime;
    FileSize: Int64;
  end;

  TFileChangeDetector = class
  private
    FSnapshots: array of TFileSnapshot;
    FSnapshotCount: LongInt;
    FChangedFiles: TStringArray;
    FChangedCount: LongInt;
    function FindSnapshotIndex(const APath: string): LongInt;
    function GetFileSnapshot(const APath: string): TFileSnapshot;
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
  SetLength(FSnapshots, 64);
  FSnapshotCount := 0;
  SetLength(FChangedFiles, 16);
  FChangedCount := 0;
end;

destructor TFileChangeDetector.Destroy;
begin
  SetLength(FSnapshots, 0);
  SetLength(FChangedFiles, 0);
  inherited Destroy;
end;

function TFileChangeDetector.FindSnapshotIndex(const APath: string): LongInt;
var
  I: LongInt;
begin
  for I := 0 to FSnapshotCount - 1 do
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
  Result := FSnapshotCount;
end;

function TFileChangeDetector.AnyChanged: Boolean;
begin
  Result := FChangedCount > 0;
end;

function TFileChangeDetector.ChangedFiles: TStringArray;
begin
  SetLength(Result, FChangedCount);
  if FChangedCount > 0 then
    Move(FChangedFiles[0], Result[0], FChangedCount * SizeOf(string));
end;

procedure TFileChangeDetector.InvalidatePrefix(const APrefix: string);
var
  I: LongInt;
begin
  for I := FSnapshotCount - 1 downto 0 do
    if Pos(APrefix, FSnapshots[I].Path) = 1 then
    begin
      FSnapshots[I] := FSnapshots[FSnapshotCount - 1];
      Dec(FSnapshotCount);
    end;
end;

procedure TFileChangeDetector.TakeSnapshot(const ARootPath: string; const AExtensions: TStringArray);
var
  SR: TSearchRec;
  Ext: string;
  FilePath: string;
  Snapshot: TFileSnapshot;
  Idx: LongInt;
  IsMatch: Boolean;
  I: LongInt;
begin
  FChangedCount := 0;

  { Scan directory for matching files }
  if FindFirst(ARootPath + '/*', faAnyFile, SR) = 0 then
  begin
    repeat
      if (SR.Name = '.') or (SR.Name = '..') then
        Continue;

      FilePath := ARootPath + '/' + SR.Name;

      { Check extension match }
      if Length(AExtensions) > 0 then
      begin
        Ext := ExtractFileExt(SR.Name);
        IsMatch := False;
        for I := 0 to High(AExtensions) do
          if SameText(Ext, AExtensions[I]) then
          begin
            IsMatch := True;
            Break;
          end;
        if not IsMatch then
          Continue;
      end;

      { Get current file info }
      Snapshot := GetFileSnapshot(FilePath);

      { Check if file was previously tracked }
      Idx := FindSnapshotIndex(FilePath);
      if Idx >= 0 then
      begin
        { Compare mtime and size }
        if (FSnapshots[Idx].ModifiedTime <> Snapshot.ModifiedTime) or
           (FSnapshots[Idx].FileSize <> Snapshot.FileSize) then
        begin
          { File changed }
          if FChangedCount >= Length(FChangedFiles) then
            SetLength(FChangedFiles, FChangedCount + 16);
          FChangedFiles[FChangedCount] := FilePath;
          Inc(FChangedCount);
          FSnapshots[Idx] := Snapshot;
        end;
      end
      else
      begin
        { New file }
        if FSnapshotCount >= Length(FSnapshots) then
          SetLength(FSnapshots, FSnapshotCount + 64);
        FSnapshots[FSnapshotCount] := Snapshot;
        Inc(FSnapshotCount);
      end;
    until FindNext(SR) <> 0;
    FindClose(SR);
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
  begin
    if FSnapshotCount >= Length(FSnapshots) then
      SetLength(FSnapshots, FSnapshotCount + 64);
    FSnapshots[FSnapshotCount] := Snapshot;
    Inc(FSnapshotCount);
  end;
end;

function TFileChangeDetector.IsFileChanged(const APath: string): Boolean;
var
  Idx: LongInt;
  Current: TFileSnapshot;
begin
  Idx := FindSnapshotIndex(APath);
  if Idx < 0 then
    Exit(True);  { Not tracked = considered changed }

  Current := GetFileSnapshot(APath);
  Result := (FSnapshots[Idx].ModifiedTime <> Current.ModifiedTime) or
            (FSnapshots[Idx].FileSize <> Current.FileSize);
end;

end.
