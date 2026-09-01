unit nextpas.core.audio.spatial.base;

{$I nextpas.core.settings.inc}

interface

type
  TAudioDistanceModel = (dmInverse, dmLinear, dmExponent);

const
  CAudioSpatialDefaultMinDistance = 1.0;
  CAudioSpatialDefaultMaxDistance = 100.0;
  CAudioSpatialDefaultRolloff = 1.0;
  CAudioSpatialDefaultDoppler = 1.0;
  CAudioSpatialDefaultGain = 1.0;

implementation

end.
