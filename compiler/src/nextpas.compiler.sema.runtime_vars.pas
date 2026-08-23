{**
 * nextpas.compiler.sema.runtime_vars.pas
 *
 * 运行时变量注册表 — 从 TSemanticAnalyzer 提取的纯数据管理方法
 *
 * 表存储可挂 phase-scratch IAllocator（analyzer FScratchAllocator）。
 *
 * 对标：rustc 的 local_names 表，Go gc 的 func info
 *}

unit nextpas.compiler.sema.runtime_vars;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TStringVec = specialize TVec<string>;

  TStringArray = array of string;

  TSemaRuntimeVarRegistry = class
  private
    FAllocator: IAllocator;
    FRuntimeVarNames: TStringVec;
    FRuntimeStrVarNames: TStringVec;
    FOwnedRuntimeStrVarNames: TStringVec;
    FBorrowedRuntimeStrVarNames: TStringVec;
    FOwnedStringReturnFuncNames: TStringVec;
    FPendingStringTempNames: TStringVec;
    FPendingStringTempSources: TStringVec;
    FRuntimeArrVarNames: TStringVec;
    FBorrowedRuntimeArrVarNames: TStringVec;
    FClassVarNames: TStringVec;
    FClassVarTypes: TStringVec;
    FRecordVarNames: TStringVec;
    FRecordVarTypes: TStringVec;
    FManagedRecordVarNames: TStringVec;
    FManagedRecordVarTypes: TStringVec;
    FPointerVarNames: TStringVec;
    FPointerVarTypes: TStringVec;
    FVarParamNames: TStringVec;
    FPtrReturnFuncs: TStringVec;
    FPtrReturnTypes: TStringVec;
    function CreateStringVec: TStringVec;
    function StringVecToArray(AVec: TStringVec): TStringArray;
    function ContainsName(AVec: TStringVec; const AName: string): Boolean;
    procedure RegisterUniqueName(AVec: TStringVec; const AName: string);
  public
    constructor Create(AAllocator: IAllocator = nil);
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

function TSemaRuntimeVarRegistry.CreateStringVec: TStringVec;
begin
  if FAllocator <> nil then
    Result := TStringVec.Create(0, FAllocator)
  else
    Result := TStringVec.Create;
end;

function TSemaRuntimeVarRegistry.StringVecToArray(AVec: TStringVec): TStringArray;
var
  I: LongInt;
begin
  SetLength(Result, LongInt(AVec.Count));
  for I := 0 to LongInt(AVec.Count) - 1 do
    Result[I] := AVec[I];
end;

function TSemaRuntimeVarRegistry.ContainsName(AVec: TStringVec;
  const AName: string): Boolean;
var
  Idx: LongInt;
begin
  for Idx := 0 to LongInt(AVec.Count) - 1 do
    if SameText(AVec[Idx], AName) then
      Exit(True);
  Result := False;
end;

procedure TSemaRuntimeVarRegistry.RegisterUniqueName(AVec: TStringVec;
  const AName: string);
begin
  if ContainsName(AVec, AName) then
    Exit;
  AVec.Push(AName);
end;

constructor TSemaRuntimeVarRegistry.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
  FRuntimeVarNames := CreateStringVec;
  FRuntimeStrVarNames := CreateStringVec;
  FOwnedRuntimeStrVarNames := CreateStringVec;
  FBorrowedRuntimeStrVarNames := CreateStringVec;
  FOwnedStringReturnFuncNames := CreateStringVec;
  FPendingStringTempNames := CreateStringVec;
  FPendingStringTempSources := CreateStringVec;
  FRuntimeArrVarNames := CreateStringVec;
  FBorrowedRuntimeArrVarNames := CreateStringVec;
  FClassVarNames := CreateStringVec;
  FClassVarTypes := CreateStringVec;
  FRecordVarNames := CreateStringVec;
  FRecordVarTypes := CreateStringVec;
  FManagedRecordVarNames := CreateStringVec;
  FManagedRecordVarTypes := CreateStringVec;
  FPointerVarNames := CreateStringVec;
  FPointerVarTypes := CreateStringVec;
  FVarParamNames := CreateStringVec;
  FPtrReturnFuncs := CreateStringVec;
  FPtrReturnTypes := CreateStringVec;
end;

destructor TSemaRuntimeVarRegistry.Destroy;
begin
  FRuntimeVarNames.Free;
  FRuntimeStrVarNames.Free;
  FOwnedRuntimeStrVarNames.Free;
  FBorrowedRuntimeStrVarNames.Free;
  FOwnedStringReturnFuncNames.Free;
  FPendingStringTempNames.Free;
  FPendingStringTempSources.Free;
  FRuntimeArrVarNames.Free;
  FBorrowedRuntimeArrVarNames.Free;
  FClassVarNames.Free;
  FClassVarTypes.Free;
  FRecordVarNames.Free;
  FRecordVarTypes.Free;
  FManagedRecordVarNames.Free;
  FManagedRecordVarTypes.Free;
  FPointerVarNames.Free;
  FPointerVarTypes.Free;
  FVarParamNames.Free;
  FPtrReturnFuncs.Free;
  FPtrReturnTypes.Free;
  inherited Destroy;
end;

procedure TSemaRuntimeVarRegistry.RegisterRuntimeVar(const AName: string);
begin
  RegisterUniqueName(FRuntimeVarNames, AName);
end;

function TSemaRuntimeVarRegistry.IsRuntimeVar(const AName: string): Boolean;
begin
  Result := ContainsName(FRuntimeVarNames, AName);
end;

{$I np_sema_runtime_vars_str_arr.inc}
{$I np_sema_runtime_vars_class_record.inc}

end.
