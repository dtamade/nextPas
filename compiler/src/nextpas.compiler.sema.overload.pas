{**
 * nextpas.compiler.sema.overload.pas
 *
 * 重载解析模块 — 从 TSemanticAnalyzer 提取
 *
 * 对标：rustc 的 fn_ctxt/overload_resolution
 *}

unit nextpas.compiler.sema.overload;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  SysUtils,
  nextpas.compiler.syntax.green_tree,
  nextpas.compiler.frontend.unit_graph,
  nextpas.compiler.syntax.ast_facade,
  nextpas.compiler.sema.semantic_model,
  nextpas.compiler.sema.builtins,
  nextpas.compiler.sema.type_check,
  nextpas.core.collections.vec,
  nextpas.core.collections.hashmap;

type
  TProcedureBodyEntry = record
    Name: string;
    Body: TGreenNode;
    Decl: TGreenNode;
    OwnerUnitId: string;
    ScopeId: LongInt;
    { Reachable body seed: only Needed bodies enter SeedFunctionBodies encode
      queue. Encoded avoids re-walking after fixed-point expansion.
      Queued avoids O(n) membership scans of FGenericWorkQueue. }
    Needed: Boolean;
    Encoded: Boolean;
    Queued: Boolean;
  end;
  { Analyzer owns; overload/ownership/HIR contexts borrow the same TVec. }
  TProcedureBodyVec = specialize TVec<TProcedureBodyEntry>;
  TProcedureBodyNameFirstMap = specialize THashMap<string, LongInt>;
  TProcedureBodyNameNextVec = specialize TVec<LongInt>;
  TTypeIdArray = array of LongInt;
  TStringArray = array of string;
  { Shared scratch vectors for imported unit tables (analyzer owns, contexts borrow). }
  TSemaImportedOwnerVec = specialize TVec<string>;
  TSemaImportedTreeVec = specialize TVec<TGreenTree>;
  TParamSignatureResult = record
    Signature: string;
    ParamCount: LongInt;
    RequiredParamCount: LongInt;
  end;

  { 重载解析上下文 }
  TSemaOverloadContext = record
    Model: TSemanticModel;
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    CurrentProcessingUnitId: string;
    CurrentScopeId: LongInt;
    ProcedureBodies: TProcedureBodyVec;
    { Optional name→index chain (borrowed from analyzer). When set, body-name
      scans are O(overloads) instead of O(all bodies). }
    BodyNameFirst: TProcedureBodyNameFirstMap;
    BodyNameNext: TProcedureBodyNameNextVec;
    ImportedUnitOwners: TSemaImportedOwnerVec;
    ImportedUnitTrees: TSemaImportedTreeVec;
    BuiltinRegistry: TBuiltinRegistry;
    PC: LongInt;
  end;

  { 单元导入查询上下文 }
  TSemaImportContext = record
    UnitGraph: TUnitGraph;
    RootAst: TAstFacade;
    ImportedUnitOwners: TSemaImportedOwnerVec;
    ImportedUnitTrees: TSemaImportedTreeVec;
  end;

function CountDeclParams(const ADecl: TGreenNode): LongInt;
function CountRequiredDeclParams(const ADecl: TGreenNode): LongInt;
function DeclAcceptsArgCount(const ADecl: TGreenNode; const AArgCount: LongInt): Boolean;
function MangledName(const AName: string; AParamCount: LongInt): string;
function MangledNameSig(const AName, ASig: string): string;
function HasOverload(const AName: string;
  const AProcedureBodies: TProcedureBodyVec): Boolean;
{ Linear name walk (TVec). Recovery used a hash index; O(n) is fine for Slice C. }
function FirstBodyIndexForName(const ABodies: TProcedureBodyVec;
  const AName: string): LongInt;
function NextBodyIndexForName(const ABodies: TProcedureBodyVec;
  const AName: string; const APrevIndex: LongInt): LongInt;
{ Prefer BodyNameFirst/Next when present (O(overloads)); else linear walk. }
function CtxFirstBodyIndexForName(const Ctx: TSemaOverloadContext;
  const AName: string): LongInt;
function CtxNextBodyIndexForName(const Ctx: TSemaOverloadContext;
  const APrevIndex: LongInt): LongInt;
function LookupOverload(const AName: string; AArgCount: LongInt;
  const AProcedureBodies: TProcedureBodyVec;
  out ABody: TGreenNode; out ADecl: TGreenNode): Boolean;
function TypeIdArrayHasKnownTypes(const ATypeIds: TTypeIdArray): Boolean;
function GetParamIdentitySignature(const ADecl: TGreenNode): string;

{ 单元导入查询 }
function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaImportContext; const AOwnerUnitId: string): Boolean;
function UnitDirectlyImports(
  const Ctx: TSemaImportContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean;

{ === 重载解析核心 — 从 TSemanticAnalyzer 提取 === }

function GetParamSignature(const Ctx: TSemaOverloadContext; const ADecl: TGreenNode): string;
function DeclParamSignatureMatchesArgs(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AArgSignature: string;
  const AArgCount: LongInt): Boolean;
function DeclParamTypesExactMatch(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt): Boolean;
function DeclParamTypesCompatibleMatch(const Ctx: TSemaOverloadContext;
  const ADecl: TGreenNode;
  const AOwnerUnitId: string;
  const AArgTypeIds: TTypeIdArray;
  const AArgCount: LongInt): Boolean;
function CanonicalTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): LongInt;
function ParamDeclTypeId(const Ctx: TSemaOverloadContext;
  const AParamDecl: TGreenNode;
  const AOwnerUnitId: string): LongInt;
function AreTypesCompatible(const Ctx: TSemaOverloadContext;
  const ALhsTypeId, ARhsTypeId: LongInt): Boolean;
function IsPointerTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): Boolean;
function ResolveTypeId(const Ctx: TSemaOverloadContext; const ATypeName: string): LongInt;
function ResolveTypeIdForOwner(const Ctx: TSemaOverloadContext;
  const ATypeName: string;
  const APreferredOwnerUnitId: string;
  const AAllowDirectImportSearch: Boolean = True): LongInt;
function TypeSignatureForTypeId(const Ctx: TSemaOverloadContext; const ATypeId: LongInt): string;
function LookupCallBindingDeclaration(const Ctx: TSemaOverloadContext;
  const AName: string;
  const AArgCount: LongInt;
  const AArgTypeIds: TTypeIdArray;
  const AArgSignature: string;
  const AHasArgSignature: Boolean;
  const AHasTypeMismatchEvidence: Boolean;
  out AResolutionFailureKind: string;
  out ABody: TGreenNode;
  out ADecl: TGreenNode;
  out AOwnerUnitId: string): Boolean;

{ 辅助查询函数 }
function HasInstalledSourceImports(const Ctx: TSemaOverloadContext): Boolean;

{ 重载：接受 TSemaOverloadContext 的导入查询函数 }
function OwnerUnitAllowsProjectSourceDiagnostic(
  const Ctx: TSemaOverloadContext; const AOwnerUnitId: string): Boolean; overload;
function UnitDirectlyImports(
  const Ctx: TSemaOverloadContext;
  const AOwnerUnitId, AImportedUnitId: string): Boolean; overload;

implementation

{ === 重载解析核心实现 === }

{$I np_sema_overload_helpers.inc}

{$I np_sema_overload_types.inc}


{$I np_sema_overload_lookup.inc}

end.
