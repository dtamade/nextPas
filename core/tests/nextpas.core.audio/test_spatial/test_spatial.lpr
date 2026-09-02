program test_spatial;

{$mode objfpc}{$H+}

uses
  nextpas.core.test,
  nextpas.core.audio.base,
  nextpas.core.audio.spatial;

type T = class
  procedure TestVector;
  procedure TestPan;
  procedure TestGain;
  procedure TestApply;
  procedure TestGainClamp;
  procedure TestPanClamp;
end;

procedure T.TestVector;
var V: TAudioVector3;
begin
  V:=TAudioVector3.Create(1,2,3);
  CheckEqual(1, Integer(Round(V.X)), 'x');
end;

procedure T.TestPan;
begin
  CheckNear(-1, SpatialPanFromPosition(TAudioVector3.Create(-2,0,0)), 1e-6, 'left');
  CheckNear(1, SpatialPanFromPosition(TAudioVector3.Create(2,0,0)), 1e-6, 'right');
  CheckNear(0, SpatialPanFromPosition(TAudioVector3.Create(0,0,0)), 1e-6, 'center');
end;

procedure T.TestGain;
begin
  CheckNear(1, SpatialGainFromDistance(0,1,10,1), 1e-6, 'near');
  CheckNear(0, SpatialGainFromDistance(10,1,10,1), 1e-6, 'far');
  CheckTrue(SpatialGainFromDistance(5,1,10,1) < 1, 'mid');
end;

procedure T.TestApply;
var Buf,OutBuf: TAudioBuffer; P: TSpatialParams; I: Integer;
begin
  Buf.Format:=AudioFormatCreate(48000,2,sfF32); Buf.FrameCount:=4; SetLength(Buf.Data,4*Buf.Format.BlockAlign);
  for I:=0 to 7 do PSingle(@Buf.Data[I*4])^:=0.5;
  P.Position:=TAudioVector3.Create(0,0,0); P.Distance:=0; P.MinDistance:=1; P.MaxDistance:=10; P.Rolloff:=1; P.Doppler:=0;
  OutBuf:=SpatialApply(Buf,P);
  CheckEqual(4, OutBuf.FrameCount, 'frames');
  CheckTrue(Length(OutBuf.Data)>0, 'data');
end;

procedure T.TestGainClamp;
begin
  CheckTrue(SpatialGainFromDistance(100,1,10,1)=0, 'clamp 0');
end;

procedure T.TestPanClamp;
begin
  CheckTrue(SpatialPanFromPosition(TAudioVector3.Create(10,0,0))=1, 'clamp 1');
end;

var Suite: TTestSuite; C: T;
begin
  C:=T.Create; Suite:=TTestSuite.Create('audio.spatial');
  Suite.Test('vector', @C.TestVector);
  Suite.Test('pan', @C.TestPan);
  Suite.Test('gain', @C.TestGain);
  Suite.Test('apply', @C.TestApply);
  Suite.Test('gain clamp', @C.TestGainClamp);
  Suite.Test('pan clamp', @C.TestPanClamp);
  C.Free;
  if not Suite.Run then Halt(1);
end.
