unit nextpas.core.graph.dot;
{$I nextpas.core.settings.inc}
{$J-}
interface
uses nextpas.core.base, nextpas.core.text.builder, nextpas.core.bytes.ops, nextpas.core.encoding.base64;
type TGraphColorFunc = function(const AKind: string): string;
TGraphDotOptions = record NodeColorFn: TGraphColorFunc; EdgeColorFn: TGraphColorFunc; MaxNodes: Integer; Direction: string; GraphName: string; NodeAttrs: string; EdgeAttrs: string; class function Default: TGraphDotOptions; static; class function Create(const ANodeColorFn, AEdgeColorFn: TGraphColorFunc; AMaxNodes: Integer = 8000; const ADirection: string = 'LR'; const AGraphName: string = 'graph'): TGraphDotOptions; static; end;
TGraphNode = record NodeId: string; Kind: string; LabelStr: string; end;
TGraphEdge = record SourceId: string; TargetId: string; Kind: string; end;
TGraph = record Nodes: array of TGraphNode; Edges: array of TGraphEdge; end;
function EscapeDot(const S: string): string;
function EscapeXml(const S: string): string;
function QuoteId(const S: string): string; function BytesToBase64(const AData: TBytes): string;
function GraphToDot(const ANodes: array of TGraphNode; const AEdges: array of TGraphEdge; const AOpts: TGraphDotOptions): string; function GraphToDotFromGraph(const G: TGraph; const AOpts: TGraphDotOptions): string;
function GraphCriticalPath(const NodeIds: TStringArray; const Edges: array of TGraphEdge): TStringArray;
function GraphPathToSvg(const Path: TStringArray; AWidth: Integer = 1200): string; function GraphToSvg(const ANodes: array of TGraphNode; const AEdges: array of TGraphEdge; AWidth: Integer = 1200): string; function GraphToSvgFromGraph(const G: TGraph; AWidth: Integer = 1200): string;
implementation
const
  HEX_LOWER: array[0..15] of AnsiChar = '0123456789abcdef';
{ perf: TBufStringBuilder single SetLength+Move zero-copy; exponential Growth inside builder; no Result+ O(n²) churn }
function EscapeDot(const S: string): string;
var
  B: TBufStringBuilder;
  I: Integer;
  C: Char;
  LOrd: Cardinal;
begin
  if Length(S) = 0 then Exit('');
  { perf: init cap = Length(S) (grow handles 6x worst \uXXXX); single ToString zero-copy }
  B.Init(SizeUInt(Length(S)));
  try
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '"': B.AppendStr('\"');
        '\': B.AppendStr('\\');
        #10: B.AppendStr('\n');
        #13: B.AppendStr('\r');
      else
        if Ord(C) < 32 then
        begin
          LOrd := Ord(C);
          B.AppendChar('\');
          B.AppendChar('u');
          B.AppendChar(HEX_LOWER[(LOrd shr 12) and $F]);
          B.AppendChar(HEX_LOWER[(LOrd shr 8) and $F]);
          B.AppendChar(HEX_LOWER[(LOrd shr 4) and $F]);
          B.AppendChar(HEX_LOWER[LOrd and $F]);
        end
        else
          B.AppendChar(AnsiChar(C));
      end;
    end;
    Result := B.ToString;
  finally
    B.Done;
  end;
end;
{ perf: TBufStringBuilder single SetLength+Move zero-copy; no Result+ O(n²) churn }
function EscapeXml(const S: string): string;
var
  B: TBufStringBuilder;
  I: Integer;
  C: Char;
begin
  if Length(S) = 0 then Exit('');
  B.Init(SizeUInt(Length(S)));
  try
    for I := 1 to Length(S) do
    begin
      C := S[I];
      case C of
        '&': B.AppendStr('&amp;');
        '<': B.AppendStr('&lt;');
        '>': B.AppendStr('&gt;');
        '"': B.AppendStr('&quot;');
        '''': B.AppendStr('&apos;');
      else
        B.AppendChar(AnsiChar(C));
      end;
    end;
    Result := B.ToString;
  finally
    B.Done;
  end;
end;
function QuoteId(const S: string): string; begin Result := '"' + EscapeDot(S) + '"'; end;
function BytesToBase64(const AData: TBytes): string; begin Result := Base64Encode(AData); end;
class function TGraphDotOptions.Default: TGraphDotOptions; begin Result.NodeColorFn := nil; Result.EdgeColorFn := nil; Result.MaxNodes := 8000; Result.Direction := 'LR'; Result.GraphName := 'graph'; Result.NodeAttrs := 'shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10'; Result.EdgeAttrs := 'fontname="Helvetica", fontsize=9'; end;
class function TGraphDotOptions.Create(const ANodeColorFn, AEdgeColorFn: TGraphColorFunc; AMaxNodes: Integer; const ADirection: string; const AGraphName: string): TGraphDotOptions; begin Result.NodeColorFn := ANodeColorFn; Result.EdgeColorFn := AEdgeColorFn; Result.MaxNodes := AMaxNodes; Result.Direction := ADirection; Result.GraphName := AGraphName; if Result.GraphName = '' then Result.GraphName := 'graph'; if Result.Direction = '' then Result.Direction := 'LR'; Result.NodeAttrs := 'shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10'; Result.EdgeAttrs := 'fontname="Helvetica", fontsize=9'; end;
function DefaultNodeColor(const AKind: string): string; begin Result := '#cbd5e1'; end;
function DefaultEdgeColor(const AKind: string): string; begin Result := '#475569'; end;
function ResolveNodeColor(const AKind: string; const AOpts: TGraphDotOptions): string; begin if Assigned(AOpts.NodeColorFn) then Result := AOpts.NodeColorFn(AKind) else Result := DefaultNodeColor(AKind); end;
function ResolveEdgeColor(const AKind: string; const AOpts: TGraphDotOptions): string; begin if Assigned(AOpts.EdgeColorFn) then Result := AOpts.EdgeColorFn(AKind) else Result := DefaultEdgeColor(AKind); end;
function GraphToDot(const ANodes: array of TGraphNode; const AEdges: array of TGraphEdge; const AOpts: TGraphDotOptions): string; var B: TBufStringBuilder; I, Limit: Integer; N: TGraphNode; E: TGraphEdge; Fill, ECol, LabelStr, GraphName, Direction, NodeAttrs, EdgeAttrs: string; begin GraphName := AOpts.GraphName; if GraphName = '' then GraphName := 'graph'; Direction := AOpts.Direction; if Direction = '' then Direction := 'LR'; NodeAttrs := AOpts.NodeAttrs; if NodeAttrs = '' then NodeAttrs := 'shape=box, style="rounded,filled", fontname="Helvetica", fontsize=10'; EdgeAttrs := AOpts.EdgeAttrs; if EdgeAttrs = '' then EdgeAttrs := 'fontname="Helvetica", fontsize=9'; B.Init(4096); try B.AppendStr('digraph '); B.AppendStr(GraphName); B.AppendStr(' {'#10); B.AppendStr('  rankdir='); B.AppendStr(Direction); B.AppendStr(';'#10); B.AppendStr('  node ['); B.AppendStr(NodeAttrs); B.AppendStr('];'#10); B.AppendStr('  edge ['); B.AppendStr(EdgeAttrs); B.AppendStr('];'#10); Limit := Length(ANodes); if (AOpts.MaxNodes > 0) and (Limit > AOpts.MaxNodes) then Limit := AOpts.MaxNodes; for I := 0 to Limit - 1 do begin N := ANodes[I]; if N.LabelStr <> '' then LabelStr := N.LabelStr else if N.Kind <> '' then LabelStr := N.NodeId + '\n' + N.Kind else LabelStr := N.NodeId; Fill := ResolveNodeColor(N.Kind, AOpts); B.AppendStr('  '); B.AppendStr(QuoteId(N.NodeId)); B.AppendStr(' [label="'); B.AppendStr(EscapeDot(LabelStr)); B.AppendStr('" fillcolor="'); B.AppendStr(Fill); B.AppendStr('"'); if GraphName = 'banked_code' then B.AppendStr(' style=filled') else if N.Kind = 'decoded' then B.AppendStr(' fontcolor="#052e16"') else B.AppendStr(' fontcolor="#0f172a"'); B.AppendStr('];'#10); end; for I := 0 to Length(AEdges) - 1 do begin E := AEdges[I]; ECol := ResolveEdgeColor(E.Kind, AOpts); B.AppendStr('  '); B.AppendStr(QuoteId(E.SourceId)); B.AppendStr(' -> '); B.AppendStr(QuoteId(E.TargetId)); B.AppendStr(' [label="'); B.AppendStr(EscapeDot(E.Kind)); B.AppendStr('" color="'); B.AppendStr(ECol); B.AppendStr('"'); if GraphName <> 'banked_code' then begin B.AppendStr(' fontcolor="'); B.AppendStr(ECol); B.AppendStr('"'); end; B.AppendStr('];'#10); end; if Limit < Length(ANodes) then begin B.AppendStr('  // truncated '); B.AppendInt(Length(ANodes) - Limit); B.AppendStr(' nodes'#10); end; B.AppendStr('}'#10); Result := B.ToString; finally B.Done; end; end;
function GraphToDotFromGraph(const G: TGraph; const AOpts: TGraphDotOptions): string; begin Result := GraphToDot(G.Nodes, G.Edges, AOpts); end;
{ perf: adjacency exponential via BytesGrowCapacityInt amortized O(1); zero-copy via single Move per edge, stability via bounded cap }
function GraphCriticalPath(const NodeIds: TStringArray; const Edges: array of TGraphEdge): TStringArray;
var
  InDegree: array of Integer;
  Adj: array of TStringArray;
  AdjLen: array of Integer;
  AdjCap: array of Integer;
  I, K, Idx, TIdx: Integer;
  Order: TStringArray;
  Queue: TStringArray;
  QPos, QLen, QCap: Integer;
  OLen, OCap: Integer;
  Dist: array of Integer;
  Prev: array of string;
  Target: string;
  MaxIdx, MaxDist: Integer;
  Cur: string;
  Path: TStringArray;
  PLen, PCap: Integer;
  function FindIdx(const AId: string): Integer; inline;
  var J: Integer; begin for J := 0 to Length(NodeIds) - 1 do if NodeIds[J] = AId then Exit(J); Result := -1; end;
begin
  Result := nil;
  if Length(NodeIds) = 0 then Exit;
  SetLength(InDegree, Length(NodeIds));
  SetLength(Adj, Length(NodeIds));
  SetLength(AdjLen, Length(NodeIds));
  SetLength(AdjCap, Length(NodeIds));
  for I := 0 to High(AdjLen) do begin AdjLen[I] := 0; AdjCap[I] := 0; end;
  for I := 0 to Length(Edges) - 1 do
  begin
    Idx := FindIdx(Edges[I].SourceId);
    TIdx := FindIdx(Edges[I].TargetId);
    if (Idx < 0) or (TIdx < 0) then Continue;
    { perf: exponential grow via BytesGrowCapacityInt single source, amortized O(1) vs linear SetLength+1 O(n²) }
    if AdjLen[Idx] >= AdjCap[Idx] then
    begin
      AdjCap[Idx] := BytesGrowCapacityInt(AdjCap[Idx], AdjLen[Idx] + 1);
      SetLength(Adj[Idx], AdjCap[Idx]);
    end;
    Adj[Idx][AdjLen[Idx]] := Edges[I].TargetId;
    Inc(AdjLen[Idx]);
    Inc(InDegree[TIdx]);
  end;
  for I := 0 to High(Adj) do
    if Length(Adj[I]) <> AdjLen[I] then
      SetLength(Adj[I], AdjLen[I]);
  QLen := 0; QCap := 0; QPos := 0;
  SetLength(Queue, 0);
  for I := 0 to Length(NodeIds) - 1 do if InDegree[I] = 0 then
  begin
    if QLen >= QCap then
    begin
      QCap := BytesGrowCapacityInt(QCap, QLen + 1);
      SetLength(Queue, QCap);
    end;
    Queue[QLen] := NodeIds[I];
    Inc(QLen);
  end;
  if Length(Queue) <> QLen then SetLength(Queue, QLen);
  OLen := 0; OCap := BytesGrowCapacityInt(0, Length(NodeIds));
  SetLength(Order, OCap);
  while QPos < QLen do
  begin
    Cur := Queue[QPos]; Inc(QPos);
    if OLen >= OCap then
    begin
      OCap := BytesGrowCapacityInt(OCap, OLen + 1);
      SetLength(Order, OCap);
    end;
    Order[OLen] := Cur; Inc(OLen);
    Idx := FindIdx(Cur);
    if (Idx < 0) or (Idx > High(Adj)) then Continue;
    for K := 0 to Length(Adj[Idx]) - 1 do
    begin
      Target := Adj[Idx][K];
      TIdx := FindIdx(Target);
      if TIdx < 0 then Continue;
      Dec(InDegree[TIdx]);
      if InDegree[TIdx] = 0 then
      begin
        if QLen >= QCap then
        begin
          QCap := BytesGrowCapacityInt(QCap, QLen + 1);
          SetLength(Queue, QCap);
        end;
        Queue[QLen] := Target;
        Inc(QLen);
      end;
    end;
  end;
  if Length(Order) <> OLen then SetLength(Order, OLen);
  if Length(Queue) <> QLen then SetLength(Queue, QLen);
  SetLength(Dist, Length(NodeIds));
  SetLength(Prev, Length(NodeIds));
  for I := 0 to Length(Dist) - 1 do begin Dist[I] := 0; Prev[I] := ''; end;
  for I := 0 to Length(Order) - 1 do
  begin
    Idx := FindIdx(Order[I]);
    if (Idx < 0) or (Idx > High(Adj)) then Continue;
    for K := 0 to Length(Adj[Idx]) - 1 do
    begin
      Target := Adj[Idx][K];
      TIdx := FindIdx(Target);
      if TIdx < 0 then Continue;
      if Dist[TIdx] < Dist[Idx] + 1 then
      begin
        Dist[TIdx] := Dist[Idx] + 1;
        Prev[TIdx] := Order[I];
      end;
    end;
  end;
  MaxDist := -1; MaxIdx := 0;
  for I := 0 to Length(Dist) - 1 do if Dist[I] > MaxDist then begin MaxDist := Dist[I]; MaxIdx := I; end;
  Cur := NodeIds[MaxIdx];
  PLen := 0; PCap := 0;
  SetLength(Path, 0);
  while Cur <> '' do
  begin
    if PLen >= PCap then
    begin
      PCap := BytesGrowCapacityInt(PCap, PLen + 1);
      SetLength(Path, PCap);
    end;
    Path[PLen] := Cur; Inc(PLen);
    Idx := FindIdx(Cur);
    if (Idx < 0) or (Idx > High(Prev)) then Cur := '' else Cur := Prev[Idx];
  end;
  if Length(Path) <> PLen then SetLength(Path, PLen);
  SetLength(Result, PLen);
  for I := 0 to PLen - 1 do Result[I] := Path[PLen - 1 - I];
end;
function GraphPathToSvg(const Path: TStringArray; AWidth: Integer): string; var B: TBufStringBuilder; I, BoxW, BoxH, Gap, Pad, TotalW, H: Integer; X, W: Integer; begin if Length(Path) = 0 then begin Result := '<svg xmlns="http://www.w3.org/2000/svg" width="400" height="80"><text x="10" y="40" font-family="Helvetica" font-size="12" fill="#94a3b8">empty graph</text></svg>'; Exit; end; BoxW := 140; BoxH := 40; Gap := 36; Pad := 24; H := 100; W := Pad * 2 + Length(Path) * BoxW + (Length(Path) - 1) * Gap; if W < AWidth then W := AWidth; if W > 2400 then W := 2400; B.Init(2048); try B.AppendStr('<svg xmlns="http://www.w3.org/2000/svg" width="'); B.AppendInt(W); B.AppendStr('" height="'); B.AppendInt(H); B.AppendStr('" viewBox="0 0 '); B.AppendInt(W); B.AppendStr(' '); B.AppendInt(H); B.AppendStr('">'); B.AppendStr('<rect width="100%" height="100%" rx="12" fill="#0f172a"/>'); B.AppendStr('<defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="8" markerHeight="8" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#38bdf8"/></marker></defs>'); B.AppendStr('<text x="'); B.AppendInt(Pad); B.AppendStr('" y="18" font-family="Helvetica" font-size="11" fill="#94a3b8">critical path ('); B.AppendInt(Length(Path)); B.AppendStr(' nodes)</text>'); for I := 0 to Length(Path) - 1 do begin X := Pad + I * (BoxW + Gap); B.AppendStr('<rect x="'); B.AppendInt(X); B.AppendStr('" y="36" width="'); B.AppendInt(BoxW); B.AppendStr('" height="'); B.AppendInt(BoxH); B.AppendStr('" rx="10" fill="#1e293b" stroke="#38bdf8" stroke-width="1.5"/>'); B.AppendStr('<text x="'); B.AppendInt(X + BoxW div 2); B.AppendStr('" y="60" text-anchor="middle" font-family="Helvetica" font-size="11" fill="#e2e8f0">'); B.AppendStr(EscapeXml(Copy(Path[I], 1, 18))); if Length(Path[I]) > 18 then B.AppendStr('…'); B.AppendStr('</text>'); if I < Length(Path) - 1 then begin B.AppendStr('<line x1="'); B.AppendInt(X + BoxW); B.AppendStr('" y1="56" x2="'); B.AppendInt(X + BoxW + Gap); B.AppendStr('" y2="56" stroke="#38bdf8" stroke-width="1.5" marker-end="url(#arrow)"/>'); end; end; B.AppendStr('</svg>'); Result := B.ToString; finally B.Done; end; end;
function GraphToSvg(const ANodes: array of TGraphNode; const AEdges: array of TGraphEdge; AWidth: Integer): string; var Ids: TStringArray; I, LCount: Integer; Path: TStringArray; begin SetLength(Ids, Length(ANodes)); for I := 0 to Length(ANodes) - 1 do Ids[I] := ANodes[I].NodeId; Path := GraphCriticalPath(Ids, AEdges); if Length(Path) = 0 then begin LCount := Length(Ids); if LCount > 6 then LCount := 6; SetLength(Path, LCount); for I := 0 to LCount - 1 do Path[I] := Ids[I]; end; Result := GraphPathToSvg(Path, AWidth); end;
function GraphToSvgFromGraph(const G: TGraph; AWidth: Integer): string; begin Result := GraphToSvg(G.Nodes, G.Edges, AWidth); end;
end.
