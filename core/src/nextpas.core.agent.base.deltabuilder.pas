{**
 * nextpas.core.agent.base.deltabuilder - 流增量构建器（高频解码路径单一真源）。
 *
 * 职责：Count/Cap 分离的几何增长 TStreamDelta 累积器，避免逐个 SetLength
 * 重分配；openai/anthropic/responses 三路解码器共享。
 * 从 base.helpers 拆出（模块化收口），消费方经 agent.base 门面访问。
 *}

unit nextpas.core.agent.base.deltabuilder;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base.types;

type
  PStreamDelta = ^TStreamDelta;

  { 增量构建器（高频解码路径）：Count/Cap 分离的几何增长，避免逐个 SetLength }
  TAgentDeltaBuilder = record
  private
    FItems: TStreamDeltaArray;
    FCount: Integer;
  public
    procedure Init;
    procedure Add(const ADelta: TStreamDelta);
    procedure AddRange(const AArr: TStreamDeltaArray);
    function Take: TStreamDeltaArray; // 截断至 Count 并接管
    function Count: Integer; inline;
    procedure Clear;
    procedure MergeToFirst(const AJson: TJsonText);
    procedure MergeToLast(const AJson: TJsonText);
    function At(AIdx: Integer): PStreamDelta; inline;
    function Get(AIdx: Integer): TStreamDelta; inline;
  end;

implementation

procedure TAgentDeltaBuilder.Init;
begin
  FCount := 0;
  SetLength(FItems, 0);
end;

procedure TAgentDeltaBuilder.Add(const ADelta: TStreamDelta);
var
  LCap: Integer;
begin
  LCap := Length(FItems);
  if FCount >= LCap then
  begin
    if LCap = 0 then
      LCap := 8
    else
      LCap := LCap * 2;
    SetLength(FItems, LCap);
  end;
  FItems[FCount] := ADelta;
  Inc(FCount);
end;

procedure TAgentDeltaBuilder.AddRange(const AArr: TStreamDeltaArray);
var
  LNeed, LCap, I: Integer;
begin
  if Length(AArr) = 0 then
    Exit;
  LNeed := FCount + Length(AArr);
  LCap := Length(FItems);
  if LNeed > LCap then
  begin
    if LCap = 0 then
      LCap := 8;
    while LCap < LNeed do
      LCap := LCap * 2;
    SetLength(FItems, LCap);
  end;
  for I := 0 to High(AArr) do
  begin
    FItems[FCount] := AArr[I];
    Inc(FCount);
  end;
end;

function TAgentDeltaBuilder.Take: TStreamDeltaArray;
begin
  SetLength(FItems, FCount);
  Result := FItems;
  FItems := nil;
  FCount := 0;
end;

function TAgentDeltaBuilder.Count: Integer;
begin
  Result := FCount;
end;

procedure TAgentDeltaBuilder.Clear;
begin
  FCount := 0;
  // 保留容量以复用
end;

procedure TAgentDeltaBuilder.MergeToFirst(const AJson: TJsonText);
begin
  if (FCount > 0) and (AJson <> '') then
    FItems[0].UnmappedJson := nextpas.core.agent.base.types.MergeExtraJson([FItems[0].UnmappedJson, AJson]);
end;

procedure TAgentDeltaBuilder.MergeToLast(const AJson: TJsonText);
begin
  if (FCount > 0) and (AJson <> '') then
    FItems[FCount - 1].UnmappedJson := nextpas.core.agent.base.types.MergeExtraJson([FItems[FCount - 1].UnmappedJson, AJson]);
end;

function TAgentDeltaBuilder.At(AIdx: Integer): PStreamDelta;
begin
  Result := @FItems[AIdx];
end;

function TAgentDeltaBuilder.Get(AIdx: Integer): TStreamDelta;
begin
  Result := FItems[AIdx];
end;

end.
