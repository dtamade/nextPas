{**
 * nextpas.core.agent.base.slotmap - 工具槽位索引注册表（单一真源）。
 *
 * 职责：ToolIndex → Pos 的 O(1) 直映 + 稀疏大索引线性回退，
 * 256 阈值由 CAgentMaxSlotMap 统一把守（SECURITY §3）。
 * 从 base.helpers 拆出（模块化收口），消费方经 agent.base 门面访问。
 *}

unit nextpas.core.agent.base.slotmap;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.agent.base.constants;

type
  TAgentSlotMap = array of Integer;

  { 槽位索引注册表（fold/provider 共用单一真源，REUSE）：Map O(1) 直映 + Indexes 几何增长
    的稀疏大索引线性回退，256 阈值由 CAgentMaxSlotMap 统一把守 }
  TAgentSlotRegistry = record
  private
    FMap: TAgentSlotMap;           { ToolIndex → Pos；-1=缺席 }
    FIndexes: array of Integer;    { Pos → ToolIndex 镜像，用于线性回退校验 }
    FCount: Integer;               { 已注册槽位数（=Length(FIndexes) 逻辑长度）}
  public
    procedure Init;
    procedure Clear;               { 保留容量复用 }
    function Count: Integer; inline;
    function TryFind(AIdx: Integer; out APos: Integer): Boolean; // O(1) 命中或 >256 线性回退
    function Register(AIdx: Integer; out APos: Integer): Boolean; // 已存在返回 False+Pos，新增 True+Pos；越限不注册返回 False
    function At(APos: Integer): Integer; inline; // Pos→Idx
  end;

  { 槽位直映表扩容（fold/provider 共用，SECURITY 阈值内）：几何增长减少重分配 }
procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer);

implementation

procedure TAgentSlotRegistry.Init;
begin
  FCount := 0;
  SetLength(FMap, 0);
  SetLength(FIndexes, 0);
end;

procedure TAgentSlotRegistry.Clear;
var
  I: Integer;
begin
  for I := 0 to FCount - 1 do
    if (FIndexes[I] >= 0) and (FIndexes[I] <= CAgentMaxSlotMap) and (FIndexes[I] < Length(FMap)) then
      FMap[FIndexes[I]] := -1;
  FCount := 0;
end;

function TAgentSlotRegistry.Count: Integer;
begin
  Result := FCount;
end;

function TAgentSlotRegistry.TryFind(AIdx: Integer; out APos: Integer): Boolean;
var
  I: Integer;
begin
  if (AIdx >= 0) and (AIdx <= CAgentMaxSlotMap) and (AIdx < Length(FMap)) then
  begin
    APos := FMap[AIdx];
    if (APos >= 0) and (APos < FCount) and (FIndexes[APos] = AIdx) then
      Exit(True);
  end;
  if AIdx > CAgentMaxSlotMap then
  begin
    for I := 0 to FCount - 1 do
      if FIndexes[I] = AIdx then
      begin
        APos := I;
        Exit(True);
      end;
  end;
  APos := -1;
  Result := False;
end;

function TAgentSlotRegistry.Register(AIdx: Integer; out APos: Integer): Boolean;
var
  LCap: Integer;
begin
  if TryFind(AIdx, APos) then
    Exit(False);
  if (AIdx < 0) then
    Exit(False);
  if FCount > CAgentMaxSlotMap then
    Exit(False); // 总数越限（provider/fold 共用阈值，SECURITY §3）
  // 索引镜像几何增长
  LCap := Length(FIndexes);
  if FCount >= LCap then
  begin
    if LCap = 0 then
      LCap := 8
    else
      LCap := LCap * 2;
    SetLength(FIndexes, LCap);
  end;
  APos := FCount;
  FIndexes[APos] := AIdx;
  Inc(FCount);
  if (AIdx >= 0) and (AIdx <= CAgentMaxSlotMap) then
  begin
    AgentSlotMapEnsureSize(FMap, AIdx);
    FMap[AIdx] := APos;
  end;
  Result := True;
end;

function TAgentSlotRegistry.At(APos: Integer): Integer;
begin
  Result := FIndexes[APos];
end;

procedure AgentSlotMapEnsureSize(var AMap: TAgentSlotMap; AIdx: Integer);
var
  LOld, LNew, I: Integer;
begin
  if (AIdx < 0) or (AIdx > CAgentMaxSlotMap) then
    Exit;
  if AIdx < Length(AMap) then
    Exit;
  LOld := Length(AMap);
  if LOld = 0 then
    LNew := 8
  else
    LNew := LOld;
  while LNew <= AIdx do
    LNew := LNew * 2;
  if LNew > CAgentMaxSlotMap + 1 then
    LNew := CAgentMaxSlotMap + 1;
  SetLength(AMap, LNew);
  for I := LOld to High(AMap) do
    AMap[I] := -1;
end;

end.
