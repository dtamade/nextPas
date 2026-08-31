{**
 * nextpas.compiler.diagnostics.json.pas — JSON Diagnostic Output
 *
 * 对标 rustc --error-format=json。
 *
 * 当前版本使用 TDiagnosticsSink 的公开 API 输出诊断摘要。
 * 完整 JSONL 格式需要 TDiagnosticsSink 暴露 DiagnosticCount/DiagnosticAt。
 *}

unit nextpas.compiler.diagnostics.json;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.compiler.diagnostics.sink;

type
  TDiagnosticsJson = class
  private
    FSink: TDiagnosticsSink;
  public
    constructor Create(const ASink: TDiagnosticsSink);
    function Summary: string;
    function HasErrors: Boolean;
    function HasWarnings: Boolean;
  end;

implementation

constructor TDiagnosticsJson.Create(const ASink: TDiagnosticsSink);
begin
  inherited Create;
  FSink := ASink;
end;

function TDiagnosticsJson.Summary: string;
begin
  Result := Format(
    '{"errors":%d,"warnings":%d,"total":%d}',
    [FSink.ErrorCount, FSink.WarningCount, FSink.TotalCount]
  );
end;

function TDiagnosticsJson.HasErrors: Boolean;
begin
  Result := FSink.ErrorCount > 0;
end;

function TDiagnosticsJson.HasWarnings: Boolean;
begin
  Result := FSink.WarningCount > 0;
end;

end.