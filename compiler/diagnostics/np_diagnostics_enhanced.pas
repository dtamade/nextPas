{**
 * np_diagnostics_enhanced.pas — Enhanced Diagnostic Helpers
 *
 * 提供 rustc 风格的诊断增强：
 *   1. 错误代码体系 (E0001-E9999)
 *   2. 修复建议生成 (did you mean?)
 *   3. 编辑距离计算
 *}

unit np_diagnostics_enhanced;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  np_diagnostics_sink,
  np_base_types;

{ === 错误代码体系 === }

const
  { 语法错误 (E0001-E0099) }
  EC_SYNTAX_UNEXPECTED_TOKEN     = 'E0001';
  EC_SYNTAX_UNCLOSED_STRING      = 'E0002';
  EC_SYNTAX_MISSING_BEGIN        = 'E0003';
  EC_SYNTAX_MISSING_SEMICOLON    = 'E0004';

  { 语义错误 — 声明 (E0100-E0199) }
  EC_SEMA_UNDECLARED_IDENTIFIER  = 'E0101';
  EC_SEMA_DUPLICATE_DECLARATION  = 'E0102';
  EC_SEMA_TYPE_REDECLARATION     = 'E0103';
  EC_SEMA_UNKNOWN_TYPE           = 'E0104';

  { 语义错误 — 类型 (E0200-E0299) }
  EC_SEMA_TYPE_MISMATCH          = 'E0201';
  EC_SEMA_TYPE_MISMATCH_ASSIGN   = 'E0202';
  EC_SEMA_TYPE_MISMATCH_PARAM    = 'E0203';
  EC_SEMA_INCOMPATIBLE_RETURN    = 'E0204';

  { 语义错误 — 调用 (E0300-E0399) }
  EC_SEMA_WRONG_ARGUMENT_COUNT   = 'E0301';
  EC_SEMA_UNKNOWN_CALLABLE       = 'E0302';
  EC_SEMA_METHOD_NOT_FOUND       = 'E0303';
  EC_SEMA_AMBIGUOUS_OVERLOAD     = 'E0304';

  { 语义错误 — 控制流 (E0400-E0499) }
  EC_SEMA_BREAK_OUTSIDE_LOOP     = 'E0401';
  EC_SEMA_CONTINUE_OUTSIDE_LOOP  = 'E0402';
  EC_SEMA_RESULT_IN_PROCEDURE    = 'E0403';

  { 语义错误 — 继承/接口 (E0500-E0599) }
  EC_SEMA_CIRCULAR_INHERITANCE   = 'E0501';
  EC_SEMA_INVALID_OVERRIDE       = 'E0502';
  EC_SEMA_MISSING_INTERFACE_METHOD = 'E0503';
  EC_SEMA_ABSTRACT_INSTANTIATE   = 'E0504';

  { 后端错误 (E9000-E9999) }
  EC_BACKEND_CODEGEN_FAILED      = 'E9001';
  EC_BACKEND_LINK_FAILED         = 'E9002';
  EC_TOOLCHAIN_HOST_COMPILER     = 'E9101';

{ === 修复建议生成 === }

{**
 * ComputeEditDistance — Levenshtein 编辑距离
 *
 * 用于 "did you mean?" 建议。
 *}
function ComputeEditDistance(const A, B: string; AMaxDistance: LongInt = High(LongInt)): LongInt;

{**
 * FindClosestMatch — 在候选列表中找编辑距离最近的匹配
 *
 * @param ATarget  目标标识符
 * @param ACandidates  候选列表
 * @param AMaxDistance  最大编辑距离阈值（超过则不返回）
 * @returns 最佳匹配，无匹配时返回空字符串
 *}
function FindClosestMatch(
  const ATarget: string;
  const ACandidates: array of string;
  AMaxDistance: LongInt
): string;

{**
 * SuggestDidYouMean — 生成 "did you mean?" 修复建议
 *
 * @param ATarget  拼错的标识符
 * @param ACandidates  可能的正确标识符列表
 * @param AMaxDistance  最大编辑距离（默认 3）
 * @returns 修复建议描述文本
 *}
function SuggestDidYouMean(
  const ATarget: string;
  const ACandidates: array of string;
  AMaxDistance: LongInt
): string;

{**
 * EmitErrorWithFix — 发射带修复建议的错误
 *}
procedure EmitErrorWithFix(
  var ASink: TDiagnosticsSink;
  const ACode: string;
  const APhase: string;
  const AFileId: LongInt;
  const AByteOffset: LongInt;
  const AMessage: string;
  const AFixDescription: string;
  const AReplacementText: string
);

implementation

function ComputeEditDistance(const A, B: string; AMaxDistance: LongInt = High(LongInt)): LongInt;
var
  I, J, Cost, RowMin: LongInt;
  Prev, Curr, Tmp: array of LongInt;
  LenA, LenB: LongInt;
  CA, CB: Char;
begin
  LenA := Length(A);
  LenB := Length(B);

  if LenA = 0 then
    Exit(LenB);
  if LenB = 0 then
    Exit(LenA);

  if (AMaxDistance <> High(LongInt)) and (Abs(LenA - LenB) > AMaxDistance) then
    Exit(AMaxDistance + 1);

  SetLength(Prev, LenB + 1);
  SetLength(Curr, LenB + 1);

  for J := 0 to LenB do
    Prev[J] := J;

  for I := 1 to LenA do
  begin
    Curr[0] := I;
    RowMin := Curr[0];
    CA := UpCase(A[I]);
    for J := 1 to LenB do
    begin
      CB := UpCase(B[J]);
      if CA = CB then
        Cost := 0
      else
        Cost := 1;

      Curr[J] := Prev[J] + 1;
      if Curr[J-1] + 1 < Curr[J] then
        Curr[J] := Curr[J-1] + 1;
      if Prev[J-1] + Cost < Curr[J] then
        Curr[J] := Prev[J-1] + Cost;

      if Curr[J] < RowMin then
        RowMin := Curr[J];
    end;
    if (AMaxDistance <> High(LongInt)) and (RowMin > AMaxDistance) then
      Exit(AMaxDistance + 1);
    Tmp := Prev;
    Prev := Curr;
    Curr := Tmp;
  end;

  Result := Prev[LenB];
  if (AMaxDistance <> High(LongInt)) and (Result > AMaxDistance) then
    Result := AMaxDistance + 1;
end;

function FindClosestMatch(
  const ATarget: string;
  const ACandidates: array of string;
  AMaxDistance: LongInt
): string;
var
  I, Dist, BestDist: LongInt;
begin
  Result := '';
  BestDist := AMaxDistance + 1;

  for I := 0 to High(ACandidates) do
  begin
    if BestDist = 0 then
      Break;
    Dist := ComputeEditDistance(ATarget, ACandidates[I], BestDist - 1);
    if Dist < BestDist then
    begin
      BestDist := Dist;
      Result := ACandidates[I];
    end;
  end;

  if BestDist > AMaxDistance then
    Result := '';
end;

function SuggestDidYouMean(
  const ATarget: string;
  const ACandidates: array of string;
  AMaxDistance: LongInt
): string;
var
  Closest: string;
begin
  Closest := FindClosestMatch(ATarget, ACandidates, AMaxDistance);
  if Closest <> '' then
    Result := 'help: did you mean ''' + Closest + '''?'
  else
    Result := '';
end;

procedure EmitErrorWithFix(
  var ASink: TDiagnosticsSink;
  const ACode: string;
  const APhase: string;
  const AFileId: LongInt;
  const AByteOffset: LongInt;
  const AMessage: string;
  const AFixDescription: string;
  const AReplacementText: string
);
var
  Fix: TSuggestedFix;
  Fixes: TSuggestedFixVec;
  Payload: TDiagnosticPayload;
  Span: TCoreSourceSpan;
begin
  Payload := Default(TDiagnosticPayload);
  Payload.Kind := dpkNone;
  Span := BuildCoreSourceSpan(AFileId, AByteOffset, ASink.ResolveByteCount(AFileId, AByteOffset));

  ASink.EmitErrorWithPayload(ACode, APhase, Span, AMessage, Payload);

  if (AFixDescription <> '') and (AReplacementText <> '') then
  begin
    Fix.Description := AFixDescription;
    Fix.ReplacementSpan := Span;
    Fix.ReplacementText := AReplacementText;
    Fixes := TSuggestedFixVec.Create;
    Fixes.Push(Fix);
    ASink.AdoptSuggestedFixesOnLast(Fixes);
  end;
end;

end.
