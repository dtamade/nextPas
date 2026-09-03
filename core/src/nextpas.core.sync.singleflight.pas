unit nextpas.core.sync.singleflight;

{$I nextpas.core.settings.inc}

interface

uses
  nextpas.core.sync.mutex;

type
  TShardedSingleFlight = class
  private
    const
      SHARD_COUNT = 64;
    var
      FFlight: array[0..63] of TMutex;
    function StripeOf(const AKey: string): Integer; inline;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Acquire(const AKey: string);
    procedure Release(const AKey: string);
  end;

implementation

function TShardedSingleFlight.StripeOf(const AKey: string): Integer;
var
  I, H: Integer;
begin
  H := 0;
  for I := 1 to Length(AKey) do
    H := (H * 31 + Ord(AKey[I])) and $7FFFFFFF;
  Result := H mod SHARD_COUNT;
end;

constructor TShardedSingleFlight.Create;
var
  I: Integer;
begin
  inherited Create;
  for I := 0 to High(FFlight) do
    FFlight[I] := nil;
  try
    for I := 0 to High(FFlight) do
      FFlight[I] := TMutex.Create;
  except
    for I := 0 to High(FFlight) do
      if Assigned(FFlight[I]) then
        FFlight[I].Free;
    raise;
  end;
end;

destructor TShardedSingleFlight.Destroy;
var
  I: Integer;
begin
  for I := 0 to High(FFlight) do
    FFlight[I].Free;
  inherited Destroy;
end;

procedure TShardedSingleFlight.Acquire(const AKey: string);
var
  Idx: Integer;
begin
  Idx := StripeOf(AKey);
  if Assigned(FFlight[Idx]) then
    FFlight[Idx].Acquire;
end;

procedure TShardedSingleFlight.Release(const AKey: string);
var
  Idx: Integer;
begin
  Idx := StripeOf(AKey);
  if Assigned(FFlight[Idx]) then
    FFlight[Idx].Release;
end;

end.
