unit np_preprocessor;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  np_base_types, np_lexer;

type
  IIncludeResolver = interface
    function ResolveInclude(const AName: string;
      const AFromFileId: TCoreId;
      out APath: string; out AContent: string): Boolean;
  end;

  TFileIncludeResolver = class(TInterfacedObject, IIncludeResolver)
  private
    FSearchPaths: array of string;
    FSearchCount: LongInt;
    FBaseDir: string;
  public
    constructor Create(const ABaseDir: string);
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

  TDefineTable = class
  private
    FEntries: array of TDefineEntry;
    FCount: LongInt;
    function IndexOf(const AName: string): LongInt;
  public
    constructor Create;
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

  TPreprocessor = class
  private
    FDefines: TDefineTable;
    FOwnsDefines: Boolean;
    FIncludeResolver: IIncludeResolver;
    FStack: array of TConditionalFrame;
    FStackCount: LongInt;
    FOutputTokens: array of TToken;
    FOutputCount: LongInt;
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
    constructor Create(ADefines: TDefineTable; AOwnsDefines: Boolean;
      AIncludeResolver: IIncludeResolver);
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
  if FStackCount = 0 then
    Exit(True);
  Result := FStack[FStackCount - 1].CurrentActive;
end;

procedure TPreprocessor.PushFrame(ACondition: Boolean);
var
  Frame: TConditionalFrame;
begin
  Frame.ParentActive := IsActive;
  Frame.AnyBranchTaken := Frame.ParentActive and ACondition;
  Frame.CurrentActive := Frame.ParentActive and ACondition;
  Frame.SeenElse := False;
  if FStackCount >= Length(FStack) then
    SetLength(FStack, FStackCount + 16);
  FStack[FStackCount] := Frame;
  Inc(FStackCount);
end;

procedure TPreprocessor.HandleElse;
begin
  if FStackCount = 0 then Exit;
  with FStack[FStackCount - 1] do
  begin
    if SeenElse then Exit;
    SeenElse := True;
    CurrentActive := ParentActive and (not AnyBranchTaken);
  end;
end;

procedure TPreprocessor.HandleElseIf(ACondition: Boolean);
begin
  if FStackCount = 0 then Exit;
  with FStack[FStackCount - 1] do
  begin
    if SeenElse then Exit;
    if ParentActive and ACondition and (not AnyBranchTaken) then
    begin
      CurrentActive := True;
      AnyBranchTaken := True;
    end
    else
      CurrentActive := False;
  end;
end;

procedure TPreprocessor.HandleEndIf;
begin
  if FStackCount > 0 then
    Dec(FStackCount);
end;

procedure TPreprocessor.EmitToken(const AToken: TToken);
begin
  if FOutputCount >= Length(FOutputTokens) then
    SetLength(FOutputTokens, FOutputCount + 256);
  FOutputTokens[FOutputCount] := AToken;
  Inc(FOutputCount);
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

function TPreprocessor.EvalSimpleCondition(const AArg: string): Boolean;
begin
  Result := EvalIfExpr(AArg);
end;

procedure TPreprocessor.EvalSkipWS;
begin
  while (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] in [' ', #9]) do
    Inc(FEvalPos);
end;

function TPreprocessor.EvalPeekChar: Char;
begin
  EvalSkipWS;
  if FEvalPos <= Length(FEvalExpr) then Result := FEvalExpr[FEvalPos]
  else Result := #0;
end;

function TPreprocessor.EvalMatchStr(const S: string): Boolean;
var
  I: LongInt;
begin
  EvalSkipWS;
  if FEvalPos + Length(S) - 1 > Length(FEvalExpr) then Exit(False);
  for I := 1 to Length(S) do
    if UpCase(FEvalExpr[FEvalPos + I - 1]) <> UpCase(S[I]) then Exit(False);
  if (FEvalPos + Length(S) <= Length(FEvalExpr)) and
    (FEvalExpr[FEvalPos + Length(S)] in ['A'..'Z','a'..'z','0'..'9','_']) then
    Exit(False);
  Inc(FEvalPos, Length(S));
  Result := True;
end;

function TPreprocessor.EvalParseInt: Int64;
var
  Start: LongInt;
  Neg: Boolean;
begin
  EvalSkipWS;
  Neg := False;
  if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '-') then
  begin Neg := True; Inc(FEvalPos); EvalSkipWS; end;
  if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '$') then
  begin
    Inc(FEvalPos); Start := FEvalPos;
    while (FEvalPos <= Length(FEvalExpr)) and
      (FEvalExpr[FEvalPos] in ['0'..'9','A'..'F','a'..'f']) do Inc(FEvalPos);
    Result := StrToInt64Def('$' + Copy(FEvalExpr, Start, FEvalPos - Start), 0);
  end
  else
  begin
    Start := FEvalPos;
    while (FEvalPos <= Length(FEvalExpr)) and
      (FEvalExpr[FEvalPos] in ['0'..'9']) do Inc(FEvalPos);
    Result := StrToInt64Def(Copy(FEvalExpr, Start, FEvalPos - Start), 0);
  end;
  if Neg then Result := -Result;
end;

function TPreprocessor.EvalParseIdent: string;
var
  Start: LongInt;
begin
  EvalSkipWS;
  Start := FEvalPos;
  while (FEvalPos <= Length(FEvalExpr)) and
    (FEvalExpr[FEvalPos] in ['A'..'Z','a'..'z','0'..'9','_']) do Inc(FEvalPos);
  Result := Copy(FEvalExpr, Start, FEvalPos - Start);
end;

function TPreprocessor.EvalAtom: Int64;
var
  Id, Inner: string;
begin
  EvalSkipWS;
  if EvalPeekChar = '(' then
  begin Inc(FEvalPos); Result := EvalOr; EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    Exit;
  end;
  if EvalMatchStr('not') then Exit(Ord(EvalAtom = 0));
  if EvalMatchStr('true') then Exit(1);
  if EvalMatchStr('false') then Exit(0);
  if (EvalPeekChar in ['0'..'9','$']) or
    ((EvalPeekChar = '-') and (FEvalPos < Length(FEvalExpr)) and
     (FEvalExpr[FEvalPos+1] in ['0'..'9','$'])) then
    Exit(EvalParseInt);
  Id := EvalParseIdent;
  if Id = '' then Exit(0);
  if LowerCase(Id) = 'defined' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    Inner := EvalParseIdent;
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    if FDefines.IsDefined(Inner) then Result := 1 else Result := 0;
  end
  else if LowerCase(Id) = 'sizeof' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    Inner := LowerCase(EvalParseIdent);
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    if (Inner = 'pointer') or (Inner = 'ptrint') or (Inner = 'ptruint') or
      (Inner = 'nativeint') or (Inner = 'nativeuint') then
      Result := {$ifdef CPU64}8{$else}4{$endif}
    else if (Inner = 'byte') or (Inner = 'shortint') or (Inner = 'boolean') or
      (Inner = 'ansichar') or (Inner = 'char') then
      Result := 1
    else if (Inner = 'word') or (Inner = 'smallint') or (Inner = 'widechar') then
      Result := 2
    else if (Inner = 'dword') or (Inner = 'longint') or (Inner = 'cardinal') or
      (Inner = 'longword') or (Inner = 'single') then
      Result := 4
    else if (Inner = 'qword') or (Inner = 'int64') or (Inner = 'double') or
      (Inner = 'comp') or (Inner = 'currency') then
      Result := 8
    else if (Inner = 'extended') then
      Result := 10
    else
      Result := 0;
  end
  else if LowerCase(Id) = 'declared' then
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '(') then Inc(FEvalPos);
    EvalParseIdent;
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = ')') then Inc(FEvalPos);
    Result := 0;
  end
  else
  begin
    if FDefines.TryGetValue(Id, Inner) then
      Result := StrToInt64Def(Inner, Ord(FDefines.IsDefined(Id)))
    else if FDefines.IsDefined(Id) then
      Result := 1
    else
      Result := 0;
  end;
end;

function TPreprocessor.EvalMul: Int64;
var
  R: Int64;
begin
  Result := EvalAtom;
  while True do
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '*') then
    begin Inc(FEvalPos); Result := Result * EvalAtom; end
    else if EvalMatchStr('div') then
    begin R := EvalAtom; if R <> 0 then Result := Result div R; end
    else if EvalMatchStr('mod') then
    begin R := EvalAtom; if R <> 0 then Result := Result mod R; end
    else Break;
  end;
end;

function TPreprocessor.EvalAdd: Int64;
begin
  Result := EvalMul;
  while True do
  begin
    EvalSkipWS;
    if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '+') then
    begin Inc(FEvalPos); Result := Result + EvalMul; end
    else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '-') then
    begin Inc(FEvalPos); Result := Result - EvalMul; end
    else Break;
  end;
end;

function TPreprocessor.EvalCmp: Int64;
var
  R: Int64;
begin
  Result := EvalAdd;
  EvalSkipWS;
  if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') and
    (FEvalExpr[FEvalPos+1] = '>') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result <> R); end
  else if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '>') and
    (FEvalExpr[FEvalPos+1] = '=') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result >= R); end
  else if (FEvalPos < Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') and
    (FEvalExpr[FEvalPos+1] = '=') then
  begin Inc(FEvalPos, 2); R := EvalAdd; Result := Ord(Result <= R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '=') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result = R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '>') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result > R); end
  else if (FEvalPos <= Length(FEvalExpr)) and (FEvalExpr[FEvalPos] = '<') then
  begin Inc(FEvalPos); R := EvalAdd; Result := Ord(Result < R); end;
end;

function TPreprocessor.EvalAnd: Int64;
begin
  Result := EvalCmp;
  while EvalMatchStr('and') do
    Result := Ord((Result <> 0) and (EvalCmp <> 0));
end;

function TPreprocessor.EvalOr: Int64;
begin
  Result := EvalAnd;
  while EvalMatchStr('or') do
    Result := Ord((Result <> 0) or (EvalAnd <> 0));
end;

function TPreprocessor.EvalIfExpr(const AExpr: string): Boolean;
begin
  FEvalExpr := AExpr;
  FEvalPos := 1;
  Result := EvalOr <> 0;
end;

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
  FOutputCount := 0;
  FStackCount := 0;
  if ALexer.TokenCount > 0 then
    FCurrentFileId := ALexer.TokenAt(0).FileId;
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
begin
  Result := TLexerResult.CreateFromTokens(FOutputTokens, FOutputCount);
end;

function TPreprocessor.OutputTokenCount: LongInt;
begin
  Result := FOutputCount;
end;

function TPreprocessor.OutputTokenAt(const AIndex: LongInt): TToken;
begin
  if (AIndex >= 0) and (AIndex < FOutputCount) then
    Result := FOutputTokens[AIndex]
  else
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.Kind := tkEOF;
  end;
end;

end.
