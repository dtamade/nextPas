unit np_mir_model;

{$mode objfpc}{$H+}
{$UNITPATH ../sema}

interface

uses
  np_semantic_model;

type
  TMirBlock = record
    BlockId: LongInt;
    LabelName: string;
  end;

  TMirOperation = record
    OperationId: LongInt;
    Kind: string;
    BlockId: LongInt;
    DisplayName: string;
  end;

  TMirModel = class
  private
    FBlocks: array of TMirBlock;
    FOperations: array of TMirOperation;
    FRootName: string;
    FStatus: string;
  public
    constructor Create;
    function AddBlock(const ALabelName: string): LongInt;
    function AddOperation(
      const AKind: string;
      const ABlockId: LongInt;
      const ADisplayName: string
    ): LongInt;
    function BlockCount: LongInt;
    function OperationCount: LongInt;
    function EntryBlockLabel: string;
    procedure SetRootName(const AName: string);
    function RootName: string;
    procedure MarkReady;
    procedure MarkFailure;
    function Status: string;
  end;

  TMirLowerer = class
  private
    FSemanticModel: TSemanticModel;
    FModel: TMirModel;
    function MirKindForTypedHirNode(const ANode: TTypedHirNode): string;
  public
    constructor Create(const ASemanticModel: TSemanticModel);
    destructor Destroy; override;
    procedure Lower;
    function DetachModel: TMirModel;
  end;

implementation

constructor TMirModel.Create;
begin
  inherited Create;
  SetLength(FBlocks, 0);
  SetLength(FOperations, 0);
  FRootName := '';
  FStatus := 'deferred';
end;

function TMirModel.AddBlock(const ALabelName: string): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FBlocks);
  SetLength(FBlocks, NextIndex + 1);
  FBlocks[NextIndex].BlockId := NextIndex + 1;
  FBlocks[NextIndex].LabelName := ALabelName;
  Result := FBlocks[NextIndex].BlockId;
end;

function TMirModel.AddOperation(
  const AKind: string;
  const ABlockId: LongInt;
  const ADisplayName: string
): LongInt;
var
  NextIndex: SizeInt;
begin
  NextIndex := Length(FOperations);
  SetLength(FOperations, NextIndex + 1);
  FOperations[NextIndex].OperationId := NextIndex + 1;
  FOperations[NextIndex].Kind := AKind;
  FOperations[NextIndex].BlockId := ABlockId;
  FOperations[NextIndex].DisplayName := ADisplayName;
  Result := FOperations[NextIndex].OperationId;
end;

function TMirModel.BlockCount: LongInt;
begin
  Result := Length(FBlocks);
end;

function TMirModel.OperationCount: LongInt;
begin
  Result := Length(FOperations);
end;

function TMirModel.EntryBlockLabel: string;
begin
  if Length(FBlocks) = 0 then
    Exit('');

  Result := FBlocks[0].LabelName;
end;

procedure TMirModel.SetRootName(const AName: string);
begin
  FRootName := AName;
end;

function TMirModel.RootName: string;
begin
  Result := FRootName;
end;

procedure TMirModel.MarkReady;
begin
  FStatus := 'ready';
end;

procedure TMirModel.MarkFailure;
begin
  FStatus := 'failure';
end;

function TMirModel.Status: string;
begin
  Result := FStatus;
end;

function TMirLowerer.MirKindForTypedHirNode(const ANode: TTypedHirNode): string;
begin
  if ANode.Kind = 'compilation-root' then
    Exit('enter-root');
  if ANode.Kind = 'resolved-unit' then
    Exit('unit-ref');
  if ANode.Kind = 'runtime-contract' then
    Exit('runtime-contract-call');

  Result := 'typed-hir-node';
end;

constructor TMirLowerer.Create(const ASemanticModel: TSemanticModel);
begin
  inherited Create;
  FSemanticModel := ASemanticModel;
  FModel := TMirModel.Create;
end;

destructor TMirLowerer.Destroy;
begin
  FModel.Free;
  inherited Destroy;
end;

procedure TMirLowerer.Lower;
var
  BlockId: LongInt;
  Index: LongInt;
  Node: TTypedHirNode;
begin
  if (FSemanticModel = nil) or (FSemanticModel.Status <> 'ready') then
  begin
    FModel.MarkFailure;
    Exit;
  end;

  FModel.SetRootName(FSemanticModel.RootName);
  BlockId := FModel.AddBlock('entry');

  for Index := 0 to FSemanticModel.TypedHirNodeCount - 1 do
  begin
    Node := FSemanticModel.TypedHirNodeAt(Index);
    FModel.AddOperation(
      MirKindForTypedHirNode(Node),
      BlockId,
      Node.DisplayName
    );
  end;

  FModel.AddOperation('return', BlockId, FSemanticModel.RootName);
  FModel.MarkReady;
end;

function TMirLowerer.DetachModel: TMirModel;
begin
  Result := FModel;
  FModel := nil;
end;

end.
