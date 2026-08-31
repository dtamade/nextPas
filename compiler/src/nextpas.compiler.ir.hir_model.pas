unit nextpas.compiler.ir.hir_model;

{$mode objfpc}{$H+}

interface

uses
  np_hir_model;

type
  THIRValueId = np_hir_model.THIRValueId;
  THIRBlockId = np_hir_model.THIRBlockId;
  THIRFuncId = np_hir_model.THIRFuncId;
  THIRInstrKind = np_hir_model.THIRInstrKind;
  THIRTermKind = np_hir_model.THIRTermKind;
  THIROperand = np_hir_model.THIROperand;
  THIRPhiEntry = np_hir_model.THIRPhiEntry;
  THIRInstr = np_hir_model.THIRInstr;
  THIRSwitchCase = np_hir_model.THIRSwitchCase;
  THirSwitchCaseVec = np_hir_model.THirSwitchCaseVec;
  THIRTerminator = np_hir_model.THIRTerminator;
  THirInstrVec = np_hir_model.THirInstrVec;
  THirBlockIdVec = np_hir_model.THirBlockIdVec;
  THIRBlock = np_hir_model.THIRBlock;
  THIRParam = np_hir_model.THIRParam;
  THirParamVec = np_hir_model.THirParamVec;
  THirBlockVec = np_hir_model.THirBlockVec;
  THIRFunction = np_hir_model.THIRFunction;
  THirStringVec = np_hir_model.THirStringVec;
  THirLongIntVec = np_hir_model.THirLongIntVec;
  THIRVmtGlobal = np_hir_model.THIRVmtGlobal;
  THIRImtGlobal = np_hir_model.THIRImtGlobal;
  THIRGlobal = np_hir_model.THIRGlobal;
  THirFunctionVec = np_hir_model.THirFunctionVec;
  THirGlobalVec = np_hir_model.THirGlobalVec;
  THirVmtGlobalVec = np_hir_model.THirVmtGlobalVec;
  THirImtGlobalVec = np_hir_model.THirImtGlobalVec;
  THIRModule = np_hir_model.THIRModule;

implementation

end.
