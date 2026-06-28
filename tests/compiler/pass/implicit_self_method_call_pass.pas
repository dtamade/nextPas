program implicit_self_method_call_pass;

{$mode objfpc}{$H+}

type
  IRequest = interface
    ['{33333333-3333-3333-3333-333333333333}']
  end;

  TRequest = class(TInterfacedObject, IRequest)
  end;

  TClient = class
  public
    function Send(const AReq: IRequest): Integer;
    function Post(const AReq: IRequest): Integer;
  end;

function TClient.Send(const AReq: IRequest): Integer;
begin
  if AReq = nil then
    Exit(0);
  Result := 9;
end;

function TClient.Post(const AReq: IRequest): Integer;
begin
  Result := Send(AReq);
end;

var
  Client: TClient;
  Request: IRequest;
begin
  Client := TClient.Create;
  Request := TRequest.Create;
  if Client.Post(Request) <> 9 then
    Halt(1);
  Client.Free;
end.
