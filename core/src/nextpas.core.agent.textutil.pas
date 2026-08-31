{**
 * nextpas.core.agent.textutil - agent 文本工具薄壳。
 *
 * 职责：UTF-8 安全截断单一真源已反哺至 nextpas.core.text.utf8
 * （UTF8SafeTruncate，门面 TextUTF8SafeTruncate）；本单元仅保留
 * AgentEstimateTokens 估算与兼容转发名（AgentUtf8SafeCutLen/Truncate
 * 为公共 API 冻结名，转发到 text 域单源）。纯函数无状态。
 *}

unit nextpas.core.agent.textutil;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text;

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
function AgentEstimateTokens(const S: string): Int64; inline;

implementation

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
begin
  Result := nextpas.core.text.TextUTF8SafeCutLen(S, AMaxBytes);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
begin
  Result := nextpas.core.text.TextUTF8SafeTruncate(S, AMaxBytes);
end;

function AgentEstimateTokens(const S: string): Int64; inline;
begin
  Result := (Int64(Length(S)) + 3) div 4;
end;

end.
