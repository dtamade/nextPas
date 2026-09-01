unit nextpas.core.graphql;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.errors,
  nextpas.core.http.base,
  nextpas.core.http.intf,
  nextpas.core.json,
  nextpas.core.json.value;

type
  EGraphqlError = class(ENextPasError)
  protected
    class function DefaultCategory: TErrorCategory; override;
  end;

  TGraphqlRequest = record
    Query: string;
    VariablesJson: string;
    OperationName: string;
    class function Create(const AQuery: string): TGraphqlRequest; static; inline;
    class function CreateWithVariables(const AQuery, AVariablesJson: string;
      const AOperationName: string = ''): TGraphqlRequest; static; inline;
  end;

  TGraphqlResponse = record
    Data: IJsonDocument;
    Raw: IJsonDocument;
  end;

function GraphqlFetch(const AClient: IHttpClient; const AUrl, AQuery: string): IJsonDocument; overload;
function GraphqlFetch(const AClient: IHttpClient; const AUrl, AQuery: string;
  const AVariablesJson: string; const AOperationName: string = ''): IJsonDocument; overload;
function GraphqlFetch(const AClient: IHttpClient; const AUrl: string;
  const ARequest: TGraphqlRequest): IJsonDocument; overload;

implementation

uses
  nextpas.core.text.conv,
  nextpas.core.http.message,
  nextpas.core.http.client.helpers,
  nextpas.core.json,
  nextpas.core.json.value.builder;

class function EGraphqlError.DefaultCategory: TErrorCategory;
begin
  Result := ecInternal;
end;

class function TGraphqlRequest.Create(const AQuery: string): TGraphqlRequest;
begin
  Result.Query := AQuery;
  Result.VariablesJson := '';
  Result.OperationName := '';
end;

class function TGraphqlRequest.CreateWithVariables(const AQuery, AVariablesJson: string;
  const AOperationName: string): TGraphqlRequest;
begin
  Result.Query := AQuery;
  Result.VariablesJson := AVariablesJson;
  Result.OperationName := AOperationName;
end;

function GraphqlFetch(const AClient: IHttpClient; const AUrl, AQuery: string): IJsonDocument;
begin
  Result := GraphqlFetch(AClient, AUrl, AQuery, '', '');
end;

function GraphqlFetch(const AClient: IHttpClient; const AUrl, AQuery: string;
  const AVariablesJson: string; const AOperationName: string): IJsonDocument;
var
  LReq: TGraphqlRequest;
begin
  LReq.Query := AQuery;
  LReq.VariablesJson := AVariablesJson;
  LReq.OperationName := AOperationName;
  Result := GraphqlFetch(AClient, AUrl, LReq);
end;

function GraphqlFetch(const AClient: IHttpClient; const AUrl: string;
  const ARequest: TGraphqlRequest): IJsonDocument;
var
  JB: IJsonBuilder;
  LBody: string;
  LVarsDoc: IJsonDocument;
  LResp: IHttpResponse;
  LRespBody: string;
  LDoc: IJsonDocument;
  LErrors, LData, LItem, LMsg: TJsonValue;
  I: UInt32;
  LErrMsg, LOne: string;
begin
  if AClient = nil then
    raise EArgumentError.Create('graphql client must not be nil');
  if AUrl = '' then
    raise EArgumentError.Create('graphql url must not be empty');

  JB := JsonBuilder(256);
  JB.BeginObject;
  JB.Key('query');
  JB.Str(ARequest.Query);
  if ARequest.VariablesJson <> '' then
  begin
    try
      LVarsDoc := JsonParse(ARequest.VariablesJson);
      if LVarsDoc.HasError then
        raise EArgumentError.Create('graphql variables is not valid JSON: ' + LVarsDoc.Error.Message.ToString);
      JB.Key('variables');
      JB.RawJson(ARequest.VariablesJson);
    except
      on E: EArgumentError do raise;
      on E: Exception do
        raise EArgumentError.Create('graphql variables is not valid JSON: ' + E.Message);
    end;
  end;
  if ARequest.OperationName <> '' then
  begin
    JB.Key('operationName');
    JB.Str(ARequest.OperationName);
  end;
  JB.EndObject;
  LBody := JB.ToString;

  try
    LResp := AClient.Send(
      THttpRequestBuilder.Create(hmPost, AUrl)
        .ContentType('application/json')
        .Body(LBody)
        .Build);
  except
    on E: Exception do
      raise;
  end;

  if not HttpStatusIsSuccess(LResp.StatusCode) then
    raise EGraphqlError.Create('graphql HTTP error: HTTP ' + IntToStr(Int64(LResp.StatusCode)));

  LRespBody := HttpReadResponseBodyString(LResp);

  try
    LDoc := JsonParse(LRespBody);
  except
    on E: Exception do
      raise EGraphqlError.Create('failed to parse response: ' + E.Message);
  end;
  if LDoc.HasError then
    raise EGraphqlError.Create('failed to parse response: ' + LDoc.Error.Message.ToString);

  LErrors := LDoc.Root.ObjectGet('errors');
  if LErrors.IsArray and (LErrors.ArrayLen > 0) then
  begin
    LErrMsg := '';
    for I := 0 to LErrors.ArrayLen - 1 do
    begin
      LItem := LErrors.ArrayGet(I);
      if LItem.IsStr then
        LOne := LItem.AsStr.ToString
      else if LItem.IsObject then
      begin
        LMsg := LItem.ObjectGet('message');
        if LMsg.IsStr then
          LOne := LMsg.AsStr.ToString
        else
          LOne := JsonStringify(LItem);
      end
      else
        LOne := JsonStringify(LItem);
      if LOne = '' then
        LOne := '(empty graphql error)';
      if LErrMsg <> '' then
        LErrMsg := LErrMsg + ', ';
      LErrMsg := LErrMsg + LOne;
    end;
    raise EGraphqlError.Create('graphql error: ' + LErrMsg);
  end;

  LData := LDoc.Root.ObjectGet('data');
  if not LData.IsValid then
    raise EGraphqlError.Create('empty graphql response');

  Result := LDoc;
end;

end.
