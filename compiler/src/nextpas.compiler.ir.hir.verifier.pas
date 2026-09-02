unit nextpas.compiler.ir.hir.verifier;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.compiler.ir.hir.types, nextpas.compiler.ir.hir.model;

type
  THIRVerifyError = record
    FuncName: string;
    BlockId: THIRBlockId;
    Message: string;
  end;

  THirVerifyErrorVec = specialize TVec<THIRVerifyError>;
  THirValueIdVec = specialize TVec<THIRValueId>;

  THIRVerifier = class
  private
    FModule: THIRModule;
    FAllocator: IAllocator;
    FErrors: THirVerifyErrorVec;
    function CreateValueIdVec: THirValueIdVec;
    procedure AddError(const AFuncName: string; ABlockId: THIRBlockId;
      const AMsg: string);
    procedure VerifyFunction(const AFunc: THIRFunction);
    procedure VerifySSADefs(const AFunc: THIRFunction);
    procedure VerifySSAUses(const AFunc: THIRFunction);
    procedure VerifyTerminators(const AFunc: THIRFunction);
    procedure VerifyTypes(const AFunc: THIRFunction);
    procedure VerifySystemContractSequences(const AFunc: THIRFunction);
  public
    constructor Create(AModule: THIRModule; AAllocator: IAllocator = nil);
    destructor Destroy; override;
    function Verify: Boolean;
    function ErrorCount: LongInt;
    function ErrorAt(AIndex: LongInt): THIRVerifyError;
  end;

implementation

uses
  nextpas.core.text.conv, nextpas.compiler.ir.system_contracts;

constructor THIRVerifier.Create(AModule: THIRModule; AAllocator: IAllocator);
begin
  inherited Create;
  FModule := AModule;
  FAllocator := AAllocator;
  if FAllocator <> nil then
    FErrors := THirVerifyErrorVec.Create(0, FAllocator)
  else
    FErrors := THirVerifyErrorVec.Create;
end;

destructor THIRVerifier.Destroy;
begin
  FErrors.Free;
  inherited Destroy;
end;

function THIRVerifier.CreateValueIdVec: THirValueIdVec;
begin
  if FAllocator <> nil then
    Result := THirValueIdVec.Create(0, FAllocator)
  else
    Result := THirValueIdVec.Create;
end;

procedure THIRVerifier.AddError(const AFuncName: string;
  ABlockId: THIRBlockId; const AMsg: string);
var
  Err: THIRVerifyError;
begin
  Err.FuncName := AFuncName;
  Err.BlockId := ABlockId;
  Err.Message := AMsg;
  FErrors.Push(Err);
end;

procedure THIRVerifier.VerifySSADefs(const AFunc: THIRFunction);
var
  BI, II: LongInt;
  Seen: THirValueIdVec;
  V: THIRValueId;
  J: LongInt;
  Found: Boolean;
begin
  Seen := CreateValueIdVec;
  try
    if AFunc.Blocks <> nil then
      for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
        if AFunc.Blocks[SizeUInt(BI)].Instrs <> nil then
          for II := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count) - 1 do
          begin
            V := AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)].ResultId;
            if V = 0 then
            begin
              AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
                'Instruction has zero ResultId');
              Continue;
            end;

            Found := False;
            for J := 0 to LongInt(Seen.Count) - 1 do
              if Seen[J] = V then
              begin
                Found := True;
                Break;
              end;

            if Found then
              AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
                'SSA violation: %%' + IntToStr(V) + ' defined more than once')
            else
              Seen.Push(V);
          end;
  finally
    Seen.Free;
  end;
end;

procedure THIRVerifier.VerifySSAUses(const AFunc: THIRFunction);
var
  BI, II, OI, PI, J: LongInt;
  Defs: THirValueIdVec;
  V: THIRValueId;
  Found: Boolean;
begin
  Defs := CreateValueIdVec;
  try
    if AFunc.Params <> nil then
      for PI := 0 to LongInt(AFunc.Params.Count) - 1 do
        Defs.Push(AFunc.Params[SizeUInt(PI)].ValueId);

    if AFunc.Blocks <> nil then
      for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
        if AFunc.Blocks[SizeUInt(BI)].Instrs <> nil then
          for II := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count) - 1 do
          begin
            V := AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)].ResultId;
            if V <> 0 then
              Defs.Push(V);
          end;

    if AFunc.Blocks <> nil then
      for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
        if AFunc.Blocks[SizeUInt(BI)].Instrs <> nil then
          for II := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count) - 1 do
          begin
            if AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)].Kind = hikPhi then
              Continue;

            for OI := 0 to High(
              AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)].Operands) do
            begin
              V := AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)]
                .Operands[OI].ValueId;
              Found := False;
              for J := 0 to LongInt(Defs.Count) - 1 do
                if Defs[J] = V then
                begin
                  Found := True;
                  Break;
                end;
              if not Found then
                AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
                  'Use of undefined value %%' + IntToStr(V));
            end;
          end;
  finally
    Defs.Free;
  end;
end;

procedure THIRVerifier.VerifyTerminators(const AFunc: THIRFunction);
var
  BI: LongInt;
begin
  if (AFunc.Blocks = nil) or (AFunc.Blocks.Count = 0) then
  begin
    if not AFunc.IsExternal then
      AddError(AFunc.Name, 0, 'Non-external function has no blocks');
    Exit;
  end;

  for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    if AFunc.Blocks[SizeUInt(BI)].Terminator.Kind = htkUnreachable then
      if ((AFunc.Blocks[SizeUInt(BI)].Instrs <> nil) and
        (AFunc.Blocks[SizeUInt(BI)].Instrs.Count > 0)) or (BI = 0) then
        { unreachable is valid as a placeholder only for truly dead blocks }
        ;
end;

procedure THIRVerifier.VerifyTypes(const AFunc: THIRFunction);
var
  BI, II: LongInt;
  Instr: THIRInstr;
  ContractError: string;
begin
  if AFunc.Blocks = nil then
    Exit;
  for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
    if AFunc.Blocks[SizeUInt(BI)].Instrs <> nil then
      for II := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count) - 1 do
      begin
        Instr := AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)];
        if Instr.HasSystemContract and
          (not ValidateSystemContractInstr(Instr, FModule.Types,
            ContractError)) then
          AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id, ContractError);
        if Instr.Kind = hikAlloca then
        begin
          if Instr.TypeId = 0 then
            AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
              'alloca %%' + IntToStr(Instr.ResultId) + ' has no type');
        end;
        if Instr.Kind in [hikAdd, hikSub, hikMul, hikDiv, hikMod] then
        begin
          if Length(Instr.Operands) < 2 then
            AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
              'Arithmetic op %%' + IntToStr(Instr.ResultId) +
              ' needs 2 operands');
        end;
        if Instr.Kind = hikCall then
        begin
          if Instr.CallTarget = '' then
            AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
              'call %%' + IntToStr(Instr.ResultId) + ' has empty target');
        end;
      end;
end;

procedure THIRVerifier.VerifySystemContractSequences(
  const AFunc: THIRFunction);
var
  BI, II: LongInt;
  GuardActive: Boolean;
  GuardReceiverValueId: THIRValueId;
  GuardDestroyTarget: string;
  Instr: THIRInstr;
  ContractError: string;
begin
  if AFunc.Blocks = nil then
    Exit;
  for BI := 0 to LongInt(AFunc.Blocks.Count) - 1 do
  begin
    GuardActive := False;
    GuardReceiverValueId := 0;
    GuardDestroyTarget := '';
    if AFunc.Blocks[SizeUInt(BI)].Instrs = nil then
      Continue;
    for II := 0 to LongInt(AFunc.Blocks[SizeUInt(BI)].Instrs.Count) - 1 do
    begin
      Instr := AFunc.Blocks[SizeUInt(BI)].Instrs[SizeUInt(II)];
      if not Instr.HasSystemContract then
      begin
        GuardActive := False;
        GuardReceiverValueId := 0;
        GuardDestroyTarget := '';
        Continue;
      end;
      if not ValidateSystemContractInstr(Instr, FModule.Types,
        ContractError) then
        Continue;

      case Instr.SystemContractKind of
        sckObjectFree:
        begin
          GuardActive := True;
          GuardReceiverValueId := Instr.Operands[0].ValueId;
          GuardDestroyTarget := Instr.CallTarget;
        end;
        sckObjectFreeDestroy,
        sckObjectFreeCleanup,
        sckObjectFreeRelease:
        begin
          if not GuardActive then
            AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id,
              'system-contract-sequence-root-missing:' +
              IntToStr(Ord(Instr.SystemContractKind)))
          else if not ValidateObjectFreeSequenceContinuation(
            GuardReceiverValueId, Instr.Operands[0].ValueId,
            GuardDestroyTarget, Instr.CallTarget,
            Instr.SystemContractKind, ContractError) then
            AddError(AFunc.Name, AFunc.Blocks[SizeUInt(BI)].Id, ContractError);
          if Instr.SystemContractKind = sckObjectFreeRelease then
          begin
            GuardActive := False;
            GuardReceiverValueId := 0;
            GuardDestroyTarget := '';
          end;
        end;
      else
        ;
      end;
    end;
  end;
end;

procedure THIRVerifier.VerifyFunction(const AFunc: THIRFunction);
begin
  VerifySSADefs(AFunc);
  VerifySSAUses(AFunc);
  VerifyTerminators(AFunc);
  VerifyTypes(AFunc);
  VerifySystemContractSequences(AFunc);
end;

function THIRVerifier.Verify: Boolean;
var
  I: LongInt;
begin
  FErrors.Clear;
  for I := 0 to FModule.FunctionCount - 1 do
    VerifyFunction(FModule.FunctionAt(I));
  Result := FErrors.Count = 0;
end;

function THIRVerifier.ErrorCount: LongInt;
begin
  Result := LongInt(FErrors.Count);
end;

function THIRVerifier.ErrorAt(AIndex: LongInt): THIRVerifyError;
begin
  if (AIndex < 0) or (AIndex >= LongInt(FErrors.Count)) then
  begin
    Result.FuncName := '';
    Result.BlockId := 0;
    Result.Message := '';
    Exit;
  end;
  Result := FErrors[AIndex];
end;

end.
