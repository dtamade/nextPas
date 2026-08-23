{**
 * nextpas.compiler.ir.mir.pass.cse.pas — MIR Common Subexpression Elimination Pass
 *
 * 消除重复计算。
 *
 * 算法（局部 CSE，单基本块内）：
 *   1. 遍历基本块内的语句
 *   2. 维护 "表达式 → 寄存器" 的哈希表
 *   3. 遇到重复表达式时，用已有寄存器替换
 *
 * 表达式指纹：Op + Lhs.Value + Rhs.Value（或 Src.Value）
 * CseTable 可挂 phase-scratch IAllocator（TVec on PhaseScratch）。
 *
 * 对标：rustc mir::transform::cse, LLVM EarlyCSE
 *}

unit nextpas.compiler.ir.mir.pass.cse;

{$mode objfpc}{$H+}
{$UNITPATH ../../core/src}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize,
  nextpas.core.mem.intf,
  nextpas.core.collections.vec;

type
  TCseEntry = record
    Fingerprint: string;
    ResultReg: TMirValueId;
  end;

  TMirCseEntryVec = specialize TVec<TCseEntry>;

  TMirCsePass = class(TInterfacedObject, IMirOptimizationPass)
  private
    FAllocator: IAllocator;
  public
    constructor Create(AAllocator: IAllocator = nil);
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

uses
  SysUtils;

constructor TMirCsePass.Create(AAllocator: IAllocator);
begin
  inherited Create;
  FAllocator := AAllocator;
end;

function BuildBinaryFingerprint(const AOp: TMirOp;
  const ALhs, ARhs: TMirOperand): string;
begin
  Result := 'b' + IntToStr(Ord(AOp)) + ':' +
    IntToStr(Ord(ALhs.Kind)) + ':' + IntToStr(ALhs.Value) + ':' +
    IntToStr(Ord(ARhs.Kind)) + ':' + IntToStr(ARhs.Value);
end;

function BuildUnaryFingerprint(const AOp: TMirOp;
  const ASrc: TMirOperand): string;
begin
  Result := 'u' + IntToStr(Ord(AOp)) + ':' +
    IntToStr(Ord(ASrc.Kind)) + ':' + IntToStr(ASrc.Value);
end;

function TMirCsePass.Name: string;
begin
  Result := 'cse';
end;

function TMirCsePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx, StmtIdx, I: LongInt;
  Fn: TMirFunction;
  Stmt: TMirStmt;
  Fingerprint: string;
  CseTable: TMirCseEntryVec;
  Entry: TCseEntry;
  Found: Boolean;
  ElimCount: LongInt;
begin
  Result := True;
  ElimCount := 0;

  if FAllocator <> nil then
    CseTable := TMirCseEntryVec.Create(0, FAllocator)
  else
    CseTable := TMirCseEntryVec.Create;
  try
    for FuncIdx := 0 to AModule.FunctionCount - 1 do
    begin
      Fn := AModule.FunctionAt(FuncIdx);

      if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
      begin
        CseTable.Clear;

        if Fn.Blocks[SizeUInt(BlkIdx)].Stmts <> nil then
          for StmtIdx := 0 to LongInt(Fn.Blocks[SizeUInt(BlkIdx)].Stmts.Count) - 1 do
        begin
          if not AModule.GetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt) then
            Continue;

          { Build fingerprint }
          case Stmt.Kind of
            mskBinary:
              Fingerprint := BuildBinaryFingerprint(Stmt.Op, Stmt.Lhs, Stmt.Rhs);
            mskUnary:
              Fingerprint := BuildUnaryFingerprint(Stmt.Op, Stmt.Src);
            else
              Fingerprint := '';
          end;

          if Fingerprint = '' then
            Continue;

          { Search CSE table }
          Found := False;
          for I := 0 to LongInt(CseTable.Count) - 1 do
            if CseTable[I].Fingerprint = Fingerprint then
            begin
              { Replace with cached result }
              Stmt.Kind := mskAssign;
              Stmt.Src.Kind := mokMove;
              Stmt.Src.Value := CseTable[I].ResultReg;
              AModule.SetStmt(FuncIdx, Fn.Blocks[SizeUInt(BlkIdx)].Id, StmtIdx, Stmt);
              Found := True;
              Inc(ElimCount);
              Break;
            end;

          { Not found — add to CSE table }
          if not Found and (Stmt.Dst > 0) then
          begin
            Entry.Fingerprint := Fingerprint;
            Entry.ResultReg := Stmt.Dst;
            CseTable.Push(Entry);
          end;
        end;
      end;
    end;
  finally
    CseTable.Free;
  end;
end;

end.
