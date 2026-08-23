{**
 * nextpas.core.agent - AI provider 客户端与通用工具循环门面。
 *
 * 契约权威：core/docs/agent/API.md。实现与文档冲突时先改文档。
 * W0 骨架：词表经 base/errors 直接可用；provider 构造入口随 W1/W2 落位。
 *}

unit nextpas.core.agent;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.agent.base,
  nextpas.core.agent.errors;

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode; inline;
function IsRetryable(ACode: TAgentErrorCode): Boolean; inline;
function AgentErrorCodeName(ACode: TAgentErrorCode): string; inline;

implementation

function ErrorCodeForStatus(AStatus: Integer): TAgentErrorCode;
begin
  Result := nextpas.core.agent.errors.ErrorCodeForStatus(AStatus);
end;

function IsRetryable(ACode: TAgentErrorCode): Boolean;
begin
  Result := nextpas.core.agent.errors.IsRetryable(ACode);
end;

function AgentErrorCodeName(ACode: TAgentErrorCode): string;
begin
  Result := nextpas.core.agent.errors.AgentErrorCodeName(ACode);
end;

end.
