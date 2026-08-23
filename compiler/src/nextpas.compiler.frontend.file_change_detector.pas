{**
 * nextpas.compiler.frontend.file_change_detector.pas — File Change Detector
 *
 * 文件变更检测接口。使用 mtime 机制追踪文件变更。
 * 支持目录扫描和文件级变更检测。
 *
 * 对标 Go 的 build cache mtime 检查
 *}

unit nextpas.compiler.frontend.file_change_detector;

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
  FChangedFiles.Clear;

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
          FChangedFiles.Push(FilePath);
          FSnapshots[Idx] := Snapshot;
        end;
      end
      else
        FSnapshots.Push(Snapshot);
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
    FSnapshots.Push(Snapshot);
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
