unit nextpas.core.diagnostics;

{$I nextpas.core.settings.inc}

{ 轻量诊断构建器：后端 Probe 可用性多行文本的统一装配。
  不依赖 SysUtils.Format，经 nextpas.core.text.* 组合。 }

interface

uses
  nextpas.core.diagnostics.base;

type
  TDiagnosticsBuilder = record
  private
    FLines: array of string;
    function BoolStr(Av: Boolean): string; inline;
  public
    procedure Clear; inline;
    procedure Add(const AName: string; AAvailable: Boolean); overload;
    procedure Add(const AName: string; AAvailable: Boolean; const ADetail: string); overload;
    procedure AddProbe(const AProbe: TDiagProbe); inline;
    procedure AddRaw(const ALine: string);
    function Build: string;
    function Count: Integer; inline;
  end;

function DiagLine(const AName: string; AAvailable: Boolean; const ADetail: string = ''): string;

implementation

uses
  nextpas.core.text.format,
  nextpas.core.text.utils;

function TDiagnosticsBuilder.BoolStr(Av: Boolean): string;
begin
  Result := BoolToStr(Av, 'True', 'False');
end;

procedure TDiagnosticsBuilder.Clear;
begin
  SetLength(FLines, 0);
end;

procedure TDiagnosticsBuilder.Add(const AName: string; AAvailable: Boolean);
begin
  Add(AName, AAvailable, '');
end;

procedure TDiagnosticsBuilder.Add(const AName: string; AAvailable: Boolean; const ADetail: string);
var
  L: string;
begin
  if ADetail <> '' then
    L := TextFormat('%s: %s (%s)', [AName, BoolStr(AAvailable), ADetail])
  else
    L := TextFormat('%s: %s', [AName, BoolStr(AAvailable)]);
  AddRaw(L);
end;

procedure TDiagnosticsBuilder.AddProbe(const AProbe: TDiagProbe);
begin
  Add(AProbe.Name, AProbe.Available, AProbe.Detail);
end;

procedure TDiagnosticsBuilder.AddRaw(const ALine: string);
begin
  SetLength(FLines, Length(FLines)+1);
  FLines[High(FLines)] := ALine;
end;

function TDiagnosticsBuilder.Build: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(FLines) do
  begin
    if I > 0 then Result := Result + LineEnding;
    Result := Result + FLines[I];
  end;
end;

function TDiagnosticsBuilder.Count: Integer;
begin
  Result := Length(FLines);
end;

function DiagLine(const AName: string; AAvailable: Boolean; const ADetail: string): string;
var
  B: TDiagnosticsBuilder;
begin
  B.Clear;
  B.Add(AName, AAvailable, ADetail);
  Result := B.Build;
end;

end.
