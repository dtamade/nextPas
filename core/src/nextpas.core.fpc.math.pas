unit nextpas.core.fpc.math;

{$I nextpas.core.settings.inc}

interface

function Min(A, B: Integer): Integer; overload; inline;
function Min(A, B: Int64): Int64; overload; inline;
function Max(A, B: Integer): Integer; overload; inline;
function Max(A, B: Int64): Int64; overload; inline;
function EnsureRange(AValue, AMin, AMax: Integer): Integer; overload; inline;
function EnsureRange(AValue, AMin, AMax: Int64): Int64; overload; inline;
function InRange(AValue, AMin, AMax: Integer): Boolean; overload; inline;
function InRange(AValue, AMin, AMax: Int64): Boolean; overload; inline;
function Sign(AValue: Integer): Integer; overload; inline;
function Sign(AValue: Int64): Integer; overload; inline;
function IfThen(ACondition: Boolean; ATrue, AFalse: Integer): Integer; overload; inline;
function IfThen(ACondition: Boolean; ATrue, AFalse: Int64): Int64; overload; inline;
function IfThen(ACondition: Boolean; const ATrue, AFalse: string): string; overload; inline;
function IsPowerOfTwo(AValue: Int64): Boolean; inline;
function NextPowerOfTwo(AValue: Int64): Int64;
function CeilDiv(A, B: Integer): Integer; inline;

implementation

function Min(A, B: Integer): Integer;
begin if A < B then Result := A else Result := B; end;

function Min(A, B: Int64): Int64;
begin if A < B then Result := A else Result := B; end;

function Max(A, B: Integer): Integer;
begin if A > B then Result := A else Result := B; end;

function Max(A, B: Int64): Int64;
begin if A > B then Result := A else Result := B; end;

function EnsureRange(AValue, AMin, AMax: Integer): Integer;
begin
  if AValue < AMin then Result := AMin
  else if AValue > AMax then Result := AMax
  else Result := AValue;
end;

function EnsureRange(AValue, AMin, AMax: Int64): Int64;
begin
  if AValue < AMin then Result := AMin
  else if AValue > AMax then Result := AMax
  else Result := AValue;
end;

function InRange(AValue, AMin, AMax: Integer): Boolean;
begin Result := (AValue >= AMin) and (AValue <= AMax); end;

function InRange(AValue, AMin, AMax: Int64): Boolean;
begin Result := (AValue >= AMin) and (AValue <= AMax); end;

function Sign(AValue: Integer): Integer;
begin
  if AValue > 0 then Result := 1
  else if AValue < 0 then Result := -1
  else Result := 0;
end;

function Sign(AValue: Int64): Integer;
begin
  if AValue > 0 then Result := 1
  else if AValue < 0 then Result := -1
  else Result := 0;
end;

function IfThen(ACondition: Boolean; ATrue, AFalse: Integer): Integer;
begin if ACondition then Result := ATrue else Result := AFalse; end;

function IfThen(ACondition: Boolean; ATrue, AFalse: Int64): Int64;
begin if ACondition then Result := ATrue else Result := AFalse; end;

function IfThen(ACondition: Boolean; const ATrue, AFalse: string): string;
begin if ACondition then Result := ATrue else Result := AFalse; end;

function IsPowerOfTwo(AValue: Int64): Boolean;
begin Result := (AValue > 0) and ((AValue and (AValue - 1)) = 0); end;

function NextPowerOfTwo(AValue: Int64): Int64;
begin
  if AValue <= 0 then Exit(1);
  Dec(AValue);
  AValue := AValue or (AValue shr 1);
  AValue := AValue or (AValue shr 2);
  AValue := AValue or (AValue shr 4);
  AValue := AValue or (AValue shr 8);
  AValue := AValue or (AValue shr 16);
  AValue := AValue or (AValue shr 32);
  Result := AValue + 1;
end;

function CeilDiv(A, B: Integer): Integer;
begin Result := (A + B - 1) div B; end;

end.
