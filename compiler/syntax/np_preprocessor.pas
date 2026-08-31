unit np_preprocessor;

{$mode objfpc}{$H+}

interface

uses
  nextpas.compiler.syntax.preprocessor;

type
  TIncludePathVec = nextpas.compiler.syntax.preprocessor.TIncludePathVec;
  TFileIncludeResolver = nextpas.compiler.syntax.preprocessor.TFileIncludeResolver;
  TDefineEntry = nextpas.compiler.syntax.preprocessor.TDefineEntry;
  TDefineEntryVec = nextpas.compiler.syntax.preprocessor.TDefineEntryVec;
  TDefineTable = nextpas.compiler.syntax.preprocessor.TDefineTable;
  TConditionalFrame = nextpas.compiler.syntax.preprocessor.TConditionalFrame;
  TConditionalFrameVec = nextpas.compiler.syntax.preprocessor.TConditionalFrameVec;
  TTokenVec = nextpas.compiler.syntax.preprocessor.TTokenVec;
  TPreprocessor = nextpas.compiler.syntax.preprocessor.TPreprocessor;

implementation

end.
