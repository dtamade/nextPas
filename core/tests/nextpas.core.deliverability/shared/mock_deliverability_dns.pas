unit mock_deliverability_dns;
{**
 * 内存 DNS mock(表驱动): 实现 IDeliverabilityDns 供 deliverability 测试。
 * TXT/A/MX 记录表 + 按名可注入网络错误; 记录查询计数可断言。
 *}

{$MODE OBJFPC}{$H+}

interface

uses
  nextpas.core.deliverability.base;

type
  TMockDeliverabilityDns = class(TInterfacedObject, IDeliverabilityDns)
  private
    FTxtNames: TDeliverabilityStringArray;
    FTxtVals: TDeliverabilityStringArray;
    FANames: TDeliverabilityStringArray;
    FAVals: TDeliverabilityStringArray;
    FMxNames: TDeliverabilityStringArray;
    FMxVals: TDeliverabilityStringArray;
    FFailNames: TDeliverabilityStringArray;   { 网络错误(不计记录数) }
    FTxtQueries: Integer;
    FAQueries: Integer;
    FMxQueries: Integer;
    function SIndex(const ANames: TDeliverabilityStringArray;
      const AName: string): Integer;
  public
    procedure AddTXT(const AName, AValue: string);
    procedure AddA(const AName, AValue: string);
    procedure AddMX(const AName, AValue: string);
    procedure AddFailure(const AName: string);
    function QueryTXT(const AName: string; const ATimeoutMs: Int32;
      out ATexts: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryA(const AName: string; const ATimeoutMs: Int32;
      out AIps: TDeliverabilityStringArray; out AError: string): Boolean;
    function QueryMX(const AName: string; const ATimeoutMs: Int32;
      out AHosts: TDeliverabilityStringArray; out AError: string): Boolean;
    property TxtQueries: Integer read FTxtQueries;
    property AQueries: Integer read FAQueries;
    property MxQueries: Integer read FMxQueries;
  end;

implementation

function LowerAscii(const AStr: string): string;
var
  I: Integer;
begin
  Result := AStr;
  for I := 1 to Length(Result) do
    if (Result[I] >= 'A') and (Result[I] <= 'Z') then
      Inc(Result[I], 32);
end;

function TMockDeliverabilityDns.SIndex(const ANames: TDeliverabilityStringArray;
  const AName: string): Integer;
var
  I: Integer;
begin
  for I := 0 to High(ANames) do
    if LowerAscii(ANames[I]) = LowerAscii(AName) then
    begin
      Result := I;
      Exit;
    end;
  Result := -1;
end;

procedure TMockDeliverabilityDns.AddTXT(const AName, AValue: string);
begin
  SetLength(FTxtNames, Length(FTxtNames) + 1);
  FTxtNames[High(FTxtNames)] := AName;
  SetLength(FTxtVals, Length(FTxtVals) + 1);
  FTxtVals[High(FTxtVals)] := AValue;
end;

procedure TMockDeliverabilityDns.AddA(const AName, AValue: string);
begin
  SetLength(FANames, Length(FANames) + 1);
  FANames[High(FANames)] := AName;
  SetLength(FAVals, Length(FAVals) + 1);
  FAVals[High(FAVals)] := AValue;
end;

procedure TMockDeliverabilityDns.AddMX(const AName, AValue: string);
begin
  SetLength(FMxNames, Length(FMxNames) + 1);
  FMxNames[High(FMxNames)] := AName;
  SetLength(FMxVals, Length(FMxVals) + 1);
  FMxVals[High(FMxVals)] := AValue;
end;

procedure TMockDeliverabilityDns.AddFailure(const AName: string);
begin
  SetLength(FFailNames, Length(FFailNames) + 1);
  FFailNames[High(FFailNames)] := AName;
end;

function TMockDeliverabilityDns.QueryTXT(const AName: string;
  const ATimeoutMs: Int32; out ATexts: TDeliverabilityStringArray;
  out AError: string): Boolean;
var
  LFail: Integer;
  I: Integer;
begin
  Result := False;
  ATexts := nil;
  AError := '';
  LFail := SIndex(FFailNames, AName);
  if LFail >= 0 then
  begin
    AError := 'temporary failure (network)';
    Exit;
  end;
  Inc(FTxtQueries);
  if SIndex(FTxtNames, AName) < 0 then
  begin
    AError := 'no record for: ' + AName;
    Exit;
  end;
  for I := 0 to High(FTxtNames) do
    if LowerAscii(FTxtNames[I]) = LowerAscii(AName) then
    begin
      SetLength(ATexts, Length(ATexts) + 1);
      ATexts[High(ATexts)] := FTxtVals[I];
    end;
  Result := Length(ATexts) > 0;
end;

function TMockDeliverabilityDns.QueryA(const AName: string;
  const ATimeoutMs: Int32; out AIps: TDeliverabilityStringArray;
  out AError: string): Boolean;
var
  LFail: Integer;
  I: Integer;
begin
  Result := False;
  AIps := nil;
  AError := '';
  LFail := SIndex(FFailNames, AName);
  if LFail >= 0 then
  begin
    AError := 'temporary failure (network)';
    Exit;
  end;
  Inc(FAQueries);
  if SIndex(FANames, AName) < 0 then
  begin
    AError := 'nxdomain for: ' + AName;
    Exit;
  end;
  for I := 0 to High(FANames) do
    if LowerAscii(FANames[I]) = LowerAscii(AName) then
    begin
      SetLength(AIps, Length(AIps) + 1);
      AIps[High(AIps)] := FAVals[I];
    end;
  Result := Length(AIps) > 0;
end;

function TMockDeliverabilityDns.QueryMX(const AName: string;
  const ATimeoutMs: Int32; out AHosts: TDeliverabilityStringArray;
  out AError: string): Boolean;
var
  LFail: Integer;
  I: Integer;
begin
  Result := False;
  AHosts := nil;
  AError := '';
  LFail := SIndex(FFailNames, AName);
  if LFail >= 0 then
  begin
    AError := 'temporary failure (network)';
    Exit;
  end;
  Inc(FMxQueries);
  if SIndex(FMxNames, AName) < 0 then
  begin
    AError := 'nxdomain for: ' + AName;
    Exit;
  end;
  for I := 0 to High(FMxNames) do
    if LowerAscii(FMxNames[I]) = LowerAscii(AName) then
    begin
      SetLength(AHosts, Length(AHosts) + 1);
      AHosts[High(AHosts)] := FMxVals[I];
    end;
  Result := Length(AHosts) > 0;
end;

end.