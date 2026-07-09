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
    function IsRuntimeStrVar(const AName: string): Boolean;
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
    function GetClassVarNames: TStringArray;
    function GetClassVarTypes: TStringArray;

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
    procedure Reset;
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
{$I np_sema_runtime_vars_str_arr.inc}
end;
{$I np_sema_runtime_vars_class_record.inc}
end;

end.
