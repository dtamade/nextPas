{**
 * nextpas.core.agent.loop.run - Loop 执行结果承载。
 *
 * 职责：IAgentLoopRun 的具体实现 TLoopRun，零 IO，纯数据持有与用量累积。
 * 被 loop.impl 聚合使用，与 loop.types/budget/exec 正交。
 *}

unit nextpas.core.agent.loop.run;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base,
  nextpas.core.agent.errors,
  nextpas.core.agent.intf,
  nextpas.core.agent.loop.types,
  nextpas.core.agent.loop.budget;

type
  TLoopRun = class(TInterfacedObject, IAgentLoopRun)
  private
    FOutcome: TLoopOutcome;
    FFinal: TMessage;
    FHasFinal: Boolean;
    FTranscript: TMessageArray;
    FTotal: TTokenUsage;
    FLastError: EAgentError;
  public
    destructor Destroy; override;
    procedure InitUsageUnknowns;
    procedure AccumulateUsage(const AU: TTokenUsage);
    function FinalMessage: TMessage;
    function TryGetFinalMessage(out AMsg: TMessage): Boolean;
    function Transcript: TMessageArray;
    function Outcome: TLoopOutcome;
    function TotalUsage: TTokenUsage;
    function LastError: EAgentError;
    property WOutcome: TLoopOutcome read FOutcome write FOutcome;
    property WFinal: TMessage read FFinal write FFinal;
    property WHasFinal: Boolean read FHasFinal write FHasFinal;
    property WTranscript: TMessageArray read FTranscript write FTranscript;
    property WLastError: EAgentError read FLastError write FLastError;
  end;

implementation

procedure TLoopRun.InitUsageUnknowns;
begin
  LoopInitUsageUnknown(FTotal);
end;

procedure TLoopRun.AccumulateUsage(const AU: TTokenUsage);
begin
  LoopAccumulateUsage(FTotal, AU);
end;

destructor TLoopRun.Destroy;
begin
  FLastError.Free;
  inherited Destroy;
end;

function TLoopRun.FinalMessage: TMessage;
begin
  Result := FFinal;
end;

function TLoopRun.TryGetFinalMessage(out AMsg: TMessage): Boolean;
begin
  AMsg := FFinal;
  Result := FHasFinal;
end;

function TLoopRun.Transcript: TMessageArray;
begin
  Result := Copy(FTranscript, 0, Length(FTranscript));
end;

function TLoopRun.Outcome: TLoopOutcome;
begin
  Result := FOutcome;
end;

function TLoopRun.TotalUsage: TTokenUsage;
begin
  Result := FTotal;
end;

function TLoopRun.LastError: EAgentError;
begin
  Result := FLastError;
end;

end.
