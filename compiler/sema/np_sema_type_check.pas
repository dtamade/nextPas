{**
 * np_sema_type_check.pas
 *
 * 类型检查/元数据查询模块 — 从 TSemanticAnalyzer 提取
 *
 * 职责：
 *   - 类型元数据查询（TypeMetaSize, TypeMetaIsRecord, TypeMetaIsClass 等）
 *   - 类型字段查询（TypeMetaFieldIndex, TypeMetaFieldIsStr 等）
 *   - VMT 查询（TypeMetaVmtSlot, TypeMetaVmtCount 等）
 *   - 类型层级查询（TypeMetaParentClass, NextClassAncestorName 等）
 *   - 接口查询（TypeMetaIsInterface, TypeIsInterfaceByName, TypeMetaInterfaces）
 *
 * 所有函数接收 const AModel: TSemanticModel 作为第一个参数，
 * 纯查询，零副作用。
 *
 * 对标：rustc 的 ty 模块
 *}

unit np_sema_type_check;

{$mode objfpc}{$H+}

interface

uses
  np_semantic_model;

{ === 基本类型元数据 === }

function TypeMetaSize(const AModel: TSemanticModel; const ATypeName: string): Int64;
function TypeMetaIsRecord(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeMetaIsClass(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeMetaIsInterface(const AModel: TSemanticModel; const ATypeName: string): Boolean;
function TypeIsInterfaceByName(const AModel: TSemanticModel; const ATypeName: string): Boolean;

{ === 字段元数据 === }

function TypeMetaFieldIndex(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
function TypeMetaFieldIsStr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldIsPtr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldIsDynArray(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
function TypeMetaFieldDynArrayElemSize(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;

{ === VMT 元数据 === }

function TypeMetaVmtSlot(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Int64;
function TypeMetaRetPtr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
function TypeMetaRetStr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
function TypeMetaVmtCount(const AModel: TSemanticModel; const ATypeName: string): Int64;

{ === 类型层级 === }

function TypeMetaParentClass(const AModel: TSemanticModel; const ATypeName: string): string;
function NextClassAncestorName(const AModel: TSemanticModel; const ATypeName: string): string;

{ === 接口 === }

function TypeMetaInterfaces(const AModel: TSemanticModel; const ATypeName: string): string;

implementation

uses
  SysUtils;

{ === 基本类型元数据 === }

function TypeMetaSize(const AModel: TSemanticModel; const ATypeName: string): Int64;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then Exit(Meta.Size);
  if AModel.LookupConstValue(ATypeName + '$size', V) then Exit(V);
  Result := -1;
end;

function TypeMetaIsRecord(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then Exit(Meta.IsRecord);
  Result := AModel.LookupConstValue(ATypeName + '$record', V);
end;

function TypeMetaIsClass(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    Exit((not Meta.IsRecord) and (Meta.Size > 0));
  Result := (not AModel.LookupConstValue(ATypeName + '$record', V)) and
    AModel.LookupConstValue(ATypeName + '$size', V);
end;

function TypeMetaIsInterface(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var V: Int64;
begin
  Result := AModel.LookupConstValue(ATypeName + '$interface', V);
end;

function TypeIsInterfaceByName(const AModel: TSemanticModel; const ATypeName: string): Boolean;
var TypeId: LongInt;
begin
  if TypeMetaIsInterface(AModel, ATypeName) then
    Exit(True);
  TypeId := AModel.FindTypeByName(ATypeName);
  Result := (TypeId > 0) and
    SameText(AModel.TypeAt(TypeId - 1).Kind, 'interface');
end;

{ === 字段元数据 === }

function TypeMetaFieldIndex(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    for I := 0 to High(Meta.Fields) do
      if SameText(Meta.Fields[I].Name, AFieldName) then
        Exit(Meta.Fields[I].Index);
  if AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$idx', V) then
    Exit(V);
  Result := -1;
end;

function TypeMetaFieldIsStr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    for I := 0 to High(Meta.Fields) do
      if SameText(Meta.Fields[I].Name, AFieldName) then
        Exit(Meta.Fields[I].IsString);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$str', V);
end;

function TypeMetaFieldIsPtr(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    for I := 0 to High(Meta.Fields) do
      if SameText(Meta.Fields[I].Name, AFieldName) then
        Exit(Meta.Fields[I].IsPointer);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$ptr', V);
end;

function TypeMetaFieldIsDynArray(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Boolean;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    for I := 0 to High(Meta.Fields) do
      if SameText(Meta.Fields[I].Name, AFieldName) then
        Exit(Meta.Fields[I].IsDynArray);
  Result := AModel.LookupConstValue(ATypeName + '.' + AFieldName + '$arr', V);
end;

function TypeMetaFieldDynArrayElemSize(const AModel: TSemanticModel;
  const ATypeName, AFieldName: string): Int64;
begin
  if not AModel.LookupConstValue(
    ATypeName + '.' + AFieldName + '$arr_elem_size', Result) then
    Result := 8;
end;

{ === VMT 元数据 === }

function TypeMetaVmtSlot(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Int64;
var Meta: TTypeMetadata; I: LongInt; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then
    for I := 0 to High(Meta.VmtSlots) do
      if SameText(Meta.VmtSlots[I].MethodName, AMethodName) then
        Exit(Meta.VmtSlots[I].SlotIndex);
  if AModel.LookupConstValue(ATypeName + '$vmt_slot_' + AMethodName, V) then
    Exit(V);
  Result := -1;
end;

function TypeMetaRetPtr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
var V: Int64;
begin
  Result := AModel.LookupConstValue(ATypeName + '$ret_ptr_' + AMethodName, V);
end;

function TypeMetaRetStr(const AModel: TSemanticModel;
  const ATypeName, AMethodName: string): Boolean;
var V: Int64;
begin
  Result := AModel.LookupConstValue(ATypeName + '$ret_str_' + AMethodName, V);
end;

function TypeMetaVmtCount(const AModel: TSemanticModel; const ATypeName: string): Int64;
var Meta: TTypeMetadata; V: Int64;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) then Exit(Meta.VmtCount);
  if AModel.LookupConstValue(ATypeName + '$vmt_count', V) then Exit(V);
  Result := -1;
end;

{ === 类型层级 === }

function TypeMetaParentClass(const AModel: TSemanticModel; const ATypeName: string): string;
var Meta: TTypeMetadata;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.ParentClassName <> '') then
    Exit(Meta.ParentClassName);
  if not AModel.LookupStringConstValue(ATypeName + '$parent_class', Result) then
    Result := '';
end;

function NextClassAncestorName(const AModel: TSemanticModel; const ATypeName: string): string;
var
  TypeId: LongInt;
begin
  Result := '';
  if ATypeName = '' then
    Exit;

  TypeId := AModel.FindTypeByName(ATypeName);
  if (TypeId > 0) and (AModel.TypeAt(TypeId - 1).ParentTypeId > 0) then
    Result := AModel.TypeAt(
      AModel.TypeAt(TypeId - 1).ParentTypeId - 1).Name;
  if Result = '' then
    Result := TypeMetaParentClass(AModel, ATypeName);
  if SameText(Result, ATypeName) then
    Result := '';
end;

{ === 接口 === }

function TypeMetaInterfaces(const AModel: TSemanticModel; const ATypeName: string): string;
var Meta: TTypeMetadata;
begin
  if AModel.GetTypeMetaByName(ATypeName, Meta) and (Meta.Interfaces <> '') then
    Exit(Meta.Interfaces);
  if not AModel.LookupStringConstValue(ATypeName + '$interfaces', Result) then
    Result := '';
end;

end.
