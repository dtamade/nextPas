unit nextpas.core.io.reactor.kqueue;

{$I nextpas.core.settings.inc}

{$IFDEF NEXTPAS_MACOS}
interface

uses
  nextpas.core.platform.darwin.base;

type
  TIoCompletion = procedure(AUserData: UInt64; AResult: Int32; AContext: Pointer);

  TKqueueOpKind = (
    opRead,
    opWrite,
    opAccept,
    opConnect,
    opSend,
    opRecv,
    opClose
  );

  TKqueueReactor = record
  private
    FKqFd: Int32;
    FMaxEvents: UInt32;
    FRunning: Int32;
  public
    class function Create(AMaxEvents: UInt32 = 64): TKqueueReactor; static;
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

const
  STUB_MSG = 'kqueue reactor not implemented on this platform';

class function TKqueueReactor.Create(AMaxEvents: UInt32): TKqueueReactor;
begin
  FillChar(Result, SizeOf(Result), 0);
  Result.FKqFd := -1;
  Result.FMaxEvents := AMaxEvents;
  Result.FRunning := 0;
end;

procedure TKqueueReactor.Close;
begin
  FKqFd := -1;
end;

function TKqueueReactor.IsValid: Boolean;
begin
  Result := FKqFd >= 0;
end;

function TKqueueReactor.AsyncRead(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncWrite(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AOffset: Int64; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncAccept(AFd: Int32; AAddr: Pointer;
  AAddrLen: Pointer; AFlags: Int32; ACallback: TIoCompletion;
  AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncConnect(AFd: Int32; AAddr: Pointer;
  AAddrLen: UInt32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncSend(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncRecv(AFd: Int32; ABuf: Pointer; ALen: UInt32;
  AFlags: Int32; ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.AsyncClose(AFd: Int32;
  ACallback: TIoCompletion; AContext: Pointer): Boolean;
begin
  Result := False;
end;

function TKqueueReactor.Poll: Int32;
begin
  Result := 0;
end;

function TKqueueReactor.PollOne: Boolean;
begin
  Result := False;
end;

procedure TKqueueReactor.Run;
begin
  { stub }
end;

procedure TKqueueReactor.Stop;
begin
  FRunning := 0;
end;

function TKqueueReactor.Flush: Int32;
begin
  Result := 0;
end;

end.
{$ELSE}
interface
implementation
end.
{$ENDIF}
