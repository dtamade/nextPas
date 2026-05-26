unit nextpas.core.log.intf;

{$I nextpas.core.settings.inc}

interface

type
  TLogLevel = (
    llTrace,
    llDebug,
    llInfo,
    llWarn,
    llError,
    llFatal
  );

  ILogger = interface
    ['{A1B2C3D4-E5F6-7890-ABCD-EF1234567890}']
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

  { TNullLogger - no-op logger, safe default }
  TNullLogger = class(TInterfacedObject, ILogger)
  public
    procedure Log(const ALevel: TLogLevel; const AMessage: string);
    procedure Trace(const AMessage: string);
    procedure Debug(const AMessage: string);
    procedure Info(const AMessage: string);
    procedure Warn(const AMessage: string);
    procedure Error(const AMessage: string);
    procedure Fatal(const AMessage: string);
  end;

function NullLogger: ILogger;

implementation

var
  GNullLogger: ILogger = nil;

function NullLogger: ILogger;
begin
  if GNullLogger = nil then
    GNullLogger := TNullLogger.Create;
  Result := GNullLogger;
end;

{ TNullLogger }

procedure TNullLogger.Log(const ALevel: TLogLevel; const AMessage: string);
begin
end;

procedure TNullLogger.Trace(const AMessage: string);
begin
end;

procedure TNullLogger.Debug(const AMessage: string);
begin
end;

procedure TNullLogger.Info(const AMessage: string);
begin
end;

procedure TNullLogger.Warn(const AMessage: string);
begin
end;

procedure TNullLogger.Error(const AMessage: string);
begin
end;

procedure TNullLogger.Fatal(const AMessage: string);
begin
end;

end.
