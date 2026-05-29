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
  SysUtils;

constructor TDefineTable.Create;
begin
  inherited Create;
  SetLength(FEntries, 0);
  FCount := 0;
end;

function TDefineTable.IndexOf(const AName: string): LongInt;
var
  I: LongInt;
  Norm: string;
begin
  Norm := UpperCase(AName);
  for I := 0 to FCount - 1 do
    if FEntries[I].Name = Norm then
      Exit(I);
  Result := -1;
end;

procedure TDefineTable.Define(const AName: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := '';
    FEntries[Idx].HasValue := False;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := '';
  FEntries[FCount].HasValue := False;
  Inc(FCount);
end;

procedure TDefineTable.DefineValue(const AName, AValue: string);
var
  Idx: LongInt;
begin
  if AName = '' then Exit;
  Idx := IndexOf(AName);
  if Idx >= 0 then
  begin
    FEntries[Idx].Value := AValue;
    FEntries[Idx].HasValue := True;
    Exit;
  end;
  if FCount >= Length(FEntries) then
    SetLength(FEntries, FCount + 16);
  FEntries[FCount].Name := UpperCase(AName);
  FEntries[FCount].Value := AValue;
  FEntries[FCount].HasValue := True;
  Inc(FCount);
end;

procedure TDefineTable.Undef(const AName: string);
var
  Idx, J: LongInt;
begin
  Idx := IndexOf(AName);
  if Idx < 0 then Exit;
  for J := Idx to FCount - 2 do
    FEntries[J] := FEntries[J + 1];
  Dec(FCount);
end;

function TDefineTable.IsDefined(const AName: string): Boolean;
begin
  Result := IndexOf(AName) >= 0;
end;

function TDefineTable.TryGetValue(const AName: string; out AValue: string): Boolean;
var
  Idx: LongInt;
begin
  AValue := '';
  Idx := IndexOf(AName);
  if (Idx < 0) or (not FEntries[Idx].HasValue) then
    Exit(False);
  AValue := FEntries[Idx].Value;
  Result := True;
end;

function TDefineTable.ValueOf(const AName: string): string;
var
  Idx: LongInt;
begin
  Idx := IndexOf(AName);
  if (Idx >= 0) and FEntries[Idx].HasValue then
    Result := FEntries[Idx].Value
  else
    Result := '';
end;

procedure TDefineTable.Clear;
begin
  FCount := 0;
  SetLength(FEntries, 0);
end;

function TDefineTable.Count: LongInt;
begin
  Result := FCount;
end;

procedure TDefineTable.SeedFPCDefines;
begin
  Define('FPC');
  DefineValue('FPC_VERSION', '3');
  DefineValue('FPC_RELEASE', '3');
  DefineValue('FPC_PATCH', '1');
  DefineValue('FPC_FULLVERSION', '30301');
  Define('VER3');
  Define('VER3_3');
  Define('VER3_3_1');
  {$ifdef CPUX86_64}
  Define('CPUX86_64');
  Define('CPU64');
  Define('CPUAMD64');
  {$endif}
  {$ifdef CPUAARCH64}
  Define('CPUAARCH64');
  Define('CPU64');
  {$endif}
  {$ifdef LINUX}
  Define('LINUX');
  Define('UNIX');
  {$endif}
  {$ifdef DARWIN}
  Define('DARWIN');
  Define('UNIX');
  {$endif}
  {$ifdef MSWINDOWS}
  Define('MSWINDOWS');
  Define('WINDOWS');
  {$endif}
  {$ifdef ENDIAN_LITTLE}
  Define('ENDIAN_LITTLE');
  {$endif}
  {$ifdef ENDIAN_BIG}
  Define('ENDIAN_BIG');
  {$endif}
  Define('FPC_HAS_TYPE_EXTENDED');
  Define('FPC_HAS_FEATURE_CLASSES');
  Define('FPC_HAS_FEATURE_EXCEPTIONS');
  Define('FPC_HAS_FEATURE_DYNARRAYS');
  Define('FPC_HAS_FEATURE_ANSISTRINGS');
  Define('FPC_HAS_FEATURE_WIDESTRINGS');
  Define('FPC_HAS_FEATURE_VARIANTS');
  Define('FPC_HAS_FEATURE_RTTI');
end;

{ TPreprocessor }

constructor TPreprocessor.Create(ADefines: TDefineTable; AOwnsDefines: Boolean;
  AIncludeResolver: IIncludeResolver);
begin
  inherited Create;
  FDefines := ADefines;
  FOwnsDefines := AOwnsDefines;
  FIncludeResolver := AIncludeResolver;
  FStackCount := 0;
  SetLength(FStack, 0);
  FOutputCount := 0;
  SetLength(FOutputTokens, 0);
  FCurrentFileId := 0;
  FNextFileId := 1000;
end;

destructor TPreprocessor.Destroy;
begin
  if FOwnsDefines then
    FDefines.Free;
  inherited Destroy;
end;

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
    Content := Copy(ALexeme, 3, Length(ALexeme) - 3)
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
      else if Dir = 'else' then HandleElse
      else if Dir = 'elseif' then HandleElseIf(EvalSimpleCondition(DirArg))
      else if (Dir = 'endif') or (Dir = 'ifend') then HandleEndIf
      else if Dir = 'define' then begin if IsActive then FDefines.Define(DirArg); end
      else if Dir = 'undef' then begin if IsActive then FDefines.Undef(DirArg); end
      else if (Dir = 'i') or (Dir = 'include') then begin if IsActive then ProcessInclude(DirArg); end
      else begin if IsActive then EmitToken(Tok); end;
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
