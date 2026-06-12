unit nextpas.core.template;
{**
 * @desc Text template engine (Go text/template simplified).
 *       Supports variable substitution, conditionals, loops, pipe filters,
 *       comparison operators, custom functions, variable assignment, with scope,
 *       define/template blocks.
 *       L3 module — zero SysUtils dependency.
 *}

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.text.conv;

type
  TStringArray = array of string;

  TTemplateVar = record
    Name: string;
    Value: string;
  end;
  TTemplateVarArray = array of TTemplateVar;

  TTemplateList = record
    Name: string;
    Items: array of string;
  end;
  TTemplateListArray = array of TTemplateList;

  TTemplateFunc = function(const AValue: string): string;

  TTemplateFuncEntry = record
    Name: string;
    Func: TTemplateFunc;
  end;
  TTemplateFuncArray = array of TTemplateFuncEntry;

  TTemplateDefine = record
    Name: string;
    Body: string;
  end;

  TTemplateContext = record
  private
    FVars: TTemplateVarArray;
    FVarCount: Integer;
    FLists: TTemplateListArray;
    FListCount: Integer;
    FFuncs: TTemplateFuncArray;
    FFuncCount: Integer;
    FDefines: array of TTemplateDefine;
    FDefineCount: Integer;
    FPrefix: string;
  public
    class function Create: TTemplateContext; static;
    procedure SetVar(const AName, AValue: string);
    procedure SetInt(const AName: string; AValue: Int64);
    procedure SetBool(const AName: string; AValue: Boolean);
    procedure SetList(const AName: string; const AItems: array of string);
    procedure RegisterFunc(const AName: string; AFunc: TTemplateFunc);
    procedure SetPrefix(const AValue: string);
    procedure Define(const AName, ABody: string);
    function GetDefine(const AName: string): string;
    function GetVar(const AName: string): string;
    function GetBool(const AName: string): Boolean;
    function GetList(const AName: string): TStringArray;
  end;

  TTemplate = record
  private
    FSource: string;
  public
    class function Create(const ASource: string): TTemplate; static;
    function Render(const ACtx: TTemplateContext): string;
    function RenderWith(const AVars: array of TTemplateVar): string;
  end;

function TemplateRender(const ATemplate: string; const ACtx: TTemplateContext): string;

implementation

uses
  nextpas.core.errors;

{ ============================================================================ }
{ Internal string helpers                                                       }
{ ============================================================================ }

function StripDot(const AName: string): string;
begin
  if (Length(AName) > 1) and (AName[1] = '.') then
    Result := Copy(AName, 2, Length(AName) - 1)
  else
    Result := AName;
end;

function TrimInternal(const S: string): string;
var
  LStart, LEnd: Integer;
begin
  LStart := 1;
  LEnd := Length(S);
  while (LStart <= LEnd) and (S[LStart] <= ' ') do
    Inc(LStart);
  while (LEnd >= LStart) and (S[LEnd] <= ' ') do
    Dec(LEnd);
  if LStart > LEnd then
    Result := ''
  else
    Result := Copy(S, LStart, LEnd - LStart + 1);
end;

function UpperInternal(const S: string): string;
var
  LI: Integer;
begin
  Result := S;
  UniqueString(Result);
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'a') and (Result[LI] <= 'z') then
      Dec(Result[LI], 32);
end;

function LowerInternal(const S: string): string;
var
  LI: Integer;
begin
  Result := S;
  UniqueString(Result);
  for LI := 1 to Length(Result) do
    if (Result[LI] >= 'A') and (Result[LI] <= 'Z') then
      Inc(Result[LI], 32);
end;

function StrEqCI(const A, B: string): Boolean;
begin
  Result := (LowerInternal(A) = LowerInternal(B));
end;

{ ============================================================================ }
{ Filter application                                                            }
{ ============================================================================ }

procedure ParseFilter(const ARaw: string; out AName, AArg: string);
var
  LI, LStart, LEnd: Integer;
  LTrimmed: string;
begin
  LTrimmed := TrimInternal(ARaw);
  AArg := '';
  LI := 1;
  while (LI <= Length(LTrimmed)) and (LTrimmed[LI] > ' ') do
    Inc(LI);
  AName := Copy(LTrimmed, 1, LI - 1);
  if LI <= Length(LTrimmed) then
  begin
    LStart := LI;
    while (LStart <= Length(LTrimmed)) and (LTrimmed[LStart] <= ' ') do
      Inc(LStart);
    LEnd := Length(LTrimmed);
    if (LStart <= LEnd) and (LTrimmed[LStart] = '"') and (LTrimmed[LEnd] = '"') then
    begin
      Inc(LStart);
      Dec(LEnd);
    end;
    if LStart <= LEnd then
      AArg := Copy(LTrimmed, LStart, LEnd - LStart + 1)
    else
      AArg := '';
  end;
end;

function ApplyFilterWithFuncs(const AValue, AFilter, AArg: string;
  const AFuncs: TTemplateFuncArray; AFuncCount: Integer): string;
var
  LI: Integer;
begin
  { Check custom functions first }
  for LI := 0 to AFuncCount - 1 do
    if AFuncs[LI].Name = AFilter then
      Exit(AFuncs[LI].Func(AValue));

  { Built-in filters }
  if StrEqCI(AFilter, 'upper') then
    Result := UpperInternal(AValue)
  else if StrEqCI(AFilter, 'lower') then
    Result := LowerInternal(AValue)
  else if StrEqCI(AFilter, 'trim') then
    Result := TrimInternal(AValue)
  else if StrEqCI(AFilter, 'default') then
  begin
    if AValue = '' then
      Result := AArg
    else
      Result := AValue;
  end
  else if StrEqCI(AFilter, 'len') then
    Result := IntToStr(Length(AValue))
  else
    Result := AValue;
end;

{ ============================================================================ }
{ Expression evaluation                                                         }
{ ============================================================================ }

function EvalExpr(const AExpr: string; const ACtx: TTemplateContext;
  const ALocals: TTemplateVarArray; ALocalCount: Integer): string;
var
  LParts: array[0..15] of string;
  LPartCount: Integer;
  LI, LStart: Integer;
  LExpr: string;
  LFilter, LArg: string;
  LVarName: string;
begin
  LExpr := TrimInternal(AExpr);
  if LExpr = '' then
    Exit('');

  { Split by pipe }
  LPartCount := 0;
  LStart := 1;
  for LI := 1 to Length(LExpr) do
  begin
    if (LExpr[LI] = '|') and (LPartCount < High(LParts)) then
    begin
      LParts[LPartCount] := Copy(LExpr, LStart, LI - LStart);
      Inc(LPartCount);
      LStart := LI + 1;
    end;
  end;
  LParts[LPartCount] := Copy(LExpr, LStart, Length(LExpr) - LStart + 1);
  Inc(LPartCount);

  { First part is the variable reference }
  LVarName := TrimInternal(LParts[0]);

  { Check if it's a local variable reference ($name) }
  if (Length(LVarName) > 1) and (LVarName[1] = '$') then
  begin
    LVarName := Copy(LVarName, 2, Length(LVarName) - 1);
    Result := '';
    for LI := ALocalCount - 1 downto 0 do
      if ALocals[LI].Name = LVarName then
      begin
        Result := ALocals[LI].Value;
        Break;
      end;
  end
  else
    Result := ACtx.GetVar(StripDot(LVarName));

  { Apply pipe filters }
  for LI := 1 to LPartCount - 1 do
  begin
    ParseFilter(LParts[LI], LFilter, LArg);
    Result := ApplyFilterWithFuncs(Result, LFilter, LArg, ACtx.FFuncs, ACtx.FFuncCount);
  end;
end;

{ Comparison operators }
function EvalCompare(const AOp, ALeft, ARight: string): Boolean;
var
  LIntL, LIntR: Int64;
  LNumeric: Boolean;
begin
  if (AOp = 'eq') then
    Result := (ALeft = ARight)
  else if (AOp = 'ne') then
    Result := (ALeft <> ARight)
  else
  begin
    { gt/lt/ge/le: try numeric first }
    LNumeric := TryStrToInt64(ALeft, LIntL) and TryStrToInt64(ARight, LIntR);
    if AOp = 'gt' then
    begin
      if LNumeric then Result := LIntL > LIntR
      else Result := ALeft > ARight;
    end
    else if AOp = 'lt' then
    begin
      if LNumeric then Result := LIntL < LIntR
      else Result := ALeft < ARight;
    end
    else if AOp = 'ge' then
    begin
      if LNumeric then Result := LIntL >= LIntR
      else Result := ALeft >= ARight;
    end
    else if AOp = 'le' then
    begin
      if LNumeric then Result := LIntL <= LIntR
      else Result := ALeft <= ARight;
    end
    else
      Result := False;
  end;
end;

function IsCompareOp(const S: string): Boolean;
begin
  Result := (S = 'eq') or (S = 'ne') or (S = 'gt') or (S = 'lt') or
            (S = 'ge') or (S = 'le');
end;

function EvalBool(const AExpr: string; const ACtx: TTemplateContext;
  const ALocals: TTemplateVarArray; ALocalCount: Integer): Boolean;
var
  LExpr, LToken, LRest: string;
  LI: Integer;
  LOp, LLeftExpr, LRightStr: string;
  LLeft, LRight: string;
begin
  LExpr := TrimInternal(AExpr);

  { Extract first token to check for comparison operator }
  LI := 1;
  while (LI <= Length(LExpr)) and (LExpr[LI] > ' ') do
    Inc(LI);
  LToken := Copy(LExpr, 1, LI - 1);

  if IsCompareOp(LToken) then
  begin
    LOp := LToken;
    LRest := TrimInternal(Copy(LExpr, LI + 1, Length(LExpr) - LI));

    { Parse: <varRef> <literal-or-varRef> }
    { Find the left operand }
    LI := 1;
    while (LI <= Length(LRest)) and (LRest[LI] > ' ') do
      Inc(LI);
    LLeftExpr := Copy(LRest, 1, LI - 1);
    LRightStr := TrimInternal(Copy(LRest, LI + 1, Length(LRest) - LI));

    { Resolve left }
    if (Length(LLeftExpr) > 1) and (LLeftExpr[1] = '$') then
    begin
      LLeft := '';
      for LI := ALocalCount - 1 downto 0 do
        if ALocals[LI].Name = Copy(LLeftExpr, 2, Length(LLeftExpr) - 1) then
        begin
          LLeft := ALocals[LI].Value;
          Break;
        end;
    end
    else
      LLeft := ACtx.GetVar(StripDot(LLeftExpr));

    { Resolve right — could be quoted string or variable }
    if (Length(LRightStr) >= 2) and (LRightStr[1] = '"') and (LRightStr[Length(LRightStr)] = '"') then
      LRight := Copy(LRightStr, 2, Length(LRightStr) - 2)
    else if (Length(LRightStr) > 1) and (LRightStr[1] = '$') then
    begin
      LRight := '';
      for LI := ALocalCount - 1 downto 0 do
        if ALocals[LI].Name = Copy(LRightStr, 2, Length(LRightStr) - 1) then
        begin
          LRight := ALocals[LI].Value;
          Break;
        end;
    end
    else if (Length(LRightStr) > 0) and ((LRightStr[1] = '.') or ((LRightStr[1] >= 'A') and (LRightStr[1] <= 'z'))) then
      LRight := ACtx.GetVar(StripDot(LRightStr))
    else
      LRight := LRightStr;

    Result := EvalCompare(LOp, LLeft, LRight);
  end
  else
  begin
    { Standard boolean evaluation }
    Result := ACtx.GetBool(StripDot(LExpr));
  end;
end;

{ ============================================================================ }
{ Core render engine                                                            }
{ ============================================================================ }

type
  TStopReason = (srNone, srElse, srEnd);

procedure RaiseTemplateParseError(const AMessage: string);
begin
  raise EParseError.Create(AMessage);
end;

procedure RequireActionExpr(const AExpr, AAction: string);
begin
  if TrimInternal(AExpr) = '' then
    RaiseTemplateParseError('malformed ' + AAction + ' action');
end;

procedure RequireStopAction(const AExpr, AAction: string);
begin
  if TrimInternal(AExpr) <> '' then
    RaiseTemplateParseError('malformed ' + AAction + ' action');
end;

procedure RequireBoolExpr(const AExpr, AAction: string);
var
  LExpr, LToken, LRest, LLeft, LRight: string;
  LI: Integer;
begin
  LExpr := TrimInternal(AExpr);
  if LExpr = '' then
    RaiseTemplateParseError('malformed ' + AAction + ' action');

  LI := 1;
  while (LI <= Length(LExpr)) and (LExpr[LI] > ' ') do
    Inc(LI);
  LToken := Copy(LExpr, 1, LI - 1);
  if not IsCompareOp(LToken) then
    Exit;

  LRest := TrimInternal(Copy(LExpr, LI + 1, Length(LExpr) - LI));
  LI := 1;
  while (LI <= Length(LRest)) and (LRest[LI] > ' ') do
    Inc(LI);
  LLeft := Copy(LRest, 1, LI - 1);
  if LI <= Length(LRest) then
    LRight := TrimInternal(Copy(LRest, LI + 1, Length(LRest) - LI))
  else
    LRight := '';
  if (LLeft = '') or (LRight = '') then
    RaiseTemplateParseError('malformed ' + AAction + ' action');
end;

procedure RequireExpressionSyntax(const AExpr, AAction: string);
var
  LExpr: string;
  LStart, LI: Integer;
begin
  LExpr := TrimInternal(AExpr);
  if LExpr = '' then
    RaiseTemplateParseError('malformed ' + AAction + ' action');

  LStart := 1;
  for LI := 1 to Length(LExpr) do
  begin
    if LExpr[LI] = '|' then
    begin
      if TrimInternal(Copy(LExpr, LStart, LI - LStart)) = '' then
        RaiseTemplateParseError('malformed ' + AAction + ' action');
      LStart := LI + 1;
    end;
  end;
  if TrimInternal(Copy(LExpr, LStart, Length(LExpr) - LStart + 1)) = '' then
    RaiseTemplateParseError('malformed ' + AAction + ' action');
end;

procedure RequireBlockClosed(const AStop: TStopReason; const ABlockName: string);
begin
  if AStop <> srEnd then
    RaiseTemplateParseError('unclosed ' + ABlockName + ' block');
end;

procedure RejectTopLevelStop(const AStop: TStopReason);
begin
  if AStop = srElse then
    RaiseTemplateParseError('unexpected else');
  if AStop = srEnd then
    RaiseTemplateParseError('unexpected end');
end;

function RenderSegment(const ASrc: string; var APos: Integer;
  const ACtx: TTemplateContext;
  var ALocals: TTemplateVarArray; var ALocalCount: Integer;
  out AStop: TStopReason): string; forward;

function FindNextTag(const ASrc: string; AFrom: Integer;
  out ATagStart, ATagEnd: Integer; out AContent: string): Boolean;
var
  LLen, LClose: Integer;
begin
  LLen := Length(ASrc);
  ATagStart := AFrom;
  while ATagStart <= LLen - 1 do
  begin
    if (ASrc[ATagStart] = '{') and (ASrc[ATagStart + 1] = '{') then
    begin
      { Check escape }
      if (ATagStart > 1) and (ASrc[ATagStart - 1] = '\') then
      begin
        Inc(ATagStart);
        Continue;
      end;
      LClose := ATagStart + 2;
      while LClose <= LLen - 1 do
      begin
        if (ASrc[LClose] = '}') and (ASrc[LClose + 1] = '}') then
        begin
          AContent := Copy(ASrc, ATagStart + 2, LClose - ATagStart - 2);
          ATagEnd := LClose + 2;
          Exit(True);
        end;
        Inc(LClose);
      end;
      RaiseTemplateParseError('unclosed template action');
    end;
    Inc(ATagStart);
  end;
  Result := False;
end;

function AppendLiteral(const ASrc: string; AFrom, ATo: Integer): string;
var
  LI: Integer;
  LResult: string;
  LStart: Integer;
begin
  LResult := '';
  LStart := AFrom;
  LI := AFrom;
  while LI <= ATo do
  begin
    if (LI < ATo) and (ASrc[LI] = '\') and ((ASrc[LI + 1] = '{') or (ASrc[LI + 1] = '}')) then
    begin
      LResult := LResult + Copy(ASrc, LStart, LI - LStart) + ASrc[LI + 1];
      Inc(LI, 2);
      LStart := LI;
    end
    else
      Inc(LI);
  end;
  LResult := LResult + Copy(ASrc, LStart, ATo - LStart + 1);
  Result := LResult;
end;

function ExtractKeyword(const AContent: string; out AExpr: string): string;
var
  LI: Integer;
begin
  LI := 1;
  while (LI <= Length(AContent)) and (AContent[LI] > ' ') do
    Inc(LI);
  Result := Copy(AContent, 1, LI - 1);
  AExpr := TrimInternal(Copy(AContent, LI + 1, Length(AContent) - LI));
end;

procedure ParseLocalAction(const AContent: string; out AName, AExpr: string; out AAssign: Boolean);
var
  LContent, LRest: string;
  LI, LAssignPos, LPipePos: Integer;
begin
  LContent := TrimInternal(AContent);
  AName := '';
  AExpr := '';
  AAssign := False;

  if (LContent = '') or (LContent[1] <> '$') then
    Exit;

  LAssignPos := Pos(':=', LContent);
  LPipePos := Pos('|', LContent);
  if (LAssignPos > 0) and ((LPipePos = 0) or (LAssignPos < LPipePos)) then
  begin
    AAssign := True;
    AName := TrimInternal(Copy(LContent, 2, LAssignPos - 2));
    AExpr := TrimInternal(Copy(LContent, LAssignPos + 2, Length(LContent) - LAssignPos - 1));
    if (AName = '') or (AExpr = '') then
      RaiseTemplateParseError('malformed variable assignment action');
    Exit;
  end;

  LI := 2;
  while (LI <= Length(LContent)) and (LContent[LI] > ' ') and
        (LContent[LI] <> '|') do
    Inc(LI);

  AName := Copy(LContent, 2, LI - 2);
  LRest := TrimInternal(Copy(LContent, LI, Length(LContent) - LI + 1));
  if (AName = '') or ((LRest <> '') and (LRest[1] <> '|')) then
    RaiseTemplateParseError('malformed variable assignment action');

  AExpr := LContent;
end;

function ExtractQuotedName(const AExpr, AAction: string): string; forward;

procedure SkipBlock(const ASrc: string; var APos: Integer; out AStop: TStopReason);
var
  LLen: Integer;
  LTagStart, LTagEnd: Integer;
  LContent, LKeyword, LExpr: string;
  LLocalName, LLocalExpr: string;
  LLocalAssign: Boolean;
  LBlocks: array of string;
  LBlockCount: Integer;

  procedure PushBlock(const AName: string);
  begin
    if LBlockCount >= Length(LBlocks) then
      SetLength(LBlocks, LBlockCount + 8);
    LBlocks[LBlockCount] := AName;
    Inc(LBlockCount);
  end;

  function TopBlock: string;
  begin
    if LBlockCount = 0 then
      Result := ''
    else
      Result := LBlocks[LBlockCount - 1];
  end;
begin
  LLen := Length(ASrc);
  LBlockCount := 0;
  SetLength(LBlocks, 0);
  AStop := srNone;

  while APos <= LLen do
  begin
    if not FindNextTag(ASrc, APos, LTagStart, LTagEnd, LContent) then
    begin
      APos := LLen + 1;
      Exit;
    end;

    APos := LTagEnd;
    LContent := TrimInternal(LContent);
    LKeyword := ExtractKeyword(LContent, LExpr);

    if (LKeyword = 'define') or (LKeyword = 'template') then
      ExtractQuotedName(LExpr, LKeyword);
    if LKeyword = 'if' then
      RequireBoolExpr(LExpr, LKeyword)
    else if (LKeyword = 'range') or (LKeyword = 'with') then
      RequireActionExpr(LExpr, LKeyword);
    if (LContent <> '') and (LContent[1] = '$') then
      ParseLocalAction(LContent, LLocalName, LLocalExpr, LLocalAssign);

    if (LKeyword = 'if') or (LKeyword = 'range') or
       (LKeyword = 'with') or (LKeyword = 'define') then
      PushBlock(LKeyword)
    else if LKeyword = 'else' then
    begin
      RequireStopAction(LExpr, 'else');
      if LBlockCount = 0 then
      begin
        AStop := srElse;
        Exit;
      end;
      if TopBlock <> 'if' then
        RaiseTemplateParseError('unexpected else');
    end
    else if LKeyword = 'end' then
    begin
      RequireStopAction(LExpr, 'end');
      if LBlockCount = 0 then
      begin
        AStop := srEnd;
        Exit;
      end;
      Dec(LBlockCount);
    end
    else if LContent <> '' then
      RequireExpressionSyntax(LContent, 'expression');
  end;
end;

{ Extract a quoted name from expression like "name" }
function ExtractQuotedName(const AExpr, AAction: string): string;
var
  LExpr: string;
  LEnd: Integer;
begin
  LExpr := TrimInternal(AExpr);
  if (LExpr = '') or (LExpr[1] <> '"') then
    RaiseTemplateParseError('malformed ' + AAction + ' name');

  LEnd := 2;
  while (LEnd <= Length(LExpr)) and (LExpr[LEnd] <> '"') do
    Inc(LEnd);
  if LEnd > Length(LExpr) then
    RaiseTemplateParseError('malformed ' + AAction + ' name');

  Result := Copy(LExpr, 2, LEnd - 2);
  if Result = '' then
    RaiseTemplateParseError('malformed ' + AAction + ' name');
  if TrimInternal(Copy(LExpr, LEnd + 1, Length(LExpr) - LEnd)) <> '' then
    RaiseTemplateParseError('malformed ' + AAction + ' name');
end;

function RenderSegment(const ASrc: string; var APos: Integer;
  const ACtx: TTemplateContext;
  var ALocals: TTemplateVarArray; var ALocalCount: Integer;
  out AStop: TStopReason): string;
var
  LLen: Integer;
  LTagStart, LTagEnd: Integer;
  LContent, LKeyword, LExpr: string;
  LResult: string;
  LItems: TStringArray;
  LI, LSavePos: Integer;
  LInnerStop: TStopReason;
  LVarName, LVarExpr: string;
  LVarAssign: Boolean;
  LDefName, LDefBody: string;
  LWithVar, LSavedPrefix, LSavedDot: string;

  function RenderScopedSegment: string;
  var
    LSavedLocalCount: Integer;
  begin
    LSavedLocalCount := ALocalCount;
    try
      Result := RenderSegment(ASrc, APos, ACtx, ALocals, ALocalCount, LInnerStop);
    finally
      ALocalCount := LSavedLocalCount;
    end;
  end;
begin
  LLen := Length(ASrc);
  LResult := '';
  AStop := srNone;

  while APos <= LLen do
  begin
    if not FindNextTag(ASrc, APos, LTagStart, LTagEnd, LContent) then
    begin
      LResult := LResult + AppendLiteral(ASrc, APos, LLen);
      APos := LLen + 1;
      Break;
    end;

    { Append literal text before tag }
    if LTagStart > APos then
      LResult := LResult + AppendLiteral(ASrc, APos, LTagStart - 1);
    APos := LTagEnd;

    { Parse tag }
    LContent := TrimInternal(LContent);
    LKeyword := ExtractKeyword(LContent, LExpr);

    { Stop words }
    if LKeyword = 'end' then
    begin
      RequireStopAction(LExpr, 'end');
      AStop := srEnd;
      Exit(LResult);
    end;
    if LKeyword = 'else' then
    begin
      RequireStopAction(LExpr, 'else');
      AStop := srElse;
      Exit(LResult);
    end;

    { define "name": collect body until end }
    if LKeyword = 'define' then
    begin
      LDefName := ExtractQuotedName(LExpr, 'define');
      LDefBody := RenderScopedSegment;
      RequireBlockClosed(LInnerStop, 'define');
      TTemplateContext(ACtx).Define(LDefName, LDefBody);
      Continue;
    end;

    { template "name": insert defined block }
    if LKeyword = 'template' then
    begin
      LDefName := ExtractQuotedName(LExpr, 'template');
      LResult := LResult + ACtx.GetDefine(LDefName);
      Continue;
    end;

    { with .Var: set prefix for inner block }
    if LKeyword = 'with' then
    begin
      RequireActionExpr(LExpr, 'with');
      LWithVar := StripDot(TrimInternal(LExpr));
      LSavedPrefix := TTemplateContext(ACtx).FPrefix;
      if LSavedPrefix <> '' then
        TTemplateContext(ACtx).SetPrefix(LSavedPrefix + '.' + LWithVar)
      else
        TTemplateContext(ACtx).SetPrefix(LWithVar);
      try
        LResult := LResult + RenderScopedSegment;
        RequireBlockClosed(LInnerStop, 'with');
      finally
        TTemplateContext(ACtx).SetPrefix(LSavedPrefix);
      end;
      Continue;
    end;

    { Local variable action }
    if (LContent <> '') and (LContent[1] = '$') then
    begin
      ParseLocalAction(LContent, LVarName, LVarExpr, LVarAssign);
      if not LVarAssign then
      begin
        LResult := LResult + EvalExpr(LVarExpr, ACtx, ALocals, ALocalCount);
        Continue;
      end;

      if ALocalCount >= Length(ALocals) then
        SetLength(ALocals, ALocalCount + 8);
      ALocals[ALocalCount].Name := LVarName;
      ALocals[ALocalCount].Value := EvalExpr(LVarExpr, ACtx, ALocals, ALocalCount);
      Inc(ALocalCount);
      Continue;
    end;

    { if/else/end }
    if LKeyword = 'if' then
    begin
      RequireBoolExpr(LExpr, 'if');
      if EvalBool(LExpr, ACtx, ALocals, ALocalCount) then
      begin
        LResult := LResult + RenderScopedSegment;
        if LInnerStop = srElse then
        begin
          SkipBlock(ASrc, APos, LInnerStop);
          RequireBlockClosed(LInnerStop, 'if');
        end
        else
          RequireBlockClosed(LInnerStop, 'if');
      end
      else
      begin
        SkipBlock(ASrc, APos, LInnerStop);
        if LInnerStop = srElse then
        begin
          LResult := LResult + RenderScopedSegment;
          RequireBlockClosed(LInnerStop, 'if');
        end
        else
          RequireBlockClosed(LInnerStop, 'if');
      end;
    end
    { range }
    else if LKeyword = 'range' then
    begin
      RequireActionExpr(LExpr, 'range');
      LItems := ACtx.GetList(StripDot(LExpr));
      LSavePos := APos;
      if Length(LItems) = 0 then
      begin
        SkipBlock(ASrc, APos, LInnerStop);
        RequireBlockClosed(LInnerStop, 'range');
      end
      else
      begin
        for LI := 0 to High(LItems) do
        begin
          APos := LSavePos;
          LSavedDot := ACtx.GetVar('.');
          TTemplateContext(ACtx).SetVar('.', LItems[LI]);
          try
            LResult := LResult + RenderScopedSegment;
            RequireBlockClosed(LInnerStop, 'range');
          finally
            TTemplateContext(ACtx).SetVar('.', LSavedDot);
          end;
        end;
      end;
    end
    else
    begin
      { Variable/expression with pipes }
      RequireExpressionSyntax(LContent, 'expression');
      LResult := LResult + EvalExpr(LContent, ACtx, ALocals, ALocalCount);
    end;
  end;

  Result := LResult;
end;

{ ============================================================================ }
{ TTemplateContext                                                               }
{ ============================================================================ }

function CloneTemplateContext(const ACtx: TTemplateContext): TTemplateContext;
var
  LI, LJ: Integer;
begin
  Result := TTemplateContext.Create;

  Result.FVarCount := ACtx.FVarCount;
  SetLength(Result.FVars, ACtx.FVarCount);
  for LI := 0 to ACtx.FVarCount - 1 do
    Result.FVars[LI] := ACtx.FVars[LI];

  Result.FListCount := ACtx.FListCount;
  SetLength(Result.FLists, ACtx.FListCount);
  for LI := 0 to ACtx.FListCount - 1 do
  begin
    Result.FLists[LI].Name := ACtx.FLists[LI].Name;
    SetLength(Result.FLists[LI].Items, Length(ACtx.FLists[LI].Items));
    for LJ := 0 to High(ACtx.FLists[LI].Items) do
      Result.FLists[LI].Items[LJ] := ACtx.FLists[LI].Items[LJ];
  end;

  Result.FFuncCount := ACtx.FFuncCount;
  SetLength(Result.FFuncs, ACtx.FFuncCount);
  for LI := 0 to ACtx.FFuncCount - 1 do
    Result.FFuncs[LI] := ACtx.FFuncs[LI];

  Result.FDefineCount := ACtx.FDefineCount;
  SetLength(Result.FDefines, ACtx.FDefineCount);
  for LI := 0 to ACtx.FDefineCount - 1 do
    Result.FDefines[LI] := ACtx.FDefines[LI];

  Result.FPrefix := ACtx.FPrefix;
end;

class function TTemplateContext.Create: TTemplateContext;
begin
  Result.FVarCount := 0;
  Result.FListCount := 0;
  Result.FFuncCount := 0;
  Result.FDefineCount := 0;
  Result.FPrefix := '';
  SetLength(Result.FVars, 0);
  SetLength(Result.FLists, 0);
  SetLength(Result.FFuncs, 0);
  SetLength(Result.FDefines, 0);
end;

procedure TTemplateContext.SetVar(const AName, AValue: string);
var
  LI: Integer;
begin
  for LI := 0 to FVarCount - 1 do
    if FVars[LI].Name = AName then
    begin
      FVars[LI].Value := AValue;
      Exit;
    end;
  if FVarCount >= Length(FVars) then
    SetLength(FVars, FVarCount + 8);
  FVars[FVarCount].Name := AName;
  FVars[FVarCount].Value := AValue;
  Inc(FVarCount);
end;

procedure TTemplateContext.SetInt(const AName: string; AValue: Int64);
begin
  SetVar(AName, IntToStr(AValue));
end;

procedure TTemplateContext.SetBool(const AName: string; AValue: Boolean);
begin
  if AValue then
    SetVar(AName, 'true')
  else
    SetVar(AName, 'false');
end;

procedure TTemplateContext.SetList(const AName: string; const AItems: array of string);
var
  LI, LIdx: Integer;
begin
  for LIdx := 0 to FListCount - 1 do
    if FLists[LIdx].Name = AName then
    begin
      SetLength(FLists[LIdx].Items, Length(AItems));
      for LI := 0 to High(AItems) do
        FLists[LIdx].Items[LI] := AItems[LI];
      Exit;
    end;
  if FListCount >= Length(FLists) then
    SetLength(FLists, FListCount + 4);
  FLists[FListCount].Name := AName;
  SetLength(FLists[FListCount].Items, Length(AItems));
  for LI := 0 to High(AItems) do
    FLists[FListCount].Items[LI] := AItems[LI];
  Inc(FListCount);
end;

procedure TTemplateContext.RegisterFunc(const AName: string; AFunc: TTemplateFunc);
begin
  if not Assigned(AFunc) then
    raise EArgumentError.Create('TTemplateContext.RegisterFunc: function must not be nil');
  if FFuncCount >= Length(FFuncs) then
    SetLength(FFuncs, FFuncCount + 4);
  FFuncs[FFuncCount].Name := AName;
  FFuncs[FFuncCount].Func := AFunc;
  Inc(FFuncCount);
end;

procedure TTemplateContext.SetPrefix(const AValue: string);
begin
  FPrefix := AValue;
end;

procedure TTemplateContext.Define(const AName, ABody: string);
var
  LI: Integer;
begin
  for LI := 0 to FDefineCount - 1 do
    if FDefines[LI].Name = AName then
    begin
      FDefines[LI].Body := ABody;
      Exit;
    end;
  if FDefineCount >= Length(FDefines) then
    SetLength(FDefines, FDefineCount + 4);
  FDefines[FDefineCount].Name := AName;
  FDefines[FDefineCount].Body := ABody;
  Inc(FDefineCount);
end;

function TTemplateContext.GetDefine(const AName: string): string;
var
  LI: Integer;
begin
  for LI := 0 to FDefineCount - 1 do
    if FDefines[LI].Name = AName then
      Exit(FDefines[LI].Body);
  Result := '';
end;

function TTemplateContext.GetVar(const AName: string): string;
var
  LI: Integer;
  LFullName: string;
begin
  { If prefix is set (inside with block), try prefix.name first }
  if FPrefix <> '' then
  begin
    LFullName := FPrefix + '.' + AName;
    for LI := 0 to FVarCount - 1 do
      if FVars[LI].Name = LFullName then
        Exit(FVars[LI].Value);
  end;
  for LI := 0 to FVarCount - 1 do
    if FVars[LI].Name = AName then
      Exit(FVars[LI].Value);
  Result := '';
end;

function TTemplateContext.GetBool(const AName: string): Boolean;
var
  LVal: string;
begin
  LVal := GetVar(AName);
  Result := (LVal <> '') and (LVal <> '0') and (LVal <> 'false') and (LVal <> 'False');
end;

function TTemplateContext.GetList(const AName: string): TStringArray;
var
  LI, LJ: Integer;
begin
  Result := nil;
  for LI := 0 to FListCount - 1 do
    if FLists[LI].Name = AName then
    begin
      SetLength(Result, Length(FLists[LI].Items));
      for LJ := 0 to High(FLists[LI].Items) do
        Result[LJ] := FLists[LI].Items[LJ];
      Exit;
    end;
end;

{ ============================================================================ }
{ TTemplate                                                                     }
{ ============================================================================ }

class function TTemplate.Create(const ASource: string): TTemplate;
begin
  Result.FSource := ASource;
end;

function TTemplate.Render(const ACtx: TTemplateContext): string;
var
  LCtx: TTemplateContext;
  LPos: Integer;
  LStop: TStopReason;
  LLocals: TTemplateVarArray;
  LLocalCount: Integer;
begin
  LCtx := CloneTemplateContext(ACtx);
  LPos := 1;
  LLocalCount := 0;
  SetLength(LLocals, 0);
  Result := RenderSegment(FSource, LPos, LCtx, LLocals, LLocalCount, LStop);
  RejectTopLevelStop(LStop);
end;

function TTemplate.RenderWith(const AVars: array of TTemplateVar): string;
var
  LCtx: TTemplateContext;
  LI: Integer;
begin
  LCtx := TTemplateContext.Create;
  for LI := 0 to High(AVars) do
    LCtx.SetVar(AVars[LI].Name, AVars[LI].Value);
  Result := Render(LCtx);
end;

{ ============================================================================ }
{ Module-level function                                                         }
{ ============================================================================ }

function TemplateRender(const ATemplate: string; const ACtx: TTemplateContext): string;
var
  LTpl: TTemplate;
begin
  LTpl := TTemplate.Create(ATemplate);
  Result := LTpl.Render(ACtx);
end;

end.
