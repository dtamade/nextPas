{**
 * np_sema_runtime_vars.pas
 *
 * 运行时变量注册表 — 从 TSemanticAnalyzer 提取的纯数据管理方法
 *
 * 对标：rustc 的 local_names 表，Go gc 的 func info
 *}

unit np_sema_runtime_vars;

{$mode objfpc}{$H+}

interface

uses
  SysUtils,
  nextpas.core.collections.vec;

type
  TStringVec = specialize TVec<string>;

  TStringArray = array of string;

  TSemaRuntimeVarRegistry = class
  private
    FRuntimeVarNames: array of string;
    FRuntimeStrVarNames: array of string;
    FOwnedRuntimeStrVarNames: array of string;
    FBorrowedRuntimeStrVarNames: array of string;
    FOwnedStringReturnFuncNames: array of string;
    FPendingStringTempNames: array of string;
    FPendingStringTempSources: array of string;
    FRuntimeArrVarNames: array of string;
    FBorrowedRuntimeArrVarNames: array of string;
    FClassVarNames: array of string;
    FClassVarTypes: array of string;
    FRecordVarNames: array of string;
    FRecordVarTypes: array of string;
    FManagedRecordVarNames: array of string;
    FManagedRecordVarTypes: array of string;
    FPointerVarNames: array of string;
    FPointerVarTypes: array of string;
    FVarParamNames: TStringVec;
    FPtrReturnFuncs: array of string;
    FPtrReturnTypes: array of string;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RegisterRuntimeVar(const AName: string);
    function IsRuntimeVar(const AName: string): Boolean;

    procedure RegisterRuntimeStrVar(const AName: string);
    procedure RegisterOwnedRuntimeStrVar(const AName: string);
    procedure RegisterBorrowedRuntimeStrVar(const AName: string);
    function IsOwnedRuntimeStrVar(const AName: string): Boolean;
    function IsBorrowedRuntimeStrVar(const AName: string): Boolean;
    function GetOwnedRuntimeStrVarNames: TStringArray;
    function GetOwnedRuntimeStrVarCount: SizeInt;

    procedure RegisterOwnedStringReturnFunc(const AName: string);
    function IsOwnedStringReturnFunc(const AName: string): Boolean;

    procedure ClearPendingStringTempReleases;
    procedure QueuePendingStringTempRelease(const ATempName, ASourceName: string);
    function GetPendingStringTempNames: TStringArray;
    function GetPendingStringTempSources: TStringArray;
    function GetPendingStringTempCount: SizeInt;

    procedure RegisterRuntimeArrVar(const AName: string);
    procedure RegisterBorrowedRuntimeArrVar(const AName: string);
    function IsRuntimeArrVar(const AName: string): Boolean;
    function IsBorrowedRuntimeArrVar(const AName: string): Boolean;
    function GetRuntimeArrVarNames: TStringArray;
    function GetBorrowedRuntimeArrVarNames: TStringArray;

    procedure RegisterClassVar(const AName, AClassName: string);
    function LookupClassVar(const AName: string): string;

    procedure RegisterRecordVar(const AName, ATypeName: string);
    function IsRecordVar(const AName: string): Boolean;
    function LookupRecordVar(const AName: string): string;

    procedure RegisterManagedRecordVar(const AName, ATypeName: string);
    function GetManagedRecordVarNames: TStringArray;
    function GetManagedRecordVarTypes: TStringArray;
    function GetManagedRecordVarCount: SizeInt;

    procedure RegisterPointerVar(const AName, APointeeTypeName: string);
    function LookupPointerVar(const AName: string): string;

    procedure RegisterVarParam(const AName: string);
    function IsVarParam(const AName: string): Boolean;
    function GetVarParamCount: SizeInt;
    function GetVarParamAt(AIndex: SizeInt): string;

    procedure RegisterPtrReturnFunc(const AName, AClassName: string);
    function LookupPtrReturnFunc(const AName: string): string;
  end;

implementation

constructor TSemaRuntimeVarRegistry.Create;
begin
  inherited Create;
  FVarParamNames := TStringVec.Create;
end;

destructor TSemaRuntimeVarRegistry.Destroy;
begin
  FVarParamNames.Free;
  inherited Destroy;
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeVarNames);
  SetLength(FRuntimeVarNames, NextIndex + 1);
  FRuntimeVarNames[NextIndex] := AName;
end;

function TSemaRuntimeVarRegistry.IsRuntimeVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeVarNames) - 1 do
    if SameText(FRuntimeVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeStrVarNames) - 1 do
    if SameText(FRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeStrVarNames);
  SetLength(FRuntimeStrVarNames, NextIndex + 1);
  FRuntimeStrVarNames[NextIndex] := AName;
end;

procedure TSemaRuntimeVarRegistry.RegisterOwnedRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
    if SameText(FOwnedRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FOwnedRuntimeStrVarNames);
  SetLength(FOwnedRuntimeStrVarNames, NextIndex + 1);
  FOwnedRuntimeStrVarNames[NextIndex] := AName;
end;

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeStrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FBorrowedRuntimeStrVarNames) - 1 do
    if SameText(FBorrowedRuntimeStrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FBorrowedRuntimeStrVarNames);
  SetLength(FBorrowedRuntimeStrVarNames, NextIndex + 1);
  FBorrowedRuntimeStrVarNames[NextIndex] := AName;
end;

function TSemaRuntimeVarRegistry.IsOwnedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedRuntimeStrVarNames) - 1 do
    if SameText(FOwnedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeStrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeStrVarNames) - 1 do
    if SameText(FBorrowedRuntimeStrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarNames: TStringArray;
begin
  Result := FOwnedRuntimeStrVarNames;
end;

function TSemaRuntimeVarRegistry.GetOwnedRuntimeStrVarCount: SizeInt;
begin
  Result := Length(FOwnedRuntimeStrVarNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterOwnedStringReturnFunc(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  if AName = '' then
    Exit;
  for Idx := 0 to Length(FOwnedStringReturnFuncNames) - 1 do
    if SameText(FOwnedStringReturnFuncNames[Idx], AName) then
      Exit;
  NextIndex := Length(FOwnedStringReturnFuncNames);
  SetLength(FOwnedStringReturnFuncNames, NextIndex + 1);
  FOwnedStringReturnFuncNames[NextIndex] := AName;
end;

function TSemaRuntimeVarRegistry.IsOwnedStringReturnFunc(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FOwnedStringReturnFuncNames) - 1 do
    if SameText(FOwnedStringReturnFuncNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemaRuntimeVarRegistry.ClearPendingStringTempReleases;
begin
  SetLength(FPendingStringTempNames, 0);
  SetLength(FPendingStringTempSources, 0);
end;

procedure TSemaRuntimeVarRegistry.QueuePendingStringTempRelease(
  const ATempName, ASourceName: string);
var
  NextIndex: SizeInt;
begin
  if (ATempName = '') or (ASourceName = '') then
    Exit;
  NextIndex := Length(FPendingStringTempNames);
  SetLength(FPendingStringTempNames, NextIndex + 1);
  SetLength(FPendingStringTempSources, NextIndex + 1);
  FPendingStringTempNames[NextIndex] := ATempName;
  FPendingStringTempSources[NextIndex] := ASourceName;
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempNames: TStringArray;
begin
  Result := FPendingStringTempNames;
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempSources: TStringArray;
begin
  Result := FPendingStringTempSources;
end;

function TSemaRuntimeVarRegistry.GetPendingStringTempCount: SizeInt;
begin
  Result := Length(FPendingStringTempNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeArrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FRuntimeArrVarNames);
  SetLength(FRuntimeArrVarNames, NextIndex + 1);
  FRuntimeArrVarNames[NextIndex] := AName;
end;

procedure TSemaRuntimeVarRegistry.RegisterBorrowedRuntimeArrVar(const AName: string);
var
  Idx: LongInt;
  NextIndex: SizeInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeArrVarNames) - 1 do
    if SameText(FBorrowedRuntimeArrVarNames[Idx], AName) then
      Exit;
  NextIndex := Length(FBorrowedRuntimeArrVarNames);
  SetLength(FBorrowedRuntimeArrVarNames, NextIndex + 1);
  FBorrowedRuntimeArrVarNames[NextIndex] := AName;
end;

function TSemaRuntimeVarRegistry.IsRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRuntimeArrVarNames) - 1 do
    if SameText(FRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.IsBorrowedRuntimeArrVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FBorrowedRuntimeArrVarNames) - 1 do
    if SameText(FBorrowedRuntimeArrVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.GetRuntimeArrVarNames: TStringArray;
begin
  Result := FRuntimeArrVarNames;
end;

function TSemaRuntimeVarRegistry.GetBorrowedRuntimeArrVarNames: TStringArray;
begin
  Result := FBorrowedRuntimeArrVarNames;
end;

procedure TSemaRuntimeVarRegistry.RegisterClassVar(const AName, AClassName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
    begin
      FClassVarTypes[Idx] := AClassName;
      Exit;
    end;
  Idx := Length(FClassVarNames);
  SetLength(FClassVarNames, Idx + 1);
  SetLength(FClassVarTypes, Idx + 1);
  FClassVarNames[Idx] := AName;
  FClassVarTypes[Idx] := AClassName;
end;

function TSemaRuntimeVarRegistry.LookupClassVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FClassVarNames) - 1 do
    if SameText(FClassVarNames[Idx], AName) then
      Exit(FClassVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterRecordVar(const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
    begin
      FRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  Idx := Length(FRecordVarNames);
  SetLength(FRecordVarNames, Idx + 1);
  SetLength(FRecordVarTypes, Idx + 1);
  FRecordVarNames[Idx] := AName;
  FRecordVarTypes[Idx] := ATypeName;
end;

function TSemaRuntimeVarRegistry.IsRecordVar(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.LookupRecordVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FRecordVarNames) - 1 do
    if SameText(FRecordVarNames[Idx], AName) then
      Exit(FRecordVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterManagedRecordVar(
  const AName, ATypeName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FManagedRecordVarNames) - 1 do
    if SameText(FManagedRecordVarNames[Idx], AName) then
    begin
      FManagedRecordVarTypes[Idx] := ATypeName;
      Exit;
    end;
  Idx := Length(FManagedRecordVarNames);
  SetLength(FManagedRecordVarNames, Idx + 1);
  SetLength(FManagedRecordVarTypes, Idx + 1);
  FManagedRecordVarNames[Idx] := AName;
  FManagedRecordVarTypes[Idx] := ATypeName;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarNames: TStringArray;
begin
  Result := FManagedRecordVarNames;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarTypes: TStringArray;
begin
  Result := FManagedRecordVarTypes;
end;

function TSemaRuntimeVarRegistry.GetManagedRecordVarCount: SizeInt;
begin
  Result := Length(FManagedRecordVarNames);
end;

procedure TSemaRuntimeVarRegistry.RegisterPointerVar(const AName,
  APointeeTypeName: string);
var
  Idx: LongInt;
begin
  if (AName = '') or (APointeeTypeName = '') then
    Exit;
  for Idx := 0 to Length(FPointerVarNames) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
    begin
      FPointerVarTypes[Idx] := APointeeTypeName;
      Exit;
    end;
  Idx := Length(FPointerVarNames);
  SetLength(FPointerVarNames, Idx + 1);
  SetLength(FPointerVarTypes, Idx + 1);
  FPointerVarNames[Idx] := AName;
  FPointerVarTypes[Idx] := APointeeTypeName;
end;

function TSemaRuntimeVarRegistry.LookupPointerVar(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPointerVarNames) - 1 do
    if SameText(FPointerVarNames[Idx], AName) then
      Exit(FPointerVarTypes[Idx]);
  Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterVarParam(const AName: string);
var
  Idx: LongInt;
begin
  for Idx := 0 to FVarParamNames.Count - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit;
  FVarParamNames.Push(AName);
end;

function TSemaRuntimeVarRegistry.IsVarParam(const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to FVarParamNames.Count - 1 do
    if SameText(FVarParamNames[Idx], AName) then
      Exit(True);
  Result := False;
end;

function TSemaRuntimeVarRegistry.GetVarParamCount: SizeInt;
begin
  Result := FVarParamNames.Count;
end;

function TSemaRuntimeVarRegistry.GetVarParamAt(AIndex: SizeInt): string;
begin
  if (AIndex >= 0) and (AIndex < FVarParamNames.Count) then
    Result := FVarParamNames[AIndex]
  else
    Result := '';
end;

procedure TSemaRuntimeVarRegistry.RegisterPtrReturnFunc(
  const AName, AClassName: string);
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FPtrReturnFuncs);
  SetLength(FPtrReturnFuncs, NextIndex + 1);
  SetLength(FPtrReturnTypes, NextIndex + 1);
  FPtrReturnFuncs[NextIndex] := AName;
  FPtrReturnTypes[NextIndex] := AClassName;
end;

function TSemaRuntimeVarRegistry.LookupPtrReturnFunc(const AName: string): string;
var
  Idx: LongInt;
begin
  for Idx := 0 to Length(FPtrReturnFuncs) - 1 do
    if SameText(FPtrReturnFuncs[Idx], AName) then
      Exit(FPtrReturnTypes[Idx]);
  Result := '';
end;

end.
