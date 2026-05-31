unit nextpas.core.io.reactor.iocp;

{$I nextpas.core.settings.inc}

{$IFDEF NEXTPAS_WINDOWS}
interface

uses
  nextpas.core.platform.windows.base;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TIocpOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opClose
  );

  TIocpReactor = record
  private
    FPort: PtrUInt;
    FMaxEvents: UInt32;
    FRunning: Int32;
  public
    class function Create(AMaxEvents: UInt32 = 64): TIocpReactor; static;
    procedure Close;
    function IsValid: Boolean; inline;

    function AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32; AOffset: Int64;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncAccept(AFd: Int32; AAddr: Pointer; AAddrLen: Pointer; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncConnect(AFd: Int32; AAddr: Pointer; AAddrLen: UInt32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32; AFlags: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;
    function AsyncClose(AFd: Int32;
      ACallback: TIoCompletion; AContext: Pointer = nil): Boolean;

    function Poll: Int32;
    function PollOne: Boolean;
    procedure Run;
    procedure Stop;
    function Flush: Int32;
  end;

implementation

class function TIocpReactor.Create(AMaxEvents: UInt32): TIocpReactor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FPort := 0;
  Result.FMaxEvents := AMaxEvents;
  Result.FRunning := 0;
end;

procedure TIocpReactor.Close;
begin
  FPort := 0;
end;

function TIocpReactor.IsValid: Boolean;
begin
  Result := FPort <> 0;
end;

function TIocpReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncAccept(AFd: Int32; AAddr: Pointer;
  AAddrLen: Pointer; AFlags: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncConnect(AFd: Int32; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.AsyncClose(AFd: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TIocpReactor.Poll: Int32;
begin
  Result := 0;
end;

function TIocpReactor.PollOne: Boolean;
begin
  Result := False;
end;

procedure TIocpReactor.Run;
begin
  { stub }
end;

procedure TIocpReactor.Stop;
begin
  FRunning := 0;
end;

function TIocpReactor.Flush: Int32;
begin
  Result := 0;
end;

end.
{$ELSE}
interface
implementation
end.
{$ENDIF}