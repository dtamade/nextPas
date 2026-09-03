{**
 * nextpas.core.agent.provider.common.extra - Extra / usage / unmapped 公共 helper。
 *
 * 职责：CaptureExtraJson 无损捕获、WriteExtraFields 回注、MergeExtraJson 薄封装、
 *   未映射枚举 JSON 构造、用量哨兵等。纯函数/零 IO，适配器编解码侧共用。
 *   与 wire/slots 互不循环，仅向下依赖 base/json。
 *
 * 属 provider.common 三象限拆分之一（extra），与 wire/slots/facade 互不循环。
 *}

unit nextpas.core.agent.provider.common.extra;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.json.value,
  nextpas.core.base,
  nextpas.core.log.intf,
  nextpas.core.json,
  nextpas.core.json.builder,
  nextpas.core.agent.base;

{ 解码侧 Extra 无损捕获：AValue 对象中不在 AKnownKeys 内的键原值捕获为
  JSON object 文本；超过 ALimit 键丢弃并 warn。无捕获返回空串 }
function CaptureExtraJson(const AValue: TJsonValue;
  const AKnownKeys: array of string; ALimit: Integer;
  const ALog: ILogger): TJsonText;

{ 编码侧 Extra 回注：把 AExtraJson 的键写入已打开的 builder 对象；
  与 AKnownNames 冲突的键让位跳过 }
procedure WriteExtraFields(const ABld: IJsonBuilder;
  const AExtraJson: TJsonText; const AKnownNames: array of string);

implementation

function CaptureExtraJson(const AValue: TJsonValue;
  const AKnownKeys: array of string; ALimit: Integer;
  const ALog: ILogger): TJsonText;
var
  LBld: IJsonBuilder;
  I: Integer;
  LKey: string;
  LCaptured: Integer;
  LHasUnknown: Boolean;
begin
  Result := '';
  if not AValue.IsObject then
    Exit;
  // 快路径：无未知键时免 JsonBuilder 分配
  LHasUnknown := False;
  for I := 0 to Integer(AValue.ObjectLen) - 1 do
    if not AgentIsKnownKey(AValue.ObjectKeyAt(UInt32(I)).ToString, AKnownKeys) then
    begin
      LHasUnknown := True;
      Break;
    end;
  if not LHasUnknown then
    Exit;
  LBld := JsonBuilder;
  LBld.BeginObject;
  LCaptured := 0;
  for I := 0 to Integer(AValue.ObjectLen) - 1 do
  begin
    LKey := AValue.ObjectKeyAt(UInt32(I)).ToString;
    if AgentIsKnownKey(LKey, AKnownKeys) then
      Continue;
    if LCaptured >= ALimit then
    begin
      if ALog <> nil then
        ALog.Warn('agent.extra: capture limit reached, dropping key ' + LKey);
      Break;
    end;
    LBld.Key(LKey);
    LBld.RawJson(JsonStringify(AValue.ObjectGet(LKey)));
    Inc(LCaptured);
  end;
  if LCaptured > 0 then
  begin
    LBld.EndObject;
    Result := LBld.ToString;
  end;
end;

procedure WriteExtraFields(const ABld: IJsonBuilder;
  const AExtraJson: TJsonText; const AKnownNames: array of string);
var
  Doc: IJsonDocument;
  Root: TJsonValue;
  I: Integer;
  LKey: string;
begin
  if AExtraJson = '' then
    Exit;
  Doc := JsonParse(AExtraJson);
  if Doc.HasError or (not Doc.Root.IsObject) then
    Exit;
  Root := Doc.Root;
  for I := 0 to Integer(Root.ObjectLen) - 1 do
  begin
    LKey := Root.ObjectKeyAt(UInt32(I)).ToString;
    if AgentIsKnownKey(LKey, AKnownNames) then
      Continue;
    ABld.Key(LKey);
    ABld.RawJson(JsonStringify(Root.ObjectGet(LKey)));
  end;
end;

end.
