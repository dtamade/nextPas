unit np_green_tree;

{$mode objfpc}{$H+}
{$UNITPATH .}
{$UNITPATH ../diagnostics}
{$UNITPATH ../frontend}

interface

uses
  np_diagnostics_sink, np_lexer, np_source_database;

type
  TForeignProcedureDecl = record
    ProcedureName: string;
    CallingConvention: string;
    LibraryId: string;
    ExternalSymbolName: string;
    HasExplicitSymbolName: Boolean;
    ByteOffset: LongInt;
  end;

  TGreenRootKind = (
    grkUnknown,
    grkProgram,
    grkUnit,
    grkLibrary,
    grkPackage
  );

  TGreenTree = class
  private
    FRootKind: TGreenRootKind;
    FDeclaredName: string;
    FNodeCount: LongInt;
    FIsValid: Boolean;
    FInterfaceUses: array of string;
    FImplementationUses: array of string;
    FForeignProcedureDecls: array of TForeignProcedureDecl;
    procedure AppendInterfaceUse(const AUseName: string);
    procedure AppendImplementationUse(const AUseName: string);
    procedure AppendForeignProcedureDecl(
      const AForeignProcedureDecl: TForeignProcedureDecl
    );
  public
    constructor Create;
    function RootKindName: string;
    function InterfaceUseCount: LongInt;
    function InterfaceUseAt(const AIndex: LongInt): string;
    function ImplementationUseCount: LongInt;
    function ImplementationUseAt(const AIndex: LongInt): string;
    function ForeignProcedureDeclCount: LongInt;
    function ForeignProcedureDeclAt(
      const AIndex: LongInt
    ): TForeignProcedureDecl;
    property RootKind: TGreenRootKind read FRootKind;
    property DeclaredName: string read FDeclaredName;
    property NodeCount: LongInt read FNodeCount;
    property IsValid: Boolean read FIsValid;
  end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;

implementation

uses
  SysUtils;

type
  TUseSectionKind = (
    uskInterface,
    uskImplementation
  );

function DecodePascalStringLiteral(const ALexeme: string): string;
var
  Index: SizeInt;
begin
  if (Length(ALexeme) < 2) or (ALexeme[1] <> '''') or
    (ALexeme[Length(ALexeme)] <> '''') then
    Exit(ALexeme);

  Result := '';
  Index := 2;
  while Index < Length(ALexeme) do
  begin
    if (ALexeme[Index] = '''') and (Index + 1 < Length(ALexeme)) and
      (ALexeme[Index + 1] = '''') then
    begin
      Result := Result + '''';
      Inc(Index, 2);
      Continue;
    end;

    Result := Result + ALexeme[Index];
    Inc(Index);
  end;
end;

function RootKindFromToken(const AKind: TTokenKind): TGreenRootKind;
begin
  case AKind of
    tkProgramKeyword:
      Result := grkProgram;
    tkUnitKeyword:
      Result := grkUnit;
    tkLibraryKeyword:
      Result := grkLibrary;
    tkPackageKeyword:
      Result := grkPackage;
  else
    Result := grkUnknown;
  end;
end;

function RootKeywordLabel(const AKind: TGreenRootKind): string;
begin
  case AKind of
    grkProgram:
      Result := 'program';
    grkUnit:
      Result := 'unit';
    grkLibrary:
      Result := 'library';
    grkPackage:
      Result := 'package';
  else
    Result := 'unknown';
  end;
end;

function TokenLabel(const AToken: TToken): string;
begin
  if AToken.Kind = tkEOF then
    Exit('end-of-file');

  if AToken.Lexeme <> '' then
    Exit(UpperCase(AToken.Lexeme));

  Result := UpperCase(TokenKindName(AToken.Kind));
end;

function BuildExpectedButFoundMessage(
  const AExpected: string;
  const AFoundToken: TToken
): string;
var
  FoundLabel: string;
begin
  FoundLabel := TokenLabel(AFoundToken);
  if FoundLabel = 'end-of-file' then
    Exit('Syntax error, "' + AExpected + '" expected but end-of-file found');

  Result := 'Syntax error, "' + AExpected + '" expected but "' + FoundLabel + '" found';
end;

procedure EmitSyntaxError(
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AToken: TToken;
  const AExpected: string
);
begin
  ADiagnostics.EmitError(
    'parser.syntax-error',
    'syntax',
    ARootFileId,
    AToken.ByteOffset,
    BuildExpectedButFoundMessage(AExpected, AToken)
  );
end;

procedure AdvanceCursor(var ACursor: LongInt);
begin
  Inc(ACursor);
end;

function CurrentToken(const ALexer: TLexerResult; const ACursor: LongInt): TToken;
begin
  Result := ALexer.TokenAt(ACursor);
end;

function MatchToken(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const AExpected: TTokenKind;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId;
  const AExpectedLabel: string
): Boolean;
begin
  Result := CurrentToken(ALexer, ACursor).Kind = AExpected;
  if not Result then
  begin
    EmitSyntaxError(
      ADiagnostics,
      ARootFileId,
      CurrentToken(ALexer, ACursor),
      AExpectedLabel
    );
    Exit;
  end;

  AdvanceCursor(ACursor);
end;

function ParseUsesClause(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const ASectionKind: TUseSectionKind;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
var
  UseName: string;
begin
  Result := True;
  if CurrentToken(ALexer, ACursor).Kind <> tkUsesKeyword then
    Exit;

  Inc(ATree.FNodeCount);
  AdvanceCursor(ACursor);

  while True do
  begin
    if CurrentToken(ALexer, ACursor).Kind <> tkIdentifier then
    begin
      EmitSyntaxError(
        ADiagnostics,
        ARootFileId,
        CurrentToken(ALexer, ACursor),
        'identifier'
      );
      Exit(False);
    end;

    UseName := CurrentToken(ALexer, ACursor).Lexeme;
    if ASectionKind = uskInterface then
      ATree.AppendInterfaceUse(UseName)
    else
      ATree.AppendImplementationUse(UseName);

    Inc(ATree.FNodeCount);
    AdvanceCursor(ACursor);

    if CurrentToken(ALexer, ACursor).Kind <> tkComma then
      Break;

    Inc(ATree.FNodeCount);
    AdvanceCursor(ACursor);
  end;

  if not MatchToken(
    ALexer,
    ACursor,
    tkSemicolon,
    ADiagnostics,
    ARootFileId,
    ';'
  ) then
    Exit(False);

  Inc(ATree.FNodeCount);
end;

function FindTokenKind(
  const ALexer: TLexerResult;
  const AStartIndex: LongInt;
  const AExpected: TTokenKind
): LongInt;
var
  Index: LongInt;
begin
  for Index := AStartIndex to ALexer.TokenCount - 1 do
    if ALexer.TokenAt(Index).Kind = AExpected then
      Exit(Index);

  Result := -1;
end;

function TryParseForeignProcedureDecl(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree
): Boolean;
var
  ForeignProcedureDecl: TForeignProcedureDecl;
  LookaheadCursor: LongInt;
begin
  Result := False;
  if CurrentToken(ALexer, ACursor).Kind <> tkProcedureKeyword then
    Exit;

  LookaheadCursor := ACursor;
  ForeignProcedureDecl.ProcedureName := '';
  ForeignProcedureDecl.CallingConvention := '';
  ForeignProcedureDecl.LibraryId := '';
  ForeignProcedureDecl.ExternalSymbolName := '';
  ForeignProcedureDecl.HasExplicitSymbolName := False;
  ForeignProcedureDecl.ByteOffset :=
    CurrentToken(ALexer, LookaheadCursor).ByteOffset;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkIdentifier then
    Exit;
  ForeignProcedureDecl.ProcedureName :=
    CurrentToken(ALexer, LookaheadCursor).Lexeme;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkCdeclKeyword then
    Exit;
  ForeignProcedureDecl.CallingConvention := 'cdecl';
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkExternalKeyword then
    Exit;
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkStringLiteral then
    Exit;
  ForeignProcedureDecl.LibraryId := DecodePascalStringLiteral(
    CurrentToken(ALexer, LookaheadCursor).Lexeme
  );
  AdvanceCursor(LookaheadCursor);

  if CurrentToken(ALexer, LookaheadCursor).Kind = tkNameKeyword then
  begin
    AdvanceCursor(LookaheadCursor);
    if CurrentToken(ALexer, LookaheadCursor).Kind <> tkStringLiteral then
      Exit;
    ForeignProcedureDecl.ExternalSymbolName := DecodePascalStringLiteral(
      CurrentToken(ALexer, LookaheadCursor).Lexeme
    );
    ForeignProcedureDecl.HasExplicitSymbolName := True;
    AdvanceCursor(LookaheadCursor);
  end;

  if CurrentToken(ALexer, LookaheadCursor).Kind <> tkSemicolon then
    Exit;
  AdvanceCursor(LookaheadCursor);

  ATree.AppendForeignProcedureDecl(ForeignProcedureDecl);
  Inc(ATree.FNodeCount);
  ACursor := LookaheadCursor;
  Result := True;
end;

function ParseProgramLikeRoot(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
begin
  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskInterface,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  while (CurrentToken(ALexer, ACursor).Kind <> tkBeginKeyword) and
    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
  begin
    if TryParseForeignProcedureDecl(ALexer, ACursor, ATree) then
      Continue;
    AdvanceCursor(ACursor);
  end;

  Result := MatchToken(
    ALexer,
    ACursor,
    tkBeginKeyword,
    ADiagnostics,
    ARootFileId,
    'BEGIN'
  );
  if not Result then
    Exit;

  Inc(ATree.FNodeCount);
end;

function ParseUnitRoot(
  const ALexer: TLexerResult;
  var ACursor: LongInt;
  const ATree: TGreenTree;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): Boolean;
begin
  Result := MatchToken(
    ALexer,
    ACursor,
    tkInterfaceKeyword,
    ADiagnostics,
    ARootFileId,
    'INTERFACE'
  );
  if not Result then
    Exit;

  Inc(ATree.FNodeCount);
  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskInterface,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  while (CurrentToken(ALexer, ACursor).Kind <> tkImplementationKeyword) and
    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
  begin
    if TryParseForeignProcedureDecl(ALexer, ACursor, ATree) then
      Continue;
    AdvanceCursor(ACursor);
  end;

  Result := MatchToken(
    ALexer,
    ACursor,
    tkImplementationKeyword,
    ADiagnostics,
    ARootFileId,
    'IMPLEMENTATION'
  );
  if not Result then
    Exit;

  Inc(ATree.FNodeCount);
  Result := ParseUsesClause(
    ALexer,
    ACursor,
    ATree,
    uskImplementation,
    ADiagnostics,
    ARootFileId
  );
  if not Result then
    Exit;

  while (CurrentToken(ALexer, ACursor).Kind <> tkEndKeyword) and
    (CurrentToken(ALexer, ACursor).Kind <> tkEOF) do
  begin
    if TryParseForeignProcedureDecl(ALexer, ACursor, ATree) then
      Continue;
    AdvanceCursor(ACursor);
  end;

  Result := MatchToken(
    ALexer,
    ACursor,
    tkEndKeyword,
    ADiagnostics,
    ARootFileId,
    'END'
  );
  if not Result then
    Exit;

  Inc(ATree.FNodeCount);
end;

constructor TGreenTree.Create;
begin
  inherited Create;
  FRootKind := grkUnknown;
  FDeclaredName := '';
  FNodeCount := 0;
  FIsValid := False;
  SetLength(FInterfaceUses, 0);
  SetLength(FImplementationUses, 0);
  SetLength(FForeignProcedureDecls, 0);
end;

procedure TGreenTree.AppendInterfaceUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FInterfaceUses);
  SetLength(FInterfaceUses, NextIndex + 1);
  FInterfaceUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendImplementationUse(const AUseName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FImplementationUses);
  SetLength(FImplementationUses, NextIndex + 1);
  FImplementationUses[NextIndex] := AUseName;
end;

procedure TGreenTree.AppendForeignProcedureDecl(
  const AForeignProcedureDecl: TForeignProcedureDecl
);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FForeignProcedureDecls);
  SetLength(FForeignProcedureDecls, NextIndex + 1);
  FForeignProcedureDecls[NextIndex] := AForeignProcedureDecl;
end;

function TGreenTree.RootKindName: string;
begin
  Result := RootKeywordLabel(FRootKind);
end;

function TGreenTree.InterfaceUseCount: LongInt;
begin
  Result := Length(FInterfaceUses);
end;

function TGreenTree.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FInterfaceUses)) then
    Exit('');

  Result := FInterfaceUses[AIndex];
end;

function TGreenTree.ImplementationUseCount: LongInt;
begin
  Result := Length(FImplementationUses);
end;

function TGreenTree.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if (AIndex < 0) or (AIndex >= Length(FImplementationUses)) then
    Exit('');

  Result := FImplementationUses[AIndex];
end;

function TGreenTree.ForeignProcedureDeclCount: LongInt;
begin
  Result := Length(FForeignProcedureDecls);
end;

function TGreenTree.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if (AIndex < 0) or (AIndex >= Length(FForeignProcedureDecls)) then
  begin
    Result.ProcedureName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.HasExplicitSymbolName := False;
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FForeignProcedureDecls[AIndex];
end;

function ParseGreenTree(
  const ALexer: TLexerResult;
  const ADiagnostics: TDiagnosticsSink;
  const ARootFileId: TSourceFileId
): TGreenTree;
var
  Cursor: LongInt;
  Current: TToken;
begin
  Result := TGreenTree.Create;
  Cursor := 0;
  Current := CurrentToken(ALexer, Cursor);

  Result.FRootKind := RootKindFromToken(Current.Kind);
  if Result.FRootKind = grkUnknown then
  begin
    EmitSyntaxError(
      ADiagnostics,
      ARootFileId,
      Current,
      'program|unit|library|package'
    );
    Exit;
  end;

  Result.FNodeCount := 1;
  AdvanceCursor(Cursor);
  Current := CurrentToken(ALexer, Cursor);

  if Current.Kind <> tkIdentifier then
  begin
    EmitSyntaxError(ADiagnostics, ARootFileId, Current, 'identifier');
    Exit;
  end;

  Result.FDeclaredName := Current.Lexeme;
  Inc(Result.FNodeCount);
  AdvanceCursor(Cursor);

  if not MatchToken(ALexer, Cursor, tkSemicolon, ADiagnostics, ARootFileId, ';') then
    Exit;
  Inc(Result.FNodeCount);

  case Result.FRootKind of
    grkProgram, grkLibrary, grkPackage:
      begin
        if not ParseProgramLikeRoot(
          ALexer,
          Cursor,
          Result,
          ADiagnostics,
          ARootFileId
        ) then
          Exit;
      end;
    grkUnit:
      begin
        if not ParseUnitRoot(
          ALexer,
          Cursor,
          Result,
          ADiagnostics,
          ARootFileId
        ) then
          Exit;
      end;
    grkUnknown:
      Exit;
  end;

  Result.FIsValid := not ADiagnostics.HasErrors;
end;

end.
