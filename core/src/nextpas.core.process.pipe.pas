unit nextpas.core.process.pipe;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.io.intf;

type
  { TPipeReader — IReader 包装一个管道 fd (Unix) 或 HANDLE (Windows) }
  TPipeReader = class(TInterfacedObject, IReader)
  private
    FFd: Int32;
    FClosed: Boolean;
  public
    constructor Create(const AFd: Int32);
    destructor Destroy; override;
    function Read(var ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

  { TPipeWriter — IWriter 包装一个管道 fd }
  TPipeWriter = class(TInterfacedObject, IWriter)
  private
    FFd: Int32;
    FClosed: Boolean;
  public
    constructor Create(const AFd: Int32);
    destructor Destroy; override;
    function Write(const ABuf; const ACount: SizeUInt): SizeUInt;
    procedure Close;
  end;

implementation

uses
  nextpas.core.platform.posix.base,
  nextpas.core.platform.posix.ffi;

{ TPipeReader }

constructor TPipeReader.Create(const AFd: Int32);
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
  LRead: ssize_t;
begin
  if FClosed then Exit(0);
  LRead := nextpas.core.platform.posix.ffi.read(FFd, @ABuf, ACount);
  if LRead <= 0 then Exit(0);
  Result := SizeUInt(LRead);
end;

procedure TPipeReader.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  nextpas.core.platform.posix.ffi.close(FFd);
end;

{ TPipeWriter }

constructor TPipeWriter.Create(const AFd: Int32);
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
  LWritten: ssize_t;
begin
  if FClosed then Exit(0);
  LWritten := nextpas.core.platform.posix.ffi.write(FFd, @ABuf, ACount);
  if LWritten <= 0 then Exit(0);
  Result := SizeUInt(LWritten);
end;

procedure TPipeWriter.Close;
begin
  if FClosed then Exit;
  FClosed := True;
  nextpas.core.platform.posix.ffi.close(FFd);
end;

end.
