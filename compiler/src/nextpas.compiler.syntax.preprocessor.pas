unit nextpas.compiler.syntax.preprocessor;

{$mode objfpc}{$H+}

interface

uses
<<<<<<<< HEAD:compiler/syntax/np_preprocessor.pas
  nextpas.compiler.syntax.preprocessor;
========
  nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  np_base_types, nextpas.compiler.syntax.lexer;
>>>>>>>> codex/compiler-system:compiler/src/nextpas.compiler.syntax.preprocessor.pas

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
