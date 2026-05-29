unit np_preprocessor;

{$mode objfpc}{$H+}
{$modeswitch advancedrecords}

interface

uses
  np_base_types, np_lexer;

type
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
    FStack: array of TConditionalFrame;
    FStackCount: LongInt;
    FOutputTokens: array of TToken;
    FOutputCount: LongInt;
    function IsActive: Boolean;
    procedure PushFrame(ACondition: Boolean);
    procedure HandleElse;
    procedure HandleElseIf(ACondition: Boolean);
    procedure HandleEndIf;
    procedure EmitToken(const AToken: TToken);
    function ParseDirectiveName(const ALexeme: string;
      out ADirective, AArg: string): Boolean;
    function EvalSimpleCondition(const AArg: string): Boolean;
  public
    constructor Create(ADefines: TDefineTable; AOwnsDefines: Boolean);
    destructor Destroy; override;
    procedure Process(const ALexer: TLexerResult);
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

{ TPreprocessor }

constructor TPreprocessor.Create(ADefines: TDefineTable; AOwnsDefines: Boolean);
begin
  inherited Create;
  FDefines := ADefines;
  FOwnsDefines := AOwnsDefines;
  FStackCount := 0;
  SetLength(FStack, 0);
  FOutputCount := 0;
  SetLength(FOutputTokens, 0);
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
var
  Inner: string;
  P: LongInt;
begin
  if (Length(AArg) > 9) and (LowerCase(Copy(AArg, 1, 8)) = 'defined(') then
  begin
    P := Pos(')', AArg);
    if P > 9 then
      Inner := Trim(Copy(AArg, 9, P - 9))
    else
      Inner := Trim(Copy(AArg, 9, Length(AArg) - 8));
    Result := FDefines.IsDefined(Inner);
  end
  else
    Result := FDefines.IsDefined(AArg);
end;

procedure TPreprocessor.Process(const ALexer: TLexerResult);
var
  I: LongInt;
  Tok: TToken;
  Dir, Arg: string;
begin
  FOutputCount := 0;
  FStackCount := 0;
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
      else if Dir = 'else' then
        HandleElse
      else if Dir = 'elseif' then
        HandleElseIf(EvalSimpleCondition(Arg))
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
