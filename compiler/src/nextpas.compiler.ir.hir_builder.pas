unit nextpas.compiler.ir.hir_builder;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.ir.hir.builder;

type
  TExprStack = nextpas.compiler.ir.hir.builder.TExprStack;
  TAllocaEntry = nextpas.compiler.ir.hir.builder.TAllocaEntry;
  THIRExprResult = nextpas.compiler.ir.hir.builder.THIRExprResult;
  TTypedHirNodeVec = nextpas.compiler.ir.hir.builder.TTypedHirNodeVec;
  THirNameVec = nextpas.compiler.ir.hir.builder.THirNameVec;
  THirBlockNameVec = nextpas.compiler.ir.hir.builder.THirBlockNameVec;
  THirBlockIdVec = nextpas.compiler.ir.hir.builder.THirBlockIdVec;
  THirAllocaVec = nextpas.compiler.ir.hir.builder.THirAllocaVec;
  THirTypeIdVec = nextpas.compiler.ir.hir.builder.THirTypeIdVec;
  THirValueIdVec = nextpas.compiler.ir.hir.builder.THirValueIdVec;
  THIRBuilder = nextpas.compiler.ir.hir.builder.THIRBuilder;

implementation

end.
