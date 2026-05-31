unit nextpas.core.process.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

type
  { TPipeReader — IReader 包装一个管道 fd (Unix) 或 HANDLE (Windows) }
  TPipeReader = class(TInterfacedObject, IReader)
  private
    FFd: PtrInt;
    FClosed: Boolean;
  public
    constructor Create(const AFd: PtrInt);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Fd: PtrInt read FFd;
  end;

  { TPipeWriter — IWriter 包装一个管道 fd }
  TPipeWriter = class(TInterfacedObject, IWriter)
  private
    FFd: PtrInt;
    FClosed: Boolean;
  public
    constructor Create(const AFd: PtrInt);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
    property Fd: PtrInt read FFd;
  end;

implementation

uses
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  nextpas.core.platform.windows.ffi
  {$ENDIF}
  ;

{ TPipeReader }

constructor TPipeReader.Create(const AFd: PtrInt);
begin
  inherited Create;
  FFd := AFd;
  FClosed := False;
end;

destructor TPipeReader.Destroy;
begin
  if not FClosed then
    Close;
  inherited;
end;

function TPipeReader.Read(var ABuf; const ACount: SizeUInt): SizeUInt;
var
  {$IFDEF NEXTPAS_UNIX}LRead: ssize_t;{$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LRead: DWORD;{$ENDIF}
begin
  if FClosed then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  LRead := nextpas.core.platform.posix.ffi.read(FFd, @ABuf, ACount);
  if LRead <= 0 then Exit(0);
  Result := SizeUInt(LRead);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LRead := 0;
  if not ReadFile(HANDLE(FFd), @ABuf, DWORD(ACount), @LRead, nil) then Exit(0);
  Result := SizeUInt(LRead);
  {$ENDIF}
end;

procedure TPipeReader.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi.close(FFd);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  CloseHandle(HANDLE(FFd));
  {$ENDIF}
end;

{ TPipeWriter }

constructor TPipeWriter.Create(const AFd: PtrInt);
begin
  inherited Create;
  FFd := AFd;
  FClosed := False;
end;

destructor TPipeWriter.Destroy;
begin
  if not FClosed then
    Close;
  inherited;
end;

function TPipeWriter.Write(const ABuf; const ACount: SizeUInt): SizeUInt;
var
  {$IFDEF NEXTPAS_UNIX}LWritten: ssize_t;{$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}LWritten: DWORD;{$ENDIF}
begin
  if FClosed then Exit(0);
  {$IFDEF NEXTPAS_UNIX}
  LWritten := nextpas.core.platform.posix.ffi.write(FFd, @ABuf, ACount);
  if LWritten <= 0 then Exit(0);
  Result := SizeUInt(LWritten);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  LWritten := 0;
  if not WriteFile(HANDLE(FFd), @ABuf, DWORD(ACount), @LWritten, nil) then Exit(0);
  Result := SizeUInt(LWritten);
  {$ENDIF}
end;

procedure TPipeWriter.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  {$IFDEF NEXTPAS_UNIX}
  nextpas.core.platform.posix.ffi.close(FFd);
  {$ENDIF}
  {$IFDEF NEXTPAS_WINDOWS}
  CloseHandle(HANDLE(FFd));
  {$ENDIF}
end;

end.
