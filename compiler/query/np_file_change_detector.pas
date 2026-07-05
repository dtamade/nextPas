{**
 * np_file_change_detector.pas
 *
 * 文件变化检测器 — 增量编译的基础
 *
 * 策略：
 *   1. 记录编译时每个源文件的 mtime（FileAge）
 *   2. 下次编译时比较 mtime
 *   3. 变化检测 → 查询失效传播
 *
 * 对标：rustc file tracking (SourceMap + DepGraph)
 *}

unit np_file_change_detector;

{$mode objfpc}{$H+}

interface

uses
  SysUtils;

type
  {**
   * TFileFingerprint — 文件指纹
   *
   * 包含足够信息判断文件是否变化。
   * 阶段 2.2 使用 mtime + size；后续可扩展为 hash。
   *}
  TFileFingerprint = record
    Path: string;
    MTime: Int64;    { FileAge 返回值，-1 = 文件不存在 }
    Size: Int64;     { 文件大小，用于额外验证 }
    Exists: Boolean;
  end;

  {**
   * TFileChangeDetector — 文件变化检测
   *
   * 维护源文件指纹的快照，支持：
   *   - TakeSnapshot: 记录当前文件状态
   *   - HasChanged: 比较当前状态与快照
   *   - ChangedFiles: 返回所有变化的文件列表
   *   - InvalidateAffected: 失效受影响的查询
   *}
  TFileChangeDetector = class
  private
    type
      TSnapshotEntry = record
        Fingerprint: TFileFingerprint;
        DependsOn: array of string;  { 依赖的其他文件路径 }
      end;
    var
      FSnapshots: array of TSnapshotEntry;
    function FindSnapshot(const APath: string): LongInt;
    function CaptureFingerprint(const APath: string): TFileFingerprint;
  public
    constructor Create;
    destructor Destroy; override;

    { 记录文件快照（编译成功后调用） }
    procedure TakeSnapshot(const APath: string;
      const ADependencies: array of string);

    { 检查文件是否变化 }
    function HasChanged(const APath: string): Boolean;

    { 返回所有变化的文件路径 }
    function ChangedFiles: TStringArray;

    { 检查任何快照文件是否变化 }
    function AnyChanged: Boolean;

    { 快照数量 }
    function SnapshotCount: LongInt;

    { 清空所有快照 }
    procedure Clear;
  end;

implementation

constructor TFileChangeDetector.Create;
begin
  inherited Create;
  SetLength(FSnapshots, 0);
end;

destructor TFileChangeDetector.Destroy;
begin
  SetLength(FSnapshots, 0);
  inherited Destroy;
end;

function TFileChangeDetector.FindSnapshot(const APath: string): LongInt;
var
  I: LongInt;
begin
  for I := 0 to Length(FSnapshots) - 1 do
    if SameText(FSnapshots[I].Fingerprint.Path, APath) then
      Exit(I);
  Result := -1;
end;

function TFileChangeDetector.CaptureFingerprint(
  const APath: string): TFileFingerprint;
var
  F: file of byte;
begin
  Result.Path := APath;
  Result.MTime := FileAge(APath);
  Result.Exists := Result.MTime <> -1;
  if Result.Exists then
  begin
    AssignFile(F, APath);
    Reset(F);
    Result.Size := FileSize(F);
    CloseFile(F);
  end
  else
    Result.Size := 0;
end;

procedure TFileChangeDetector.TakeSnapshot(const APath: string;
  const ADependencies: array of string);
var
  Idx: LongInt;
  I: LongInt;
begin
  Idx := FindSnapshot(APath);
  if Idx < 0 then
  begin
    Idx := Length(FSnapshots);
    SetLength(FSnapshots, Idx + 1);
  end;

  FSnapshots[Idx].Fingerprint := CaptureFingerprint(APath);
  SetLength(FSnapshots[Idx].DependsOn, Length(ADependencies));
  for I := 0 to Length(ADependencies) - 1 do
    FSnapshots[Idx].DependsOn[I] := ADependencies[I];
end;

function TFileChangeDetector.HasChanged(const APath: string): Boolean;
var
  Idx: LongInt;
  Current: TFileFingerprint;
begin
  Idx := FindSnapshot(APath);
  if Idx < 0 then
    Exit(True);  { 新文件，视为已变化 }

  Current := CaptureFingerprint(APath);

  { 比较 mtime 和 size }
  Result := (Current.MTime <> FSnapshots[Idx].Fingerprint.MTime)
    or (Current.Size <> FSnapshots[Idx].Fingerprint.Size)
    or (Current.Exists <> FSnapshots[Idx].Fingerprint.Exists);
end;

function TFileChangeDetector.ChangedFiles: TStringArray;
var
  I: LongInt;
  Count: LongInt;
begin
  SetLength(Result, 0);
  Count := 0;
  for I := 0 to Length(FSnapshots) - 1 do
    if HasChanged(FSnapshots[I].Fingerprint.Path) then
    begin
      Inc(Count);
      SetLength(Result, Count);
      Result[Count - 1] := FSnapshots[I].Fingerprint.Path;
    end;
end;

function TFileChangeDetector.AnyChanged: Boolean;
var
  I: LongInt;
begin
  for I := 0 to Length(FSnapshots) - 1 do
    if HasChanged(FSnapshots[I].Fingerprint.Path) then
      Exit(True);
  Result := False;
end;

function TFileChangeDetector.SnapshotCount: LongInt;
begin
  Result := Length(FSnapshots);
end;

procedure TFileChangeDetector.Clear;
begin
  SetLength(FSnapshots, 0);
end;

end.
