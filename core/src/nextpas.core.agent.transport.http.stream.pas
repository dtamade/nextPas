{**
 * nextpas.core.agent.transport.http.stream - HTTP wire streaming.
 *
 * 薄拆自 nextpas.core.agent.transport.http：承载 TWireStream、IReader
 * 逐块喂养、SSE 解析与通道状态；与 core 域为兄弟依赖。
 *}

unit nextpas.core.agent.transport.http.stream;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.base,
  nextpas.core.sync.intf,
  nextpas.core.sync.mutex,
  nextpas.core.stopwatch,
  nextpas.core.thread.base,
  nextpas.core.thread.channel,
  nextpas.core.http.intf,
  nextpas.core.http.client,
  nextpas.core.agent.base,
  nextpas.core.agent.intf;

function NewWireStream(const AProviderName: string;
  const AClient: IHttpClient; const AReq: TWireRequest): IAgentWireStream;

implementation

uses
  nextpas.core.http.base,
  nextpas.core.exception,
  nextpas.core.http.message,
  nextpas.core.agent.provider.common,
  nextpas.core.agent.errors,
  nextpas.core.agent.sse;

const
  CWaitSliceNs = 100 * 1000 * 1000;
  CMaxErrorBodyBytes = nextpas.core.agent.base.CAgentMaxWireTotalHeaderBytes;
  CWireChannelDepth = nextpas.core.agent.base.CAgentMaxSlotMap;

type
  TWireMsgKind = (wmkSSE, wmkStatus, wmkEOF, wmkError);

  TTWireMsg = record
    Kind: TWireMsgKind;
    Event: TWireSSEEvent;
    Status: Integer;
    ErrCode: TAgentErrorCode;
    ErrMsg: string;
  end;

  TWireMsgChannel = specialize TChannel<TTWireMsg>;

function MsgSSE(const AEvent: TWireSSEEvent): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkSSE;
  Result.Event := AEvent;
end;

function MsgStatus(AStatus: Integer): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkStatus;
  Result.Status := AStatus;
end;

function MsgEOF: TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkEOF;
end;

function MsgError(ACode: TAgentErrorCode; const AText: string): TTWireMsg;
begin
  Result := Default(TTWireMsg);
  Result.Kind := wmkError;
  Result.ErrCode := ACode;
  Result.ErrMsg := AText;
end;

function LocalHeadersToArray(const AHeaders: IHttpHeaders): TWireHeaderArray;
var
  LN, LIdx: Integer;
  LArr: TWireHeaderArray;
begin
  LN := AHeaders.Count;
  SetLength(LArr, LN);
  LIdx := 0;
  AHeaders.ForEach(
    procedure(const AName, AValue: string)
    begin
      if LIdx < LN then
      begin
        LArr[LIdx].Name := AName;
        LArr[LIdx].Value := AValue;
        Inc(LIdx);
      end;
    end);
  Result := LArr;
end;

type
  TWireStream = class(TInterfacedObject, IAgentWireStream)
  private type
    TWorker = class(TWorkerThread)
    private
      FStream: TObject;
    public
      constructor Create(const AStream: TObject);
      procedure Execute; override;
    end;
  private
    FProvider: string;
    FClient: IHttpClient;
    FRequest: IHttpRequest;
    FHttpCancel: IHttpCancelToken;
    FChannel: TWireMsgChannel;
    FLock: IMutex;
    FCancelled: Boolean;
    FWorker: TWorker;
    FParser: TSSEParser;
    FStatus: Integer;
    FIsErrorResp: Boolean;
    FDead: Boolean;
    FErrBody: string;
    FDone: Boolean;
    FLastErrCode: TAgentErrorCode;
    FLastErrMsg: string;
    FSw: TStopwatch;
    FLastProgressMs: Int64;
    FReadIdleMs: Int64;
    procedure PushMsg(const AMsg: TTWireMsg);
    procedure DrainParser;
    procedure PushErrorObj(const AErr: EAgentError);
    procedure MapAndPushHttpException(const AErr: EHttpError);
    procedure OnResponseStatus(const AStatus: THttpStatus);
    procedure OnBodyChunk(const AData: PByte; ASize: SizeUInt);
    procedure ExecuteStream;
  public
    constructor Create(const AProviderName: string;
      const AClient: IHttpClient);
    destructor Destroy; override;
    procedure Start(const AReq: TWireRequest);
    function NextEvent(out AEvent: TWireSSEEvent): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
  end;

constructor TWireStream.TWorker.Create(const AStream: TObject);
begin
  inherited Create;
  FStream := AStream;
end;

procedure TWireStream.TWorker.Execute;
begin
  TWireStream(FStream).ExecuteStream;
end;

constructor TWireStream.Create(const AProviderName: string;
  const AClient: IHttpClient);
begin
  inherited Create;
  FProvider := AProviderName;
  FClient := AClient;
end;

destructor TWireStream.Destroy;
begin
  if FWorker <> nil then
  begin
    if FHttpCancel <> nil then
      FHttpCancel.Cancel;
    FWorker.WaitFor;
    FWorker.Free;
    FWorker := nil;
  end;
  if FParser <> nil then
  begin
    FParser.Free;
    FParser := nil;
  end;
  if FChannel <> nil then
  begin
    FChannel.Free;
    FChannel := nil;
  end;
  inherited Destroy;
end;

procedure TWireStream.Start(const AReq: TWireRequest);
var
  B: THttpRequestBuilder;
  I: Integer;
begin
  AgentValidateWireHeaders(AReq.Headers);
  FLock := TMutex.Create;
  try
    FChannel := TWireMsgChannel.Create(CWireChannelDepth);
    FParser := TSSEParser.Create;
    FHttpCancel := NewHttpCancelToken;
    FReadIdleMs := AReq.ReadIdleTimeoutMs;
    FLastProgressMs := 0;
    FSw := TStopwatch.StartNew;
    B := THttpRequestBuilder.Create(hmPost, AReq.Url)
      .ContentType('application/json');
    for I := 0 to High(AReq.Headers) do
      B := B.Header(AReq.Headers[I].Name, AReq.Headers[I].Value);
    if AReq.TotalTimeoutMs <> CTimeoutDefault then
      B := B.Timeout(AReq.TotalTimeoutMs);
    B := B.CancelToken(FHttpCancel)
      .ResponseBodyChunk(@OnBodyChunk)
      .ResponseStatus(@OnResponseStatus)
      .SkipBodyBuffer;
    FRequest := B.Body(AReq.BodyJson).Build;
    FWorker := TWorker.Create(Self);
    FWorker.Start;
  except
    if FParser <> nil then
    begin
      FParser.Free;
      FParser := nil;
    end;
    if FChannel <> nil then
    begin
      FChannel.Free;
      FChannel := nil;
    end;
    FLock := nil;
    FHttpCancel := nil;
    FRequest := nil;
    raise;
  end;
end;

procedure TWireStream.PushMsg(const AMsg: TTWireMsg);
begin
  FChannel.Send(AMsg);
end;

procedure TWireStream.DrainParser;
var
  Ev: TWireSSEEvent;
begin
  while FParser.PopEvent(Ev) do
    PushMsg(MsgSSE(Ev));
end;

procedure TWireStream.PushErrorObj(const AErr: EAgentError);
begin
  try
    PushMsg(MsgError(AErr.ErrorCode, AErr.Message));
  finally
    AErr.Free;
  end;
end;

procedure TWireStream.MapAndPushHttpException(const AErr: EHttpError);
var
  LCode: TAgentErrorCode;
begin
  case AErr.Kind of
    hekTimeout:   LCode := aecTimeout;
    hekCanceled:  LCode := aecCancelled;
    hekProtocol,
    hekParse:     LCode := aecProtocol;
  else
    LCode := aecTransport;
  end;
  PushErrorObj(EAgentError.CreateLocal(LCode,
    'http transport: ' + AErr.Message));
end;

procedure TWireStream.OnResponseStatus(const AStatus: THttpStatus);
begin
  FLastProgressMs := FSw.ElapsedMs;
  FStatus := Integer(AStatus);
  FIsErrorResp := (FStatus < 200) or (FStatus > 299);
  PushMsg(MsgStatus(FStatus));
end;

procedure TWireStream.OnBodyChunk(const AData: PByte; ASize: SizeUInt);
begin
  FLastProgressMs := FSw.ElapsedMs;
  if FDead then
    Exit;
  if FIsErrorResp then
  begin
    if Length(FErrBody) < CMaxErrorBodyBytes then
    begin
      SetLength(FErrBody, Length(FErrBody) + SizeInt(ASize));
      Move(AData^, PAnsiChar(@FErrBody[Length(FErrBody) - SizeInt(ASize) + 1])^,
        ASize);
    end;
    Exit;
  end;
  try
    FParser.Feed(TByteSpan.Create(AData, ASize));
    DrainParser;
  except
    on E: EAgentError do
    begin
      FDead := True;
      PushErrorObj(EAgentError.CreateLocal(aecProtocol, E.Message));
    end;
  end;
end;

procedure TWireStream.ExecuteStream;
var
  LResp: IHttpResponse;
  LHdrs: TWireHeaderArray;
begin
  LHdrs := nil;
  try
    LResp := FClient.Send(FRequest);
    try
      if FIsErrorResp then
      begin
        LHdrs := LocalHeadersToArray(LResp.Headers);
        PushErrorObj(BuildUpstreamError(FProvider, FErrBody, FStatus, LHdrs));
      end
      else
      begin
        FParser.Finish;
        DrainParser;
        PushMsg(MsgEOF);
      end;
    finally
      LResp.Close;
      LResp := nil;
    end;
  except
    on HE: EHttpError do
      MapAndPushHttpException(HE);
    on E: Exception do
      PushErrorObj(EAgentError.CreateLocal(aecTransport,
        'http transport: ' + E.Message));
  end;
end;

function TWireStream.NextEvent(out AEvent: TWireSSEEvent): Boolean;
var
  LMsg: TTWireMsg;
begin
  if FDone then
  begin
    if FLastErrCode <> aecNone then
      raise EAgentError.CreateLocal(FLastErrCode, FLastErrMsg);
    Exit(False);
  end;
  while True do
  begin
    if (FChannel <> nil) and FChannel.ReceiveTimeout(LMsg, CWaitSliceNs) then
    begin
      case LMsg.Kind of
        wmkSSE:
          begin
            if GetCancelled then
            begin
              FDone := True;
              Exit(False);
            end;
            AEvent := LMsg.Event;
            Exit(True);
          end;
        wmkStatus:
          Continue;
        wmkEOF:
          begin
            FDone := True;
            Exit(False);
          end;
        wmkError:
          begin
            if (LMsg.ErrCode = aecCancelled) and GetCancelled then
            begin
              FDone := True;
              Exit(False);
            end;
            FDone := True;
            FLastErrCode := LMsg.ErrCode;
            FLastErrMsg := LMsg.ErrMsg;
            raise EAgentError.CreateLocal(LMsg.ErrCode, LMsg.ErrMsg);
          end;
      end;
    end;
    if GetCancelled then
    begin
      FDone := True;
      Exit(False);
    end;
    if (FReadIdleMs > CTimeoutDefault) and
       ((FSw.ElapsedMs - FLastProgressMs) > FReadIdleMs) then
    begin
      FDone := True;
      FLastErrCode := aecTimeout;
      FLastErrMsg := 'wire: no stream data for ' +
        IntToStr(FReadIdleMs) + 'ms (read idle timeout)';
      if FHttpCancel <> nil then
        FHttpCancel.Cancel;
      if FChannel <> nil then
        FChannel.Close;
      raise EAgentError.CreateLocal(FLastErrCode, FLastErrMsg);
    end;
  end;
end;

procedure TWireStream.Cancel;
begin
  if FLock = nil then
  begin
    FCancelled := True;
    if FHttpCancel <> nil then
      FHttpCancel.Cancel;
    if FChannel <> nil then
      FChannel.Close;
    Exit;
  end;
  FLock.Acquire;
  try
    FCancelled := True;
  finally
    FLock.Release;
  end;
  if FHttpCancel <> nil then
    FHttpCancel.Cancel;
  if FChannel <> nil then
    FChannel.Close;
end;

function TWireStream.GetCancelled: Boolean;
begin
  if FLock = nil then
    Exit(FCancelled);
  FLock.Acquire;
  try
    Result := FCancelled;
  finally
    FLock.Release;
  end;
end;

function NewWireStream(const AProviderName: string;
  const AClient: IHttpClient; const AReq: TWireRequest): IAgentWireStream;
var
  LStream: TWireStream;
begin
  LStream := TWireStream.Create(AProviderName, AClient);
  try
    LStream.Start(AReq);
  except
    LStream.Free;
    raise;
  end;
  Result := LStream;
end;

end.
