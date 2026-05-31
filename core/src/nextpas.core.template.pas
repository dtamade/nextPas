unit nextpas.core.template;
{**
 * @desc Text template engine (Go text/template simplified).
 *       Supports variable substitution, conditionals, loops, and pipe filters.
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

  TTemplateContext = record
  private
    FVars: TTemplateVarArray;
    FVarCount: Integer;
    FLists: TTemplateListArray;
    FListCount: Integer;
  public
    class function Create: TTemplateContext; static;
    procedure SetVar(const AName, AValue: string);
    procedure SetInt(const AName: string; AValue: Int64);
    procedure SetBool(const AName: string; AValue: Boolean);
    procedure SetList(const AName: string; const AItems: array of string);
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

function ApplyFilter(const AValue, AFilter, AArg: string): string;
begin
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

function EvalExpr(const AExpr: string; const ACtx: TTemplateContext): string;
var
  LParts: array[0..15] of string;
  LPartCount: Integer;
  LI, LStart: Integer;
  LExpr: string;
  LFilter, LArg: string;
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
  Result := ACtx.GetVar(StripDot(TrimInternal(LParts[0])));

  { Apply pipe filters }
  for LI := 1 to LPartCount - 1 do
  begin
    ParseFilter(LParts[LI], LFilter, LArg);
    Result := ApplyFilter(Result, LFilter, LArg);
  end;
end;

function EvalBool(const AExpr: string; const ACtx: TTemplateContext): Boolean;
begin
  Result := ACtx.GetBool(StripDot(TrimInternal(AExpr)));
end;

{ ============================================================================ }
{ Core render engine                                                            }
{ ============================================================================ }

type
  TStopReason = (srNone, srElse, srEnd);

function RenderSegment(const ASrc: string; var APos: Integer;
  const ACtx: TTemplateContext; out AStop: TStopReason): string; forward;

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
      Exit(False);
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

procedure SkipBlock(const ASrc: string; var APos: Integer);
var
  LStop: TStopReason;
begin
  RenderSegment(ASrc, APos, Default(TTemplateContext), LStop);
end;

function RenderSegment(const ASrc: string; var APos: Integer;
  const ACtx: TTemplateContext; out AStop: TStopReason): string;
var
  LLen: Integer;
  LTagStart, LTagEnd: Integer;
  LContent, LKeyword, LExpr: string;
  LResult: string;
  LItems: TStringArray;
  LI, LSavePos: Integer;
  LInnerStop: TStopReason;
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
      AStop := srEnd;
      Exit(LResult);
    end;
    if LKeyword = 'else' then
    begin
      AStop := srElse;
      Exit(LResult);
    end;

    { if/else/end }
    if LKeyword = 'if' then
    begin
      if EvalBool(LExpr, ACtx) then
      begin
        { Render true branch }
        LResult := LResult + RenderSegment(ASrc, APos, ACtx, LInnerStop);
        if LInnerStop = srElse then
        begin
          { Skip false branch }
          RenderSegment(ASrc, APos, ACtx, LInnerStop);
        end;
      end
      else
      begin
        { Skip true branch }
        RenderSegment(ASrc, APos, ACtx, LInnerStop);
        if LInnerStop = srElse then
        begin
          { Render false branch }
          LResult := LResult + RenderSegment(ASrc, APos, ACtx, LInnerStop);
        end;
      end;
    end
    { range }
    else if LKeyword = 'range' then
    begin
      LItems := ACtx.GetList(StripDot(LExpr));
      LSavePos := APos;
      if Length(LItems) = 0 then
      begin
        { Skip body }
        RenderSegment(ASrc, APos, ACtx, LInnerStop);
      end
      else
      begin
        for LI := 0 to High(LItems) do
        begin
          APos := LSavePos;
          TTemplateContext(ACtx).SetVar('.', LItems[LI]);
          LResult := LResult + RenderSegment(ASrc, APos, ACtx, LInnerStop);
        end;
        TTemplateContext(ACtx).SetVar('.', '');
      end;
    end
    else
    begin
      { Variable/expression with pipes }
      LResult := LResult + EvalExpr(LContent, ACtx);
    end;
  end;

  Result := LResult;
end;

{ ============================================================================ }
{ TTemplateContext                                                               }
{ ============================================================================ }

class function TTemplateContext.Create: TTemplateContext;
begin
  Result.FVarCount := 0;
  Result.FListCount := 0;
  SetLength(Result.FVars, 0);
  SetLength(Result.FLists, 0);
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

function TTemplateContext.GetVar(const AName: string): string;
var
  LI: Integer;
begin
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
  LI: Integer;
begin
  for LI := 0 to FListCount - 1 do
    if FLists[LI].Name = AName then
      Exit(FLists[LI].Items);
  Result := nil;
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
  LPos: Integer;
  LStop: TStopReason;
begin
  LPos := 1;
  Result := RenderSegment(FSource, LPos, ACtx, LStop);
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
