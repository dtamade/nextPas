unit np_ast_facade;

{$mode objfpc}{$H+}
{$UNITPATH .}

interface

uses
  np_green_tree;

type
  TAstFacade = class
  private
    FGreenTree: TGreenTree;
  public
    constructor Create(const AGreenTree: TGreenTree);
    function RootKindName: string;
    function DeclaredName: string;
    function IsValid: Boolean;
    function InterfaceUseCount: LongInt;
    function InterfaceUseAt(const AIndex: LongInt): string;
    function ImplementationUseCount: LongInt;
    function ImplementationUseAt(const AIndex: LongInt): string;
    function ForeignProcedureDeclCount: LongInt;
    function ForeignProcedureDeclAt(
      const AIndex: LongInt
    ): TForeignProcedureDecl;
    function RootNodeChildCount: LongInt;
    function RootNodeChildAt(const AIndex: LongInt): TGreenNode;
    function VarSectionCount: LongInt;
    function ProcedureDeclCount: LongInt;
    function FunctionDeclCount: LongInt;
  end;

implementation

constructor TAstFacade.Create(const AGreenTree: TGreenTree);
begin
  inherited Create;
  FGreenTree := AGreenTree;
end;

function TAstFacade.RootKindName: string;
begin
  if FGreenTree = nil then
    Exit('unknown');

  Result := FGreenTree.RootKindName;
end;

function TAstFacade.DeclaredName: string;
begin
  if FGreenTree = nil then
    Exit('');

  Result := FGreenTree.DeclaredName;
end;

function TAstFacade.IsValid: Boolean;
begin
  Result := (FGreenTree <> nil) and FGreenTree.IsValid;
end;

function TAstFacade.InterfaceUseCount: LongInt;
begin
  if FGreenTree = nil then
    Exit(0);

  Result := FGreenTree.InterfaceUseCount;
end;

function TAstFacade.InterfaceUseAt(const AIndex: LongInt): string;
begin
  if FGreenTree = nil then
    Exit('');

  Result := FGreenTree.InterfaceUseAt(AIndex);
end;

function TAstFacade.ImplementationUseCount: LongInt;
begin
  if FGreenTree = nil then
    Exit(0);

  Result := FGreenTree.ImplementationUseCount;
end;

function TAstFacade.ImplementationUseAt(const AIndex: LongInt): string;
begin
  if FGreenTree = nil then
    Exit('');

  Result := FGreenTree.ImplementationUseAt(AIndex);
end;

function TAstFacade.ForeignProcedureDeclCount: LongInt;
begin
  if FGreenTree = nil then
    Exit(0);

  Result := FGreenTree.ForeignProcedureDeclCount;
end;

function TAstFacade.ForeignProcedureDeclAt(
  const AIndex: LongInt
): TForeignProcedureDecl;
begin
  if FGreenTree = nil then
  begin
    Result.ProcedureName := '';
    Result.CallingConvention := '';
    Result.LibraryId := '';
    Result.ExternalSymbolName := '';
    Result.HasExplicitSymbolName := False;
    Result.ByteOffset := 0;
    Exit;
  end;

  Result := FGreenTree.ForeignProcedureDeclAt(AIndex);
end;

function TAstFacade.RootNodeChildCount: LongInt;
begin
  if (FGreenTree = nil) or (FGreenTree.RootNode = nil) then
    Exit(0);
  Result := FGreenTree.RootNode.ChildCount;
end;

function TAstFacade.RootNodeChildAt(const AIndex: LongInt): TGreenNode;
begin
  if (FGreenTree = nil) or (FGreenTree.RootNode = nil) then
    Exit(nil);
  if (AIndex < 0) or (AIndex >= FGreenTree.RootNode.ChildCount) then
    Exit(nil);
  Result := FGreenTree.RootNode.ChildAt(AIndex);
end;

function CountNodeKindInChildren(const ANode: TGreenNode;
  const AKind: TGreenNodeKind): LongInt;
var
  I: LongInt;
  Child: TGreenNode;
begin
  Result := 0;
  if ANode = nil then
    Exit;
  for I := 0 to ANode.ChildCount - 1 do
  begin
    Child := ANode.ChildAt(I);
    if Child <> nil then
    begin
      if Child.NodeKind = AKind then
        Inc(Result);
      Inc(Result, CountNodeKindInChildren(Child, AKind));
    end;
  end;
end;

function TAstFacade.VarSectionCount: LongInt;
begin
  if (FGreenTree = nil) or (FGreenTree.RootNode = nil) then
    Exit(0);
  Result := CountNodeKindInChildren(FGreenTree.RootNode, gnkVarSection);
end;

function TAstFacade.ProcedureDeclCount: LongInt;
begin
  if (FGreenTree = nil) or (FGreenTree.RootNode = nil) then
    Exit(0);
  Result := CountNodeKindInChildren(FGreenTree.RootNode, gnkProcedureDecl);
end;

function TAstFacade.FunctionDeclCount: LongInt;
begin
  if (FGreenTree = nil) or (FGreenTree.RootNode = nil) then
    Exit(0);
  Result := CountNodeKindInChildren(FGreenTree.RootNode, gnkFunctionDecl);
end;

end.
