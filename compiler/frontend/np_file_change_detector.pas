{**
 * np_file_change_detector.pas — File Change Detector
 *
 * 文件变更检测接口。使用快照机制追踪文件变更。
 * 当前为基础实现，增量精度待 AL4 完善。
 *}

unit np_file_change_detector;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.text.strings;

type
  TFileChangeDetector = class
  private
    FSnapshots: array of record
      RootPath: string;
      Extensions: TStringArray;
    end;
    FChangedFiles: TStringArray;
  public
    constructor Create;
    destructor Destroy; override;
    function SnapshotCount: LongInt;
    function AnyChanged: Boolean;
    function ChangedFiles: TStringArray;
    procedure InvalidatePrefix(const APrefix: string);
    procedure TakeSnapshot(const ARootPath: string; const AExtensions: TStringArray);
  end;

implementation

constructor TFileChangeDetector.Create;
begin
  inherited Create;
  SetLength(FSnapshots, 0);
  SetLength(FChangedFiles, 0);
end;

destructor TFileChangeDetector.Destroy;
begin
  SetLength(FSnapshots, 0);
  SetLength(FChangedFiles, 0);
  inherited Destroy;
end;

function TFileChangeDetector.SnapshotCount: LongInt;
begin
  Result := Length(FSnapshots);
end;

function TFileChangeDetector.AnyChanged: Boolean;
begin
  Result := Length(FChangedFiles) > 0;
end;

function TFileChangeDetector.ChangedFiles: TStringArray;
begin
  Result := FChangedFiles;
end;

procedure TFileChangeDetector.InvalidatePrefix(const APrefix: string);
begin
  { Stub: no-op — full implementation in AL4 }
end;

procedure TFileChangeDetector.TakeSnapshot(const ARootPath: string; const AExtensions: TStringArray);
var
  Idx: LongInt;
begin
  Idx := Length(FSnapshots);
  SetLength(FSnapshots, Idx + 1);
  FSnapshots[Idx].RootPath := ARootPath;
  FSnapshots[Idx].Extensions := AExtensions;
  SetLength(FChangedFiles, 0);
end;

end.
