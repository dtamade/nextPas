{**
 * np_mir_pass_cse.pas — MIR Common Subexpression Elimination Pass
 *
 * 消除重复计算。
 *
 * 算法（局部 CSE，单基本块内）：
 *   1. 遍历基本块内的语句
 *   2. 维护 "表达式 → 寄存器" 的哈希表
 *   3. 遇到重复表达式时，用已有寄存器替换
 *
 * 表达式指纹：Op + Lhs.Value + Rhs.Value（或 Src.Value）
 *
 * 对标：rustc mir::transform::cse, LLVM EarlyCSE
 *}

unit np_mir_pass_cse;

{$mode objfpc}{$H+}

interface

uses
  np_mir_model, np_mir_optimize;

type
  TMirCsePass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

uses
  SysUtils;

type
  TCseEntry = record
    Fingerprint: string;
    ResultReg: TMirValueId;
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
  CseTable: array of TCseEntry;
  Found: Boolean;
  ElimCount: LongInt;
begin
  Result := True;
  ElimCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    for BlkIdx := 0 to High(Fn.Blocks) do
    begin
      SetLength(CseTable, 0);

      for StmtIdx := 0 to High(Fn.Blocks[BlkIdx].Stmts) do
      begin
        if not AModule.GetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt) then
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
        for I := 0 to High(CseTable) do
          if CseTable[I].Fingerprint = Fingerprint then
          begin
            { Replace with cached result }
            Stmt.Kind := mskAssign;
            Stmt.Src.Kind := mokMove;
            Stmt.Src.Value := CseTable[I].ResultReg;
            AModule.SetStmt(FuncIdx, Fn.Blocks[BlkIdx].Id, StmtIdx, Stmt);
            Found := True;
            Inc(ElimCount);
            Break;
          end;

        { Not found — add to CSE table }
        if not Found and (Stmt.Dst > 0) then
        begin
          I := Length(CseTable);
          SetLength(CseTable, I + 1);
          CseTable[I].Fingerprint := Fingerprint;
          CseTable[I].ResultReg := Stmt.Dst;
        end;
      end;
    end;
  end;
end;

end.
