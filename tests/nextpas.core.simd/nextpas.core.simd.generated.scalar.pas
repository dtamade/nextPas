{$MODE OBJFPC}{$H+}
{$I ../../src/nextpas.core.settings.inc}

unit nextpas.core.simd.generated.scalar;

interface

uses
  nextpas.core.simd.base,
  nextpas.core.simd.dispatch;

{$I ../../src/generated/nextpas.core.simd.scalar.decl.inc}

implementation

uses
  Math;

{$I ../../src/generated/nextpas.core.simd.scalar.impl.inc}

end.
