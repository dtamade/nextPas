unit nextpas.core.platform.windows.math;

{$I nextpas.core.settings.inc}

interface

function windows_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64; inline;
function windows_qpc_resolution_ns(const AFrequency: UInt64): UInt64; inline;

implementation

const
  WINDOWS_NANOSECONDS_PER_SECOND = UInt64(1000000000);

function windows_mul_div_floor(
  const AValue: UInt64;
  const AMultiplier: UInt64;
  const ADivisor: UInt64): UInt64;
var
  LFactor: UInt64;
  LQuotient: UInt64;
  LRemainder: UInt64;
  LTermQuotient: UInt64;
  LTermRemainder: UInt64;
begin
  if (AValue = 0) or (AMultiplier = 0) then
    Exit(0);
  if ADivisor = 0 then
    Exit(High(UInt64));

  LFactor := AMultiplier;
  LQuotient := 0;
  LRemainder := 0;
  LTermQuotient := AValue div ADivisor;
  LTermRemainder := AValue mod ADivisor;

  while LFactor <> 0 do
  begin
    if (LFactor and UInt64(1)) <> 0 then
    begin
      if LQuotient > High(UInt64) - LTermQuotient then
        Exit(High(UInt64));
      LQuotient := LQuotient + LTermQuotient;

      if LTermRemainder <> 0 then
      begin
        if LRemainder >= ADivisor - LTermRemainder then
        begin
          LRemainder := LRemainder - (ADivisor - LTermRemainder);
          if LQuotient = High(UInt64) then
            Exit(High(UInt64));
          Inc(LQuotient);
        end
        else
          LRemainder := LRemainder + LTermRemainder;
      end;
    end;

    LFactor := LFactor shr 1;
    if LFactor = 0 then
      Break;

    if LTermQuotient > High(UInt64) div 2 then
      LTermQuotient := High(UInt64)
    else
      LTermQuotient := LTermQuotient * 2;

    if LTermRemainder <> 0 then
    begin
      if LTermRemainder >= ADivisor - LTermRemainder then
      begin
        LTermRemainder := LTermRemainder - (ADivisor - LTermRemainder);
        if LTermQuotient <> High(UInt64) then
          Inc(LTermQuotient);
      end
      else
        LTermRemainder := LTermRemainder + LTermRemainder;
    end;
  end;

  Result := LQuotient;
end;

function windows_scale_units(
  const AValue: UInt64;
  const ADivisor: UInt64;
  const AMultiplier: UInt64): UInt64;
var
  LDivisor: UInt64;
  LWhole: UInt64;
  LRem: UInt64;
  LFrac: UInt64;
begin
  if AMultiplier = 0 then
    Exit(0);

  LDivisor := ADivisor;
  if LDivisor = 0 then
    LDivisor := 1;

  LWhole := AValue div LDivisor;
  LRem := AValue mod LDivisor;

  if LWhole > High(UInt64) div AMultiplier then
    Exit(High(UInt64));

  Result := LWhole * AMultiplier;

  if LRem = 0 then
    LFrac := 0
  else if LRem <= High(UInt64) div AMultiplier then
    LFrac := (LRem * AMultiplier) div LDivisor
  else
    LFrac := windows_mul_div_floor(LRem, AMultiplier, LDivisor);

  if Result > High(UInt64) - LFrac then
    Exit(High(UInt64));

  Result := Result + LFrac;
end;

function windows_qpc_to_ns(const ACounter: UInt64; const AFrequency: UInt64): UInt64; inline;
begin
  Result := windows_scale_units(ACounter, AFrequency, WINDOWS_NANOSECONDS_PER_SECOND);
end;

function windows_qpc_resolution_ns(const AFrequency: UInt64): UInt64; inline;
begin
  if AFrequency = 0 then
    Exit(1);
  if AFrequency >= WINDOWS_NANOSECONDS_PER_SECOND then
    Exit(1);
  Result := (WINDOWS_NANOSECONDS_PER_SECOND + AFrequency - 1) div AFrequency;
  if Result = 0 then
    Result := 1;
end;

end.
