unit nextpas.core.time.timezone;

{$I nextpas.core.settings.inc}

interface

type
  TUtcOffset = record
  private
    FSeconds: Int32;
  public
    class function UTC: TUtcOffset; static; inline;
    class function FromHoursMinutes(const AHours, AMinutes: Integer): TUtcOffset; static;
    class function FromSeconds(const ASeconds: Int32): TUtcOffset; static; inline;
    class function Local: TUtcOffset; static;
    function TotalSeconds: Int32; inline;
    function TotalMinutes: Int32; inline;
    function Hours: Integer; inline;
    function Minutes: Integer; inline;
    function IsUtc: Boolean; inline;
    function ToString: string;
    class operator =(const A, B: TUtcOffset): Boolean; inline;
  end;

implementation

uses
  nextpas.core.errors,
  nextpas.core.platform.time;

class function TUtcOffset.UTC: TUtcOffset;
begin
  Result.FSeconds := 0;
end;

class function TUtcOffset.FromHoursMinutes(const AHours, AMinutes: Integer): TUtcOffset;
var
  LTotal: Int32;
begin
  LTotal := AHours * 3600 + AMinutes * 60;
  if (LTotal < -64800) or (LTotal > 64800) then
    raise EArgumentError.Create('TUtcOffset: offset out of range (-18h..+18h)');
  Result.FSeconds := LTotal;
end;

class function TUtcOffset.FromSeconds(const ASeconds: Int32): TUtcOffset;
begin
  Result.FSeconds := ASeconds;
end;

class function TUtcOffset.Local: TUtcOffset;
begin
  Result.FSeconds := platform_utc_offset_seconds;
end;

function TUtcOffset.TotalSeconds: Int32;
begin
  Result := FSeconds;
end;

function TUtcOffset.TotalMinutes: Int32;
begin
  Result := FSeconds div 60;
end;

function TUtcOffset.Hours: Integer;
begin
  Result := FSeconds div 3600;
end;

function TUtcOffset.Minutes: Integer;
begin
  Result := (System.Abs(FSeconds) mod 3600) div 60;
end;

function TUtcOffset.IsUtc: Boolean;
begin
  Result := FSeconds = 0;
end;

function TUtcOffset.ToString: string;
var
  LH, LM: Integer;
  LSign: Char;
begin
  if FSeconds = 0 then
    Exit('Z');
  if FSeconds > 0 then
    LSign := '+'
  else
    LSign := '-';
  LH := System.Abs(FSeconds) div 3600;
  LM := (System.Abs(FSeconds) mod 3600) div 60;
  Result := LSign + Chr(Ord('0') + LH div 10) + Chr(Ord('0') + LH mod 10)
    + ':' + Chr(Ord('0') + LM div 10) + Chr(Ord('0') + LM mod 10);
end;

class operator TUtcOffset.=(const A, B: TUtcOffset): Boolean;
begin
  Result := A.FSeconds = B.FSeconds;
end;

end.
