unit nextpas.core.validation;
{**
 * @desc Data validation module — fluent builder API with error collection.
 * @layer L2
 * Zero SysUtils dependency. Collects all errors instead of stopping at first.
 *}

{$I nextpas.core.settings.inc}

interface

type
  TValidationError = record
    Field: string;
    Message: string;
  end;
  TValidationErrors = array of TValidationError;

  TValidator = record
  private
    FField: string;
    FErrors: TValidationErrors;
    FErrorCount: Integer;
    procedure AddError(const AMsg: string);
  public
    class function Create(const AField: string): TValidator; static;
    function Required(const AValue: string): TValidator;
    function MinLen(const AValue: string; AMin: Integer): TValidator;
    function MaxLen(const AValue: string; AMax: Integer): TValidator;
    function MinInt(AValue: Int64; AMin: Int64): TValidator;
    function MaxInt(AValue: Int64; AMax: Int64): TValidator;
    function RangeInt(AValue: Int64; AMin, AMax: Int64): TValidator;
    function Email(const AValue: string): TValidator;
    function NotEmpty(const AValue: string): TValidator;
    function Matches(const AValue, APattern: string): TValidator;
    function OneOf(const AValue: string; const AOptions: array of string): TValidator;
    function Custom(AValid: Boolean; const AMsg: string): TValidator;
    function IsValid: Boolean;
    function Errors: TValidationErrors;
    function FirstError: string;
  end;

  TValidationResult = record
  private
    FErrors: TValidationErrors;
    FErrorCount: Integer;
  public
    class function Create: TValidationResult; static;
    procedure Add(const AValidator: TValidator);
    procedure AddError(const AField, AMsg: string);
    function IsValid: Boolean;
    function Errors: TValidationErrors;
    function ErrorCount: Integer;
    function ErrorMessages: string;
  end;

implementation

{ --- Internal helpers --- }

function IntToStrSimple(V: Int64): string;
var
  Neg: Boolean;
  Buf: string;
begin
  if V = 0 then begin Result := '0'; Exit; end;
  Neg := V < 0;
  if Neg then V := -V;
  Buf := '';
  while V > 0 do
  begin
    Buf := Char(Ord('0') + (V mod 10)) + Buf;
    V := V div 10;
  end;
  if Neg then Buf := '-' + Buf;
  Result := Buf;
end;

function SimplePatternMatch(const AValue, APattern: string): Boolean;
var
  VI, PI, StarVI, StarPI: Integer;
begin
  VI := 1; PI := 1;
  StarVI := 0; StarPI := 0;
  while VI <= Length(AValue) do
  begin
    if (PI <= Length(APattern)) and ((APattern[PI] = '?') or (APattern[PI] = AValue[VI])) then
    begin
      Inc(VI); Inc(PI);
    end
    else if (PI <= Length(APattern)) and (APattern[PI] = '*') then
    begin
      StarPI := PI; StarVI := VI;
      Inc(PI);
    end
    else if StarPI > 0 then
    begin
      PI := StarPI + 1;
      Inc(StarVI);
      VI := StarVI;
    end
    else
      Exit(False);
  end;
  while (PI <= Length(APattern)) and (APattern[PI] = '*') do
    Inc(PI);
  Result := PI > Length(APattern);
end;

{ --- TValidator --- }

class function TValidator.Create(const AField: string): TValidator;
begin
  Result.FField := AField;
  Result.FErrors := nil;
  Result.FErrorCount := 0;
end;

procedure TValidator.AddError(const AMsg: string);
begin
  Inc(FErrorCount);
  SetLength(FErrors, FErrorCount);
  FErrors[FErrorCount - 1].Field := FField;
  FErrors[FErrorCount - 1].Message := AMsg;
end;

function TValidator.Required(const AValue: string): TValidator;
begin
  if Length(AValue) = 0 then
    AddError('is required');
  Result := Self;
end;

function TValidator.MinLen(const AValue: string; AMin: Integer): TValidator;
begin
  if Length(AValue) < AMin then
    AddError('must be at least ' + IntToStrSimple(AMin) + ' characters');
  Result := Self;
end;

function TValidator.MaxLen(const AValue: string; AMax: Integer): TValidator;
begin
  if Length(AValue) > AMax then
    AddError('must be at most ' + IntToStrSimple(AMax) + ' characters');
  Result := Self;
end;

function TValidator.MinInt(AValue: Int64; AMin: Int64): TValidator;
begin
  if AValue < AMin then
    AddError('must be at least ' + IntToStrSimple(AMin));
  Result := Self;
end;

function TValidator.MaxInt(AValue: Int64; AMax: Int64): TValidator;
begin
  if AValue > AMax then
    AddError('must be at most ' + IntToStrSimple(AMax));
  Result := Self;
end;

function TValidator.RangeInt(AValue: Int64; AMin, AMax: Int64): TValidator;
begin
  if (AValue < AMin) or (AValue > AMax) then
    AddError('must be between ' + IntToStrSimple(AMin) + ' and ' + IntToStrSimple(AMax));
  Result := Self;
end;

function TValidator.Email(const AValue: string): TValidator;
var
  AtPos, I: Integer;
begin
  AtPos := 0;
  for I := 1 to Length(AValue) do
    if AValue[I] = '@' then
    begin
      AtPos := I;
      Break;
    end;
  if (AtPos < 2) or (AtPos >= Length(AValue)) then
    AddError('must be a valid email address');
  Result := Self;
end;

function TValidator.NotEmpty(const AValue: string): TValidator;
var
  I: Integer;
  HasContent: Boolean;
begin
  HasContent := False;
  for I := 1 to Length(AValue) do
    if (AValue[I] <> ' ') and (AValue[I] <> #9) and (AValue[I] <> #10) and (AValue[I] <> #13) then
    begin
      HasContent := True;
      Break;
    end;
  if not HasContent then
    AddError('must not be empty');
  Result := Self;
end;

function TValidator.Matches(const AValue, APattern: string): TValidator;
begin
  if not SimplePatternMatch(AValue, APattern) then
    AddError('must match pattern "' + APattern + '"');
  Result := Self;
end;

function TValidator.OneOf(const AValue: string; const AOptions: array of string): TValidator;
var
  I: Integer;
  Found: Boolean;
begin
  Found := False;
  for I := 0 to High(AOptions) do
    if AValue = AOptions[I] then
    begin
      Found := True;
      Break;
    end;
  if not Found then
    AddError('must be one of the allowed values');
  Result := Self;
end;

function TValidator.Custom(AValid: Boolean; const AMsg: string): TValidator;
begin
  if not AValid then
    AddError(AMsg);
  Result := Self;
end;

function TValidator.IsValid: Boolean;
begin
  Result := FErrorCount = 0;
end;

function TValidator.Errors: TValidationErrors;
begin
  Result := FErrors;
end;

function TValidator.FirstError: string;
begin
  if FErrorCount > 0 then
    Result := FErrors[0].Message
  else
    Result := '';
end;

{ --- TValidationResult --- }

class function TValidationResult.Create: TValidationResult;
begin
  Result.FErrors := nil;
  Result.FErrorCount := 0;
end;

procedure TValidationResult.Add(const AValidator: TValidator);
var
  VErrors: TValidationErrors;
  I, OldLen: Integer;
begin
  VErrors := AValidator.FErrors;
  if Length(VErrors) = 0 then Exit;
  OldLen := FErrorCount;
  Inc(FErrorCount, Length(VErrors));
  SetLength(FErrors, FErrorCount);
  for I := 0 to High(VErrors) do
    FErrors[OldLen + I] := VErrors[I];
end;

procedure TValidationResult.AddError(const AField, AMsg: string);
begin
  Inc(FErrorCount);
  SetLength(FErrors, FErrorCount);
  FErrors[FErrorCount - 1].Field := AField;
  FErrors[FErrorCount - 1].Message := AMsg;
end;

function TValidationResult.IsValid: Boolean;
begin
  Result := FErrorCount = 0;
end;

function TValidationResult.Errors: TValidationErrors;
begin
  Result := FErrors;
end;

function TValidationResult.ErrorCount: Integer;
begin
  Result := FErrorCount;
end;

function TValidationResult.ErrorMessages: string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to FErrorCount - 1 do
  begin
    if I > 0 then
      Result := Result + '; ';
    Result := Result + FErrors[I].Field + ': ' + FErrors[I].Message;
  end;
end;

end.
