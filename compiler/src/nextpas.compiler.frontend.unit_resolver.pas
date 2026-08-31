unit nextpas.compiler.frontend.unit_resolver;

{$mode objfpc}{$H+}

interface

uses
<<<<<<<< HEAD:compiler/frontend/np_unit_resolver.pas
  nextpas.compiler.frontend.unit_resolver;
========
  { SameText via text.conv — do not pull nextpas.core.text unicode facade. }
  nextpas.core.text.conv, nextpas.core.path,
  nextpas.core.fs.util, nextpas.core.fs.dir, nextpas.core.fs.base,
  nextpas.core.time, nextpas.core.mem.intf,
  nextpas.core.collections.vec,
  nextpas.compiler.syntax.ast_facade, nextpas.compiler.diagnostics.sink, nextpas.compiler.syntax.green_tree, nextpas.compiler.syntax.lexer,
  nextpas.compiler.frontend.package_manifest, nextpas.compiler.syntax.preprocessor, nextpas.compiler.frontend.source_database,
  nextpas.compiler.targets.facts, np_text_primitives, nextpas.compiler.toolchain.profiles, nextpas.compiler.frontend.unit_graph;
>>>>>>>> codex/compiler-system:compiler/src/nextpas.compiler.frontend.unit_resolver.pas

type
  TUnitResolverStringVec = nextpas.compiler.frontend.unit_resolver.TUnitResolverStringVec;
  TProjectUnitRootInfoVec = nextpas.compiler.frontend.unit_resolver.TProjectUnitRootInfoVec;
  TSearchIndexEntry = nextpas.compiler.frontend.unit_resolver.TSearchIndexEntry;
  TSearchIndexEntryVec = nextpas.compiler.frontend.unit_resolver.TSearchIndexEntryVec;
  TResolutionStackEntry = nextpas.compiler.frontend.unit_resolver.TResolutionStackEntry;
  TResolutionStackVec = nextpas.compiler.frontend.unit_resolver.TResolutionStackVec;
  TRootSearchIndex = nextpas.compiler.frontend.unit_resolver.TRootSearchIndex;
  TRootSearchIndexVec = nextpas.compiler.frontend.unit_resolver.TRootSearchIndexVec;
  TUnitResolver = nextpas.compiler.frontend.unit_resolver.TUnitResolver;

implementation

end.