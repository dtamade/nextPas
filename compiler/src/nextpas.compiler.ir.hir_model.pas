unit nextpas.compiler.ir.hir_model;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.hir.model;

type
  THIRValueId = nextpas.compiler.ir.hir.model.THIRValueId;
  THIRBlockId = nextpas.compiler.ir.hir.model.THIRBlockId;
  THIRFuncId = nextpas.compiler.ir.hir.model.THIRFuncId;
  THIRInstrKind = nextpas.compiler.ir.hir.model.THIRInstrKind;
  THIRTermKind = nextpas.compiler.ir.hir.model.THIRTermKind;
  THIROperand = nextpas.compiler.ir.hir.model.THIROperand;
  THIRPhiEntry = nextpas.compiler.ir.hir.model.THIRPhiEntry;
  THIRInstr = nextpas.compiler.ir.hir.model.THIRInstr;
  THIRSwitchCase = nextpas.compiler.ir.hir.model.THIRSwitchCase;
  THirSwitchCaseVec = nextpas.compiler.ir.hir.model.THirSwitchCaseVec;
  THIRTerminator = nextpas.compiler.ir.hir.model.THIRTerminator;
  THirInstrVec = nextpas.compiler.ir.hir.model.THirInstrVec;
  THirBlockIdVec = nextpas.compiler.ir.hir.model.THirBlockIdVec;
  THIRBlock = nextpas.compiler.ir.hir.model.THIRBlock;
  THIRParam = nextpas.compiler.ir.hir.model.THIRParam;
  THirParamVec = nextpas.compiler.ir.hir.model.THirParamVec;
  THirBlockVec = nextpas.compiler.ir.hir.model.THirBlockVec;
  THIRFunction = nextpas.compiler.ir.hir.model.THIRFunction;
  THirStringVec = nextpas.compiler.ir.hir.model.THirStringVec;
  THirLongIntVec = nextpas.compiler.ir.hir.model.THirLongIntVec;
  THIRVmtGlobal = nextpas.compiler.ir.hir.model.THIRVmtGlobal;
  THIRImtGlobal = nextpas.compiler.ir.hir.model.THIRImtGlobal;
  THIRGlobal = nextpas.compiler.ir.hir.model.THIRGlobal;
  THirFunctionVec = nextpas.compiler.ir.hir.model.THirFunctionVec;
  THirGlobalVec = nextpas.compiler.ir.hir.model.THirGlobalVec;
  THirVmtGlobalVec = nextpas.compiler.ir.hir.model.THirVmtGlobalVec;
  THirImtGlobalVec = nextpas.compiler.ir.hir.model.THirImtGlobalVec;
  THIRModule = nextpas.compiler.ir.hir.model.THIRModule;

implementation

end.
