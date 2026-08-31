{**
 * nextpas.core.agent.provider.common.slots - 工具槽池与流式/装饰器公共基建。
 *
 * 职责：TWireToolSlotPool（跨 chunk index 分桶）、TWireBackedCompletion
 *   （wire 流→词表增量）、TProviderFailure/TFirstGateCompletion（重试/fallback
 *   共享）、取消令牌合并、AddStreamDelta 等。单角色独占，不跨消息复用。
 *   与 wire/extra 互不循环，仅向下依赖 base/errors/intf/async。
 *
 * 属 provider.common 三象限拆分之一（slots），与 wire/extra/facade 互不循环。
 *}

unit nextpas.core.agent.provider.common.slots;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.log.intf,
  nextpas.core.async.cancellation,
  nextpas.core.text.builder,
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf;

type
  { 工具槽：跨 chunk 的 index 分桶缓冲 }
  TWireToolSlot = record
    Index: Integer;
    Id: string;
    Name: string;
    Args: IStringBuilder;
    Announced: Boolean;
  end;

  { 槽池：单角色独占，不跨消息复用 }
  TWireToolSlotPool = class(TInterfacedObject)
  private
    FSlots: array of TWireToolSlot;
    FReg: TAgentSlotRegistry;
    function GetAnnounced(ASlot: Integer): Boolean;
    function GetHasName(ASlot: Integer): Boolean;
  public
    function Find(AIdx: Integer; out ACreated: Boolean): Integer;
    function Count: Integer;
    procedure UpdateIdentity(ASlot: Integer; const AId, AName: string);
    procedure AppendArgs(ASlot: Integer; const AFrag: string);
    property Announced[ASlot: Integer]: Boolean read GetAnnounced;
    property HasName[ASlot: Integer]: Boolean read GetHasName;
    procedure Announce(ASlot: Integer; var ADeltas: TStreamDeltaArray);
    procedure AnnounceBuilder(ASlot: Integer; var ABuilder: TAgentDeltaBuilder);
    procedure FlushUnannounced(const ALog: ILogger; const ASrc: string;
      var ADeltas: TStreamDeltaArray);
    procedure FlushUnannouncedBuilder(const ALog: ILogger; const ASrc: string;
      var ABuilder: TAgentDeltaBuilder);
    destructor Destroy; override;
  end;

  { 线背完成对象（两适配器共用）：wire 流事件→decoder 归约→词表增量 }
  TWireBackedCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FStream: IAgentWireStream;
    FDecoder: IAgentWireDecoder;
    FToken: IAsyncCancellationToken;
    FProviderName: string;
    FPendingBuilder: TAgentDeltaBuilder;
    FIdx: Integer;
    FAccumBuilder: TAgentDeltaBuilder;
    FSourceDone: Boolean;
    FFolded: Boolean;
    FCancelled: Boolean;
    FMsg: TMessage;
    FErrMsg: string;
    FErrCode: TAgentErrorCode;
    FErrAfterMs: Int64;
    procedure AppendDeltas(const AArr: TStreamDeltaArray);
    procedure CloseOnce;
  public
    constructor Create(const AStream: IAgentWireStream;
      const ADecoder: IAgentWireDecoder;
      const AToken: IAsyncCancellationToken;
      const AProviderName: string);
    destructor Destroy; override;
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

  { 失败快照：异常实例生命周期限于 handler，出块后按快照重建等价异常 }
  TProviderFailure = record
    Code: TAgentErrorCode;
    Msg: string;
    RetryAfterMs: Int64;
    Provider: string;
    RequestId: string;
    RawBodySnippet: string;
    procedure Capture(const AErr: EAgentError);
    function Rebuild: EAgentError;
  end;

  { 流式首 delta 门：装饰器已替消费方拉走首个增量，回放后透传其余 }
  TFirstGateCompletion = class(TInterfacedObject, IAgentCompletion)
  private
    FInner: IAgentCompletion;
    FFirst: TStreamDelta;
    FHasFirst: Boolean;
  public
    constructor Create(const AInner: IAgentCompletion;
      const AFirst: TStreamDelta; AHasFirst: Boolean);
    function NextDelta(out ADelta: TStreamDelta): Boolean;
    procedure Cancel;
    function GetCancelled: Boolean;
    function GetMessage: TMessage;
    function GetUsage: TTokenUsage;
  end;

{ 词表增量追加（容量倍增由 SetLength 摊还；两适配器与槽池共用）}
procedure AddStreamDelta(var AArr: TStreamDeltaArray;
  const AD: TStreamDelta); inline;

{ 环境令牌与调用令牌合并：调用令牌优先，皆空返回 nil }
function MergeCancellationTokens(
  const AAmbient, ACall: IAsyncCancellationToken): IAsyncCancellationToken;

{ 令牌已取消即抛 EAgentCancelled }
procedure RequireNotCancelled(const AToken: IAsyncCancellationToken);

implementation

uses
  nextpas.core.exception,
  nextpas.core.text.conv,
  nextpas.core.agent.fold;

procedure AddStreamDelta(var AArr: TStreamDeltaArray;
  const AD: TStreamDelta); inline;
begin
  AgentAppendDelta(AArr, AD);
end;

function TWireToolSlotPool.GetAnnounced(ASlot: Integer): Boolean;
begin
  Result := FSlots[ASlot].Announced;
end;

function TWireToolSlotPool.GetHasName(ASlot: Integer): Boolean;
begin
  Result := FSlots[ASlot].Name <> '';
end;

destructor TWireToolSlotPool.Destroy;
begin
  SetLength(FSlots, 0);
  FReg.Clear;
  inherited Destroy;
end;

function TWireToolSlotPool.Find(AIdx: Integer;
  out ACreated: Boolean): Integer;
var
  LPos: Integer;
begin
  if AIdx < 0 then
    raise EAgentError.CreateLocal(aecProtocol,
      'tool slot index <0: ' + nextpas.core.text.conv.IntToStr(AIdx));
  if FReg.TryFind(AIdx, LPos) then
  begin
    Result := LPos;
    ACreated := False;
    Exit;
  end;
  if FReg.Count > CAgentMaxSlotMap then
    raise EAgentError.CreateLocal(aecProtocol,
      'tool slot count exceeds ' + nextpas.core.text.conv.IntToStr(CAgentMaxSlotMap));
  Result := Length(FSlots);
  SetLength(FSlots, Result + 1);
  FSlots[Result] := Default(TWireToolSlot);
  FSlots[Result].Index := AIdx;
  FSlots[Result].Args := MakeStringBuilder(CAgentToolArgsInitialCap);
  FReg.Register(AIdx, Result);
  ACreated := True;
end;

function TWireToolSlotPool.Count: Integer;
begin
  Result := Length(FSlots);
end;

procedure TWireToolSlotPool.UpdateIdentity(ASlot: Integer;
  const AId, AName: string);
begin
  if (AId <> '') and (FSlots[ASlot].Id = '') then
    FSlots[ASlot].Id := AId;
  if (not FSlots[ASlot].Announced) and (AName <> '') then
    FSlots[ASlot].Name := AName;
end;

procedure TWireToolSlotPool.AppendArgs(ASlot: Integer; const AFrag: string);
begin
  if AFrag <> '' then
    FSlots[ASlot].Args.AppendStr(AFrag);
end;

procedure TWireToolSlotPool.Announce(ASlot: Integer;
  var ADeltas: TStreamDeltaArray);
var
  LD: TStreamDelta;
begin
  LD := Default(TStreamDelta);
  LD.Kind := sdkToolCallStart;
  LD.ToolIndex := FSlots[ASlot].Index;
  LD.ToolCallId := FSlots[ASlot].Id;
  LD.ToolName := FSlots[ASlot].Name;
  AddStreamDelta(ADeltas, LD);
  if FSlots[ASlot].Args.Len > 0 then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := FSlots[ASlot].Index;
    LD.ArgumentsDelta := FSlots[ASlot].Args.ToString;
    AddStreamDelta(ADeltas, LD);
  end;
  FSlots[ASlot].Announced := True;
end;

procedure TWireToolSlotPool.AnnounceBuilder(ASlot: Integer;
  var ABuilder: TAgentDeltaBuilder);
var
  LD: TStreamDelta;
begin
  LD := Default(TStreamDelta);
  LD.Kind := sdkToolCallStart;
  LD.ToolIndex := FSlots[ASlot].Index;
  LD.ToolCallId := FSlots[ASlot].Id;
  LD.ToolName := FSlots[ASlot].Name;
  ABuilder.Add(LD);
  if FSlots[ASlot].Args.Len > 0 then
  begin
    LD := Default(TStreamDelta);
    LD.Kind := sdkToolCallDelta;
    LD.ToolIndex := FSlots[ASlot].Index;
    LD.ArgumentsDelta := FSlots[ASlot].Args.ToString;
    ABuilder.Add(LD);
  end;
  FSlots[ASlot].Announced := True;
end;

procedure TWireToolSlotPool.FlushUnannounced(const ALog: ILogger;
  const ASrc: string; var ADeltas: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(FSlots) do
    if (not FSlots[I].Announced) and
       ((FSlots[I].Id <> '') or (FSlots[I].Name <> '') or
        (FSlots[I].Args.Len > 0)) then
    begin
      if ALog <> nil then
        ALog.Warn(ASrc + ': flushing tool call slot ' +
          nextpas.core.text.conv.IntToStr(FSlots[I].Index) + ' whose name never arrived');
      Announce(I, ADeltas);
    end;
end;

procedure TWireToolSlotPool.FlushUnannouncedBuilder(const ALog: ILogger;
  const ASrc: string; var ABuilder: TAgentDeltaBuilder);
var
  I: Integer;
begin
  for I := 0 to High(FSlots) do
    if (not FSlots[I].Announced) and
       ((FSlots[I].Id <> '') or (FSlots[I].Name <> '') or
        (FSlots[I].Args.Len > 0)) then
    begin
      if ALog <> nil then
        ALog.Warn(ASrc + ': flushing tool call slot ' +
          nextpas.core.text.conv.IntToStr(FSlots[I].Index) + ' whose name never arrived');
      AnnounceBuilder(I, ABuilder);
    end;
end;

constructor TWireBackedCompletion.Create(const AStream: IAgentWireStream;
  const ADecoder: IAgentWireDecoder;
  const AToken: IAsyncCancellationToken;
  const AProviderName: string);
begin
  inherited Create;
  FStream := AStream;
  FDecoder := ADecoder;
  FToken := AToken;
  FProviderName := AProviderName;
  FIdx := 0;
  FPendingBuilder.Init;
  FAccumBuilder.Init;
end;

destructor TWireBackedCompletion.Destroy;
var
  LArr: TStreamDeltaArray;
begin
  if not FFolded then
  begin
    try
      if (FDecoder <> nil) and not FSourceDone then
      begin
        try
          FDecoder.Finalize(LArr);
          AppendDeltas(LArr);
        except
          on E: EAgentError do
          begin
            if FErrMsg = '' then
            begin
              FErrMsg := E.Message;
              FErrCode := E.ErrorCode;
              FErrAfterMs := E.RetryAfterMs;
            end;
          end;
          on E: Exception do
          begin
            if FErrMsg = '' then
            begin
              FErrMsg := E.Message;
              FErrCode := aecProtocol;
              FErrAfterMs := CRetryAfterUnknown;
            end;
          end;
        end;
        try
          CloseOnce;
        except
        end;
      end;
    except
    end;
  end;
  if not FSourceDone then
    Cancel;
  inherited Destroy;
end;

procedure TWireBackedCompletion.AppendDeltas(const AArr: TStreamDeltaArray);
var
  I: Integer;
begin
  for I := 0 to High(AArr) do
  begin
    if AArr[I].Kind = sdkError then
    begin
      if FErrMsg = '' then
      begin
        FErrMsg := AArr[I].Error.Message;
        FErrCode := AArr[I].Error.Code;
        FErrAfterMs := AArr[I].Error.RetryAfterMs;
      end;
      Continue;
    end;
    FAccumBuilder.Add(AArr[I]);
    FPendingBuilder.Add(AArr[I]);
  end;
end;

procedure TWireBackedCompletion.CloseOnce;
var
  LArr: TStreamDeltaArray;
begin
  if FFolded then
    Exit;
  FFolded := True;
  LArr := FAccumBuilder.Take;
  FoldDeltas(LArr, FMsg);
end;

function TWireBackedCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
var
  LEv: TWireSSEEvent;
  LArr: TStreamDeltaArray;
begin
  if FCancelled then
    Exit(False);
  if Assigned(FToken) and FToken.IsCancelled then
  begin
    Cancel;
    Exit(False);
  end;
  while FIdx >= FPendingBuilder.Count do
  begin
    if FSourceDone then
    begin
      CloseOnce;
      Exit(False);
    end;
    if FStream.NextEvent(LEv) then
    begin
      FDecoder.DecodeEvent(LEv, LArr);
      AppendDeltas(LArr);
    end
    else
    begin
      FSourceDone := True;
      FDecoder.Finalize(LArr);
      AppendDeltas(LArr);
    end;
  end;
  ADelta := FPendingBuilder.Get(FIdx);
  Inc(FIdx);
  Result := True;
end;

procedure TWireBackedCompletion.Cancel;
begin
  FCancelled := True;
  FStream.Cancel;
end;

function TWireBackedCompletion.GetCancelled: Boolean;
begin
  Result := FCancelled or FStream.GetCancelled;
end;

function TWireBackedCompletion.GetMessage: TMessage;
var
  E: EAgentError;
begin
  if not FFolded then
    raise EAgentError.CreateLocal(aecProtocol,
      'completion not drained — drain NextDelta until False before GetMessage');
  if FErrMsg <> '' then
  begin
    E := EAgentError.CreateUpstream(FErrCode, FProviderName, FErrMsg,
      '', '', FErrAfterMs);
    raise E;
  end;
  Result := FMsg;
end;

function TWireBackedCompletion.GetUsage: TTokenUsage;
begin
  if not FFolded then
    raise EAgentError.CreateLocal(aecProtocol,
      'completion not drained — drain NextDelta until False before GetUsage');
  Result := FMsg.Usage;
end;

procedure TProviderFailure.Capture(const AErr: EAgentError);
begin
  Code := AErr.ErrorCode;
  Msg := AErr.Message;
  RetryAfterMs := AErr.RetryAfterMs;
  Provider := AErr.Provider;
  RequestId := AErr.RequestId;
  RawBodySnippet := AErr.RawBodySnippet;
end;

function TProviderFailure.Rebuild: EAgentError;
begin
  if Provider <> '' then
    Result := EAgentError.CreateUpstream(Code, Provider, Msg,
      RequestId, RawBodySnippet, RetryAfterMs)
  else
    Result := EAgentError.CreateLocal(Code, Msg);
end;

constructor TFirstGateCompletion.Create(const AInner: IAgentCompletion;
  const AFirst: TStreamDelta; AHasFirst: Boolean);
begin
  inherited Create;
  FInner := AInner;
  FFirst := AFirst;
  FHasFirst := AHasFirst;
end;

function TFirstGateCompletion.NextDelta(out ADelta: TStreamDelta): Boolean;
begin
  if FHasFirst then
  begin
    FHasFirst := False;
    ADelta := FFirst;
    Exit(True);
  end;
  Result := FInner.NextDelta(ADelta);
end;

procedure TFirstGateCompletion.Cancel;
begin
  FInner.Cancel;
end;

function TFirstGateCompletion.GetCancelled: Boolean;
begin
  Result := FInner.GetCancelled;
end;

function TFirstGateCompletion.GetMessage: TMessage;
begin
  Result := FInner.GetMessage;
end;

function TFirstGateCompletion.GetUsage: TTokenUsage;
begin
  Result := FInner.GetUsage;
end;

function MergeCancellationTokens(
  const AAmbient, ACall: IAsyncCancellationToken): IAsyncCancellationToken;
begin
  if ACall <> nil then
    Exit(ACall);
  Result := AAmbient;
end;

procedure RequireNotCancelled(const AToken: IAsyncCancellationToken);
begin
  if (AToken <> nil) and AToken.IsCancelled then
    raise EAgentCancelled.Create;
end;

end.
