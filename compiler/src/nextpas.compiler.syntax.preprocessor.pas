unit nextpas.compiler.syntax.preprocessor;

{$mode objfpc}{$H+}

interface

uses
  np_preprocessor;

type
  TIncludePathVec = np_preprocessor.TIncludePathVec;
  TFileIncludeResolver = np_preprocessor.TFileIncludeResolver;
  TDefineEntry = np_preprocessor.TDefineEntry;
  TDefineEntryVec = np_preprocessor.TDefineEntryVec;
  TDefineTable = np_preprocessor.TDefineTable;
  TConditionalFrame = np_preprocessor.TConditionalFrame;
  TConditionalFrameVec = np_preprocessor.TConditionalFrameVec;
  TTokenVec = np_preprocessor.TTokenVec;
  TPreprocessor = np_preprocessor.TPreprocessor;

implementation

end.
