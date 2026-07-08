unit DateUtils;

{$mode objfpc}{$H+}

interface

uses SysUtils;

function DateTimeToUnix(const AValue: TDateTime): Int64;
function UnixToDateTime(const AValue: Int64): TDateTime;
function DateOf(const AValue: TDateTime): TDateTime;
function TimeOf(const AValue: TDateTime): TDateTime;
function IncSecond(const AValue: TDateTime; const ANumberOfSeconds: Int64 = 1): TDateTime;

implementation

function DateTimeToUnix(const AValue: TDateTime): Int64;
begin
  Result := Round((AValue - 25569.0) * 86400.0);
end;

function UnixToDateTime(const AValue: Int64): TDateTime;
begin
  Result := AValue / 86400.0 + 25569.0;
end;

function DateOf(const AValue: TDateTime): TDateTime;
begin
  Result := Trunc(AValue);
end;

function TimeOf(const AValue: TDateTime): TDateTime;
begin
  Result := Frac(AValue);
end;

function IncSecond(const AValue: TDateTime; const ANumberOfSeconds: Int64 = 1): TDateTime;
begin
  Result := AValue + ANumberOfSeconds / 86400.0;
end;

end.
