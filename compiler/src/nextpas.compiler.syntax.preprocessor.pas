unit nextpas.compiler.syntax.preprocessor;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}
{$UNITPATH .}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  np_base_types, nextpas.compiler.syntax.lexer;

type
  IIncludeResolver = interface
    function ResolveInclude(const AName: string;
      const AFromFileId: TCoreId;
      out APath: string; out AContent: string): Boolean;
  end;

  TIncludePathVec = specialize TVec<string>;

  TFileIncludeResolver = class(TInterfacedObject, IIncludeResolver)
  private
    FAllocator: IAllocator;
    FSearchPaths: TIncludePathVec;
    FBaseDir: string;
  public
    { Optional AAllocator: session/phase scratch for include search-path TVec. }
    constructor Create(const ABaseDir: string; AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure AddSearchPath(const APath: string);
    function ResolveInclude(const AName: string;
      const AFromFileId: TCoreId;
      out APath: string; out AContent: string): Boolean;
  end;

  TDefineEntry = record
    Name: string;
    Value: string;
    HasValue: Boolean;
  end;

  TDefineEntryVec = specialize TVec<TDefineEntry>;

  TDefineTable = class
  private
    FAllocator: IAllocator;
    FEntries: TDefineEntryVec;
    function IndexOf(const AName: string): LongInt;
  public
    { Optional AAllocator: session/phase scratch for define entries TVec. }
    constructor Create(AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure Define(const AName: string);
    procedure DefineValue(const AName, AValue: string);
    procedure Undef(const AName: string);
    function IsDefined(const AName: string): Boolean;
    function TryGetValue(const AName: string; out AValue: string): Boolean;
    function ValueOf(const AName: string): string;
    procedure Clear;
    function Count: LongInt;
    procedure SeedFPCDefines;
  end;

  TConditionalFrame = record
    ParentActive: Boolean;
    AnyBranchTaken: Boolean;
    CurrentActive: Boolean;
    SeenElse: Boolean;
  end;

  TConditionalFrameVec = specialize TVec<TConditionalFrame>;
  TTokenVec = specialize TVec<TToken>;

  TPreprocessor = class
  private
    FDefines: TDefineTable;
    FOwnsDefines: Boolean;
    FIncludeResolver: IIncludeResolver;
    FAllocator: IAllocator;
    FStack: TConditionalFrameVec;
    FOutputTokens: TTokenVec;
    FCurrentFileId: TCoreId;
    FNextFileId: TCoreId;
    FEvalExpr: string;
    FEvalPos: LongInt;
    function IsActive: Boolean;
    procedure PushFrame(ACondition: Boolean);
    procedure HandleElse;
    procedure HandleElseIf(ACondition: Boolean);
    procedure HandleEndIf;
    procedure EmitToken(const AToken: TToken);
    function ParseDirectiveName(const ALexeme: string;
      out ADirective, AArg: string): Boolean;
    function EvalSimpleCondition(const AArg: string): Boolean;
    function EvalIfExpr(const AExpr: string): Boolean;
    procedure EvalSkipWS;
    function EvalPeekChar: Char;
    function EvalMatchStr(const S: string): Boolean;
    function EvalParseInt: Int64;
    function EvalParseIdent: string;
    function EvalAtom: Int64;
    function EvalMul: Int64;
    function EvalAdd: Int64;
    function EvalCmp: Int64;
    function EvalAnd: Int64;
    function EvalOr: Int64;
    procedure ProcessInclude(const AArg: string);
  public
    { Optional AAllocator: session/phase scratch for stack + output token TVecs. }
    constructor Create(ADefines: TDefineTable; AOwnsDefines: Boolean;
      AIncludeResolver: IIncludeResolver; AAllocator: IAllocator = nil);
    destructor Destroy; override;
    procedure Process(const ALexer: TLexerResult);
    function ToLexerResult: TLexerResult;
    function OutputTokenCount: LongInt;
    function OutputTokenAt(const AIndex: LongInt): TToken;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.core.fs.util;

{$I np_preprocessor_tables.inc}
function TPreprocessor.IsActive: Boolean;
begin
  if FStack.Count = 0 then
    Exit(True);
  Result := FStack[FStack.Count - 1].CurrentActive;
end;

procedure TPreprocessor.PushFrame(ACondition: Boolean);
var
  Frame: TConditionalFrame;
begin
  Frame.ParentActive := IsActive;
  Frame.AnyBranchTaken := Frame.ParentActive and ACondition;
  Frame.CurrentActive := Frame.ParentActive and ACondition;
  Frame.SeenElse := False;
  FStack.Push(Frame);
end;

procedure TPreprocessor.HandleElse;
var
  Frame: TConditionalFrame;
  Idx: SizeUInt;
begin
  if FStack.Count = 0 then Exit;
  Idx := FStack.Count - 1;
  Frame := FStack[Idx];
  if Frame.SeenElse then Exit;
  Frame.SeenElse := True;
  Frame.CurrentActive := Frame.ParentActive and (not Frame.AnyBranchTaken);
  FStack[Idx] := Frame;
end;

procedure TPreprocessor.HandleElseIf(ACondition: Boolean);
var
  Frame: TConditionalFrame;
  Idx: SizeUInt;
begin
  if FStack.Count = 0 then Exit;
  Idx := FStack.Count - 1;
  Frame := FStack[Idx];
  if Frame.SeenElse then Exit;
  if Frame.ParentActive and ACondition and (not Frame.AnyBranchTaken) then
  begin
    Frame.CurrentActive := True;
    Frame.AnyBranchTaken := True;
  end
  else
    Frame.CurrentActive := False;
  FStack[Idx] := Frame;
end;

procedure TPreprocessor.HandleEndIf;
begin
  if FStack.Count > 0 then
    FStack.Resize(FStack.Count - 1);
end;

procedure TPreprocessor.EmitToken(const AToken: TToken);
begin
  { Deep-copy nested trivia; source lexer retains its entry-owned vecs. }
  FOutputTokens.Push(CloneTokenWithTrivia(AToken, FAllocator));
end;

function TPreprocessor.ParseDirectiveName(const ALexeme: string;
  out ADirective, AArg: string): Boolean;
var
  Content: string;
  SpacePos: LongInt;
begin
  Result := False;
  ADirective := '';
  AArg := '';
  if Length(ALexeme) < 3 then Exit;
  if (ALexeme[1] = '{') and (ALexeme[2] = '$') then
  begin
    Content := Copy(ALexeme, 3, Length(ALexeme) - 3);
    if (Content <> '') and (Content[Length(Content)] = '}') then
      SetLength(Content, Length(Content) - 1);
  end
  else if (Length(ALexeme) >= 4) and (ALexeme[1] = '(') and
    (ALexeme[2] = '*') and (ALexeme[3] = '$') then
    Content := Copy(ALexeme, 4, Length(ALexeme) - 5)
  else
    Exit;
  Content := Trim(Content);
  if Content = '' then Exit;
  SpacePos := Pos(' ', Content);
  if SpacePos > 0 then
  begin
    ADirective := LowerCase(Copy(Content, 1, SpacePos - 1));
    AArg := Trim(Copy(Content, SpacePos + 1, Length(Content)));
  end
  else
    ADirective := LowerCase(Content);
  Result := True;
end;

{$I np_preprocessor_eval.inc}

procedure TPreprocessor.ProcessInclude(const AArg: string);
var
  IncName, Path, Content: string;
  IncLexer: TLexerResult;
  IncFileId: TCoreId;
  I: LongInt;
  Tok: TToken;
  Dir, DirArg: string;
begin
  IncName := Trim(AArg);
  if (Length(IncName) >= 2) and (IncName[1] = '''') and
    (IncName[Length(IncName)] = '''') then
    IncName := Copy(IncName, 2, Length(IncName) - 2);
  if IncName = '' then Exit;
  if FIncludeResolver = nil then Exit;
  if not FIncludeResolver.ResolveInclude(IncName, FCurrentFileId, Path, Content) then
    Exit;
  Inc(FNextFileId);
  IncFileId := FNextFileId;
  IncLexer := TLexerResult.Create(Content, nil, IncFileId);
  for I := 0 to IncLexer.TokenCount - 1 do
  begin
    Tok := IncLexer.TokenAt(I);
    if Tok.Kind = tkEOF then
      Continue;
    if Tok.Kind = tkCompilerDirective then
    begin
      if not ParseDirectiveName(Tok.Lexeme, Dir, DirArg) then
      begin
        if IsActive then EmitToken(Tok);
        Continue;
      end;
      if Dir = 'ifdef' then PushFrame(EvalSimpleCondition(DirArg))
      else if Dir = 'ifndef' then PushFrame(not EvalSimpleCondition(DirArg))
      else if Dir = 'if' then PushFrame(EvalIfExpr(DirArg))
      else if Dir = 'else' then HandleElse
      else if Dir = 'elseif' then HandleElseIf(EvalIfExpr(DirArg))
      else if (Dir = 'endif') or (Dir = 'ifend') then HandleEndIf
      else if Dir = 'define' then begin if IsActive then FDefines.Define(DirArg); end
      else if Dir = 'undef' then begin if IsActive then FDefines.Undef(DirArg); end
      else if (Dir = 'i') or (Dir = 'include') then begin if IsActive then ProcessInclude(DirArg); end
      else if not IsConsumedDirective(Dir) then
      begin if IsActive then EmitToken(Tok); end;
    end
    else
    begin
      if IsActive then
        EmitToken(Tok);
    end;
  end;
  IncLexer.Free;
end;

procedure TPreprocessor.Process(const ALexer: TLexerResult);
var
  I: LongInt;
  Tok: TToken;
  Dir, Arg: string;
begin
  FOutputTokens.Clear;
  FStack.Clear;
  if ALexer.TokenCount > 0 then
  begin
    { Pre-size capacity only. Ensure() raises Count and inserts empty tokens. }
    FOutputTokens.EnsureCapacity(SizeUInt(ALexer.TokenCount));
    FCurrentFileId := ALexer.TokenAt(0).FileId;
  end;
  for I := 0 to ALexer.TokenCount - 1 do
  begin
    Tok := ALexer.TokenAt(I);
    if Tok.Kind = tkCompilerDirective then
    begin
      if not ParseDirectiveName(Tok.Lexeme, Dir, Arg) then
      begin
        if IsActive then
          EmitToken(Tok);
        Continue;
      end;
      if Dir = 'ifdef' then
        PushFrame(EvalSimpleCondition(Arg))
      else if Dir = 'ifndef' then
        PushFrame(not EvalSimpleCondition(Arg))
      else if Dir = 'if' then
        PushFrame(EvalIfExpr(Arg))
      else if Dir = 'else' then
        HandleElse
      else if Dir = 'elseif' then
        HandleElseIf(EvalIfExpr(Arg))
      else if (Dir = 'endif') or (Dir = 'ifend') then
        HandleEndIf
      else if Dir = 'define' then
      begin
        if IsActive then
          FDefines.Define(Arg);
      end
      else if Dir = 'undef' then
      begin
        if IsActive then
          FDefines.Undef(Arg);
      end
      else if (Dir = 'i') or (Dir = 'include') then
      begin
        if IsActive then
          ProcessInclude(Arg);
      end
      else if IsConsumedDirective(Dir) then
      begin
      end
      else
      begin
        if IsActive then
          EmitToken(Tok);
      end;
    end
    else
    begin
      if IsActive then
        EmitToken(Tok);
    end;
  end;
end;

function TPreprocessor.ToLexerResult: TLexerResult;
var
  TokenArr: array of TToken;
  I: LongInt;
  N: LongInt;
begin
  N := LongInt(FOutputTokens.Count);
  SetLength(TokenArr, N);
  for I := 0 to N - 1 do
    TokenArr[I] := FOutputTokens[I];
  Result := TLexerResult.CreateFromTokens(TokenArr, N);
end;

function TPreprocessor.OutputTokenCount: LongInt;
begin
  Result := LongInt(FOutputTokens.Count);
end;

function TPreprocessor.OutputTokenAt(const AIndex: LongInt): TToken;
begin
  if (AIndex >= 0) and (AIndex < LongInt(FOutputTokens.Count)) then
    Result := FOutputTokens[SizeUInt(AIndex)]
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Kind := tkEOF;
  end;
end;

end.
