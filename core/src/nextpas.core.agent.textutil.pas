{**
 * nextpas.core.agent.textutil - UTF-8 安全截断单一真源。
 *
 * 职责：为 tools / provider.common / base 提供同一 Utf8SafeCutLen/Truncate
 * 实现，消除 F-H01 孪生分歧（工具侧多吞1字节、common 残留非法 UTF-8）。
 * 纯函数无状态，可被多单元复用，性能零回归（inline 透传）。
 *}

unit nextpas.core.agent.textutil;

{$I nextpas.core.settings.inc}

interface

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
function AgentEstimateTokens(const S: string): Int64; inline;

implementation

function AgentUtf8SafeCutLen(const S: string; AMaxBytes: Integer): Integer; inline;
var
  LCut: Integer;
  B: Byte;
  LExpected: Integer;
begin
  if AMaxBytes <= 0 then
    Exit(0);
  if Length(S) <= AMaxBytes then
    Exit(Length(S));
  LCut := AMaxBytes;
  while (LCut > 0) and ((Byte(S[LCut]) and $C0) = $80) do
    Dec(LCut);
  if LCut <= 0 then
    Exit(0);
  B := Byte(S[LCut]);
  if (B and $80) = 0 then
    LExpected := 1
  else if (B and $E0) = $C0 then
    LExpected := 2
  else if (B and $F0) = $E0 then
    LExpected := 3
  else if (B and $F8) = $F0 then
    LExpected := 4
  else
    LExpected := 1;
  if LCut + LExpected - 1 > AMaxBytes then
    Result := LCut - 1
  else
    Result := AMaxBytes;
  if Result < 0 then
    Result := 0;
  if Result > Length(S) then
    Result := Length(S);
end;

function AgentUtf8SafeTruncate(const S: string; AMaxBytes: Integer): string; inline;
var
  LLen: Integer;
begin
  LLen := AgentUtf8SafeCutLen(S, AMaxBytes);
  if LLen = 0 then
    Exit('');
  if LLen = Length(S) then
    Exit(S);
  Result := System.Copy(S, 1, LLen);
end;

function AgentEstimateTokens(const S: string): Int64; inline;
begin
  Result := (Int64(Length(S)) + 3) div 4;
end;

end.