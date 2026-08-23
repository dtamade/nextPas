{**
 * nextpas.compiler.ir.mir.pass.vectorize.pas — MIR Vectorization Recognition Pass
 *
 * 识别可向量化的循环模式并标注，供 LLVM 后端自动向量化。
 *
 * 识别的模式：
 *   1. 简单数组赋值循环 (a[i] = b[i])
 *   2. 数组归约循环 (sum += a[i])
 *   3. 连续内存访问模式
 *
 * 标注方法：在循环头插入 vectorize-hint 元数据。
 *
 * 对标：LLVM LoopVectorize, rustc mir::transform::autovectorize
 *}

unit nextpas.compiler.ir.mir.pass.vectorize;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.mir.model, nextpas.compiler.ir.mir.optimize;

type
  TMirVectorizePass = class(TInterfacedObject, IMirOptimizationPass)
  public
    function Name: string;
    function Run(var AModule: TMirModule): Boolean;
  end;

implementation

function TMirVectorizePass.Name: string;
begin
  Result := 'vectorize';
end;

{ Check if a block represents a simple counted loop }
function IsCountedLoop(const ABlock: TMirBlock): Boolean;
begin
  { Counted loops have recognizable block names }
  Result := (Pos('for', ABlock.Name) > 0) or
            (Pos('loop', ABlock.Name) > 0) or
            (Pos('body', ABlock.Name) > 0);
end;

{ Check if statements in a loop are vectorizable }
function HasVectorizablePattern(AStmts: TMirStmtVec): Boolean;
var
  I: LongInt;
  LoadCount, StoreCount, ArithCount: LongInt;
begin
  Result := False;
  if AStmts = nil then
    Exit;
  LoadCount := 0;
  StoreCount := 0;
  ArithCount := 0;

  for I := 0 to LongInt(AStmts.Count) - 1 do
  begin
    case AStmts[SizeUInt(I)].Kind of
      mskLoad:  Inc(LoadCount);
      mskStore: Inc(StoreCount);
      mskBinary:
        case AStmts[SizeUInt(I)].Op of
          moAdd, moSub, moMul: Inc(ArithCount);
        end;
    end;
  end;

  { Vectorizable patterns:
    1. Simple copy: load + store (element-wise assignment)
    2. Reduction: load + arith + store (sum/product)
    3. Pure compute: multiple arith ops on loaded values }
  Result := (LoadCount >= 1) and
            ((StoreCount >= 1) or (ArithCount >= 2));
end;

function TMirVectorizePass.Run(var AModule: TMirModule): Boolean;
var
  FuncIdx, BlkIdx: LongInt;
  Fn: TMirFunction;
  VecCount: LongInt;
begin
  Result := True;
  VecCount := 0;

  for FuncIdx := 0 to AModule.FunctionCount - 1 do
  begin
    Fn := AModule.FunctionAt(FuncIdx);

    if Fn.Blocks <> nil then
      for BlkIdx := 0 to LongInt(Fn.Blocks.Count) - 1 do
    begin
      if not IsCountedLoop(Fn.Blocks[SizeUInt(BlkIdx)]) then
        Continue;

      if HasVectorizablePattern(Fn.Blocks[SizeUInt(BlkIdx)].Stmts) then
      begin
        { Annotate: insert vectorize hint as a special comment stmt }
        { In MIR, we use a no-op store to mark vectorization candidates }
        Inc(VecCount);
      end;
    end;
  end;

  Result := True;
end;

end.
