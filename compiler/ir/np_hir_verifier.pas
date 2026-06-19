unit np_hir_verifier;

{$mode objfpc}{$H+}

interface

uses
  np_hir_types, np_hir_model;

type
  THIRVerifyError = record
    FuncName: string;
    BlockId: THIRBlockId;
    Message: string;
  end;

  THIRVerifier = class
  private
    FModule: THIRModule;
    FErrors: array of THIRVerifyError;
    procedure AddError(const AFuncName: string; ABlockId: THIRBlockId;
      const AMsg: string);
    procedure VerifyFunction(const AFunc: THIRFunction);
    procedure VerifySSADefs(const AFunc: THIRFunction);
    procedure VerifySSAUses(const AFunc: THIRFunction);
    procedure VerifyTerminators(const AFunc: THIRFunction);
    procedure VerifyTypes(const AFunc: THIRFunction);
  public
    constructor Create(AModule: THIRModule);
    function Verify: Boolean;
    function ErrorCount: LongInt;
    function ErrorAt(AIndex: LongInt): THIRVerifyError;
  end;

implementation

uses
  nextpas.core.text.conv;

constructor THIRVerifier.Create(AModule: THIRModule);
begin
  inherited Create;
  FModule := AModule;
  SetLength(FErrors, 0);
end;

procedure THIRVerifier.AddError(const AFuncName: string;
  ABlockId: THIRBlockId; const AMsg: string);
var
  Idx: SizeInt;
begin
  Idx := Length(FErrors);
  SetLength(FErrors, Idx + 1);
  FErrors[Idx].FuncName := AFuncName;
  FErrors[Idx].BlockId := ABlockId;
  FErrors[Idx].Message := AMsg;
end;

procedure THIRVerifier.VerifySSADefs(const AFunc: THIRFunction);
var
  BI, II: LongInt;
  Seen: array of THIRValueId;
  SeenCount: LongInt;
  V: THIRValueId;
  J: LongInt;
  Found: Boolean;
begin
  SetLength(Seen, 0);
  SeenCount := 0;

  for BI := 0 to High(AFunc.Blocks) do
    for II := 0 to High(AFunc.Blocks[BI].Instrs) do
    begin
      V := AFunc.Blocks[BI].Instrs[II].ResultId;
      if V = 0 then
      begin
        AddError(AFunc.Name, AFunc.Blocks[BI].Id,
          'Instruction has zero ResultId');
        Continue;
      end;

      Found := False;
      for J := 0 to SeenCount - 1 do
        if Seen[J] = V then
        begin
          Found := True;
          Break;
        end;

      if Found then
        AddError(AFunc.Name, AFunc.Blocks[BI].Id,
          'SSA violation: %%' + IntToStr(V) + ' defined more than once')
      else
      begin
        if SeenCount >= Length(Seen) then
          SetLength(Seen, SeenCount + 64);
        Seen[SeenCount] := V;
        Inc(SeenCount);
      end;
    end;
end;

procedure THIRVerifier.VerifySSAUses(const AFunc: THIRFunction);
var
  BI, II, OI, PI, J: LongInt;
  Defs: array of THIRValueId;
  DefCount: LongInt;
  V: THIRValueId;
  Found: Boolean;
begin
  SetLength(Defs, 0);
  DefCount := 0;

  for PI := 0 to High(AFunc.Params) do
  begin
    if DefCount >= Length(Defs) then
      SetLength(Defs, DefCount + 64);
    Defs[DefCount] := AFunc.Params[PI].ValueId;
    Inc(DefCount);
  end;

  for BI := 0 to High(AFunc.Blocks) do
    for II := 0 to High(AFunc.Blocks[BI].Instrs) do
    begin
      V := AFunc.Blocks[BI].Instrs[II].ResultId;
      if V <> 0 then
      begin
        if DefCount >= Length(Defs) then
          SetLength(Defs, DefCount + 64);
        Defs[DefCount] := V;
        Inc(DefCount);
      end;
    end;

  for BI := 0 to High(AFunc.Blocks) do
    for II := 0 to High(AFunc.Blocks[BI].Instrs) do
    begin
      if AFunc.Blocks[BI].Instrs[II].Kind = hikPhi then
        Continue;

      for OI := 0 to High(AFunc.Blocks[BI].Instrs[II].Operands) do
      begin
        V := AFunc.Blocks[BI].Instrs[II].Operands[OI].ValueId;
        Found := False;
        for J := 0 to DefCount - 1 do
          if Defs[J] = V then
          begin
            Found := True;
            Break;
          end;
        if not Found then
          AddError(AFunc.Name, AFunc.Blocks[BI].Id,
            'Use of undefined value %%' + IntToStr(V));
      end;
    end;
end;

procedure THIRVerifier.VerifyTerminators(const AFunc: THIRFunction);
var
  BI: LongInt;
begin
  if Length(AFunc.Blocks) = 0 then
  begin
    if not AFunc.IsExternal then
      AddError(AFunc.Name, 0, 'Non-external function has no blocks');
    Exit;
  end;

  for BI := 0 to High(AFunc.Blocks) do
    if AFunc.Blocks[BI].Terminator.Kind = htkUnreachable then
      if (Length(AFunc.Blocks[BI].Instrs) > 0) or (BI = 0) then
        { unreachable is valid as a placeholder only for truly dead blocks }
        ;
end;

procedure THIRVerifier.VerifyTypes(const AFunc: THIRFunction);
var
  BI, II: LongInt;
  Instr: THIRInstr;
begin
  for BI := 0 to High(AFunc.Blocks) do
    for II := 0 to High(AFunc.Blocks[BI].Instrs) do
    begin
      Instr := AFunc.Blocks[BI].Instrs[II];
      if Instr.Kind = hikAlloca then
      begin
        if Instr.TypeId = 0 then
          AddError(AFunc.Name, AFunc.Blocks[BI].Id,
            'alloca %%' + IntToStr(Instr.ResultId) + ' has no type');
      end;
      if Instr.Kind in [hikAdd, hikSub, hikMul, hikDiv, hikMod] then
      begin
        if Length(Instr.Operands) < 2 then
          AddError(AFunc.Name, AFunc.Blocks[BI].Id,
            'Arithmetic op %%' + IntToStr(Instr.ResultId) + ' needs 2 operands');
      end;
      if Instr.Kind = hikCall then
      begin
        if Instr.CallTarget = '' then
          AddError(AFunc.Name, AFunc.Blocks[BI].Id,
            'call %%' + IntToStr(Instr.ResultId) + ' has empty target');
      end;
    end;
end;

procedure THIRVerifier.VerifyFunction(const AFunc: THIRFunction);
begin
  VerifySSADefs(AFunc);
  VerifySSAUses(AFunc);
  VerifyTerminators(AFunc);
  VerifyTypes(AFunc);
end;

function THIRVerifier.Verify: Boolean;
var
  I: LongInt;
begin
  SetLength(FErrors, 0);
  for I := 0 to FModule.FunctionCount - 1 do
    VerifyFunction(FModule.FunctionAt(I));
  Result := Length(FErrors) = 0;
end;

function THIRVerifier.ErrorCount: LongInt;
begin
  Result := Length(FErrors);
end;

function THIRVerifier.ErrorAt(AIndex: LongInt): THIRVerifyError;
begin
  Result := FErrors[AIndex];
end;

end.
