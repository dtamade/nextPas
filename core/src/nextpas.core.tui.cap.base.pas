unit nextpas.core.tui.cap.base;

{$I nextpas.core.settings.inc}

interface

type
  TTuiCapabilityTier = (tctCore, tctExtended, tctExperimental, tctFullOnly);

  TTuiCapabilityPolicy = (tcpAuto, tcpEnable, tcpDisable, tcpRequire);

  TTuiCapabilityStatus = record
    Requested: Boolean;
    Detected: Boolean;
    Active: Boolean;
    Verified: Boolean;
    FallbackReason: AnsiString;

    class function Create(ARequested, ADetected, AActive, AVerified: Boolean;
      const AFallbackReason: AnsiString): TTuiCapabilityStatus; static;
  end;

implementation

class function TTuiCapabilityStatus.Create(ARequested, ADetected, AActive,
  AVerified: Boolean; const AFallbackReason: AnsiString): TTuiCapabilityStatus;
begin
  Result.Requested := ARequested;
  Result.Detected := ADetected;
  Result.Active := AActive;
  Result.Verified := AVerified;
  Result.FallbackReason := AFallbackReason;
end;

end.
