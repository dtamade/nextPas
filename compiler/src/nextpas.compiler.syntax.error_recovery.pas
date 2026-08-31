{**
 * nextpas.compiler.syntax.error_recovery.pas — Parser Error Recovery
 *
 * 对标 rustc_parse error recovery。
 *
 * 策略：
 *   1. 记录错误诊断
 *   2. 跳过 token 直到同步点（; end begin until except finally）
 *   3. 限制最多 100 个错误后停止
 *   4. 每个错误产生一条诊断消息
 *
 * 使用方式：
 *   Recovery := TErrorRecovery.Create(ADiagnostics, ARootFileId, ALexer);
 *   if not MatchToken(...) then
 *     Recovery.SkipToSync(ACursor);
 *}

unit nextpas.compiler.syntax.error_recovery;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.syntax.lexer, nextpas.compiler.diagnostics.sink, np_base_types;

type
  {**
   * TErrorRecovery — 错误恢复器
   *
   * 维护错误计数和同步点集合。
   *}
  TErrorRecovery = class
  private
    FDiagnostics: TDiagnosticsSink;
    FRootFileId: TSourceFileId;
    FLexer: TLexerResult;
    FErrorCount: LongInt;
    FMaxErrors: LongInt;
    function IsSyncToken(const AToken: TToken): Boolean;
  public
    constructor Create(
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ALexer: TLexerResult
    );
    constructor CreateWithLimit(
      const ADiagnostics: TDiagnosticsSink;
      const ARootFileId: TSourceFileId;
      const ALexer: TLexerResult;
      AMaxErrors: LongInt
    );

    { 记录一个错误并增加计数。返回 False 表示已达错误上限 }
    function RecordError(const AToken: TToken;
      const AMessage: string): Boolean;

    { 跳过 token 直到同步点或 token 流结束 }
    procedure SkipToSync(var ACursor: LongInt);

    { 跳过到指定 token kind }
    procedure SkipTo(var ACursor: LongInt; const ATarget: TTokenKind);

    { 错误统计 }
    function ErrorCount: LongInt;
    function HasReachedLimit: Boolean;
    function CanContinue: Boolean;
  end;

implementation

function TErrorRecovery.IsSyncToken(const AToken: TToken): Boolean;
begin
  Result := AToken.Kind in [
    tkSemicolon,
    tkEndKeyword,
    tkBeginKeyword,
    tkUntilKeyword,
    tkExceptKeyword,
    tkFinallyKeyword,
    tkImplementationKeyword,
    tkInterfaceKeyword,
    tkInitializationKeyword,
    tkFinalizationKeyword,
    tkProcedureKeyword,
    tkFunctionKeyword,
    tkConstructorKeyword,
    tkDestructorKeyword,
    tkTypeKeyword,
    tkVarKeyword,
    tkConstKeyword,
    tkUsesKeyword,
    tkUnitKeyword,
    tkProgramKeyword,
    tkLibraryKeyword,
    tkPackageKeyword
  ];
end;

constructor TErrorRecovery.Create(
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ALexer: TLexerResult
);
begin
  CreateWithLimit(ADiagnostics, ARootFileId, ALexer, 100);
end;

constructor TErrorRecovery.CreateWithLimit(
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const ALexer: TLexerResult;
  AMaxErrors: LongInt
);
begin
  inherited Create;
  FDiagnostics := ADiagnostics;
  FRootFileId := ARootFileId;
  FLexer := ALexer;
  FErrorCount := 0;
  FMaxErrors := AMaxErrors;
  if FMaxErrors < 1 then
    FMaxErrors := 100;
end;

function TErrorRecovery.RecordError(const AToken: TToken;
  const AMessage: string): Boolean;
begin
  if FErrorCount >= FMaxErrors then
    Exit(False);

  FDiagnostics.EmitError(
    FRootFileId,
    AToken.Line,
    AToken.Column,
    AToken.ByteOffset,
    Length(AToken.Lexeme),
    AMessage
  );

  Inc(FErrorCount);
  Result := True;
end;

procedure TErrorRecovery.SkipToSync(var ACursor: LongInt);
begin
  while ACursor < FLexer.TokenCount do
  begin
    if IsSyncToken(FLexer.Tokens[ACursor]) then
      Break;
    Inc(ACursor);
  end;
end;

procedure TErrorRecovery.SkipTo(var ACursor: LongInt;
  const ATarget: TTokenKind);
begin
  while ACursor < FLexer.TokenCount do
  begin
    if FLexer.Tokens[ACursor].Kind = ATarget then
    begin
      Inc(ACursor);  { Consume the target token }
      Exit;
    end;
    if IsSyncToken(FLexer.Tokens[ACursor]) then
      Break;  { Don't skip past sync points }
    Inc(ACursor);
  end;
end;

function TErrorRecovery.ErrorCount: LongInt;
begin
  Result := FErrorCount;
end;

function TErrorRecovery.HasReachedLimit: Boolean;
begin
  Result := FErrorCount >= FMaxErrors;
end;

function TErrorRecovery.CanContinue: Boolean;
begin
  Result := FErrorCount < FMaxErrors;
end;

end.
