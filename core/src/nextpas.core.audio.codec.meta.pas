unit nextpas.core.audio.codec.meta;
{$I nextpas.core.settings.inc}
interface
uses nextpas.core.base, nextpas.core.io.intf, nextpas.core.audio.base;
function TryParseID3v2(const APrefix: TBytes; out ATags: TAudioTags; out ASkipped: Integer): Boolean;
function TryParseVorbisComment(const AData: TBytes; out ATags: TAudioTags): Boolean;
function TryParseRiffInfo(const AStream: IStream; ALimit: Int64; out ATags: TAudioTags): Boolean;
function MergeTags(const APrimary, AFallback: TAudioTags): TAudioTags;
implementation
function IsSpaceChar(C: Char): Boolean; inline;
begin Result := (C=' ') or (C=#9) or (C=#10) or (C=#13); end;
function TrimStr(const S: string): string;
var L,R: Integer;
begin L:=1; R:=Length(S); while (L<=R) and IsSpaceChar(S[L]) do Inc(L); while (R>=L) and IsSpaceChar(S[R]) do Dec(R);
  if L>R then Exit(''); Result:=Copy(S,L,R-L+1); end;
function UpperCaseStr(const S: string): string;
var I: Integer;
begin Result:=S; for I:=1 to Length(Result) do if (Result[I]>='a') and (Result[I]<='z') then Result[I]:=Chr(Ord(Result[I])-32); end;
function SameTextCI(const A,B: string): Boolean;
var I: Integer; CA,CB: Char;
begin if Length(A)<>Length(B) then Exit(False);
  for I:=1 to Length(A) do begin CA:=A[I]; CB:=B[I];
    if (CA>='a')and(CA<='z') then CA:=Chr(Ord(CA)-32);
    if (CB>='a')and(CB<='z') then CB:=Chr(Ord(CB)-32);
    if CA<>CB then Exit(False); end; Result:=True; end;
function TryParseIntStr(const S: string; out V: Integer): Boolean;
var I,Sign,N: Integer; C: Char; Has:Boolean;
begin V:=0; Result:=False; if S='' then Exit; I:=1; while (I<=Length(S)) and IsSpaceChar(S[I]) do Inc(I);
  if I>Length(S) then Exit; Sign:=1; if S[I]='-' then begin Sign:=-1; Inc(I); end else if S[I]='+' then Inc(I);
  N:=0; Has:=False; while I<=Length(S) do begin C:=S[I]; if (C<'0')or(C>'9') then Break;
    Has:=True; N:=N*10+Ord(C)-48; if N>1000000 then Break; Inc(I); end;
  if not Has then Exit; V:=N*Sign; Result:=True; end;
function ExtractTrackNo(const S: string): Integer;
var P: Integer; Part: string;
begin Result:=0; P:=Pos('/',S); if P>0 then Part:=Copy(S,1,P-1) else Part:=S;
  Part:=TrimStr(Part); if not TryParseIntStr(Part,Result) then Result:=0; if Result<0 then Result:=0; end;
function ExtractYear(const S: string): string;
var I: Integer;
begin Result:=''; if Length(S)<4 then Exit; for I:=1 to 4 do if (S[I]<'0')or(S[I]>'9') then Exit; Result:=Copy(S,1,4); end;
function IsValidUtf8Bytes(const B: TBytes; AOff,ALen: Integer): Boolean;
var I,Need: Integer; C: Byte;
begin Result:=True; I:=AOff; while I<AOff+ALen do begin C:=B[I];
    if C<$80 then Need:=0 else if (C and $E0)=$C0 then Need:=1 else if (C and $F0)=$E0 then Need:=2
    else if (C and $F8)=$F0 then Need:=3 else Exit(False);
    if Need=0 then Inc(I) else begin if I+Need>=AOff+ALen then Exit(False);
      while Need>0 do begin Inc(I); if (B[I] and $C0)<>$80 then Exit(False); Dec(Need); end; Inc(I); end; end; end;
function Latin1ToUtf8(const B: TBytes; AOff,ALen: Integer): string;
var I,OutLen: Integer; C: Byte; Res: string;
begin if ALen<=0 then Exit(''); SetLength(Res,ALen*2); OutLen:=0;
  for I:=0 to ALen-1 do begin C:=B[AOff+I];
    if C<$80 then begin Inc(OutLen); Res[OutLen]:=Chr(C); end
    else begin Inc(OutLen); Res[OutLen]:=Chr($C0 or (C shr 6)); Inc(OutLen); Res[OutLen]:=Chr($80 or (C and $3F)); end; end;
  SetLength(Res,OutLen); Result:=Res; end;
function Utf16ToUtf8(const B: TBytes; AOff,ALen: Integer; AIsBE: Boolean): string;
var I: Integer; U,U2,CP: UInt32; Res: string; OutPos,Cap: Integer;
  procedure AppendUtf8(ACP: UInt32);
  begin if ACP<$80 then begin Inc(OutPos); Res[OutPos]:=Chr(ACP); end
    else if ACP<$800 then begin Inc(OutPos); Res[OutPos]:=Chr($C0 or (ACP shr 6)); Inc(OutPos); Res[OutPos]:=Chr($80 or (ACP and $3F)); end
    else if ACP<$10000 then begin Inc(OutPos); Res[OutPos]:=Chr($E0 or (ACP shr 12)); Inc(OutPos); Res[OutPos]:=Chr($80 or ((ACP shr 6) and $3F)); Inc(OutPos); Res[OutPos]:=Chr($80 or (ACP and $3F)); end
    else begin Inc(OutPos); Res[OutPos]:=Chr($F0 or (ACP shr 18)); Inc(OutPos); Res[OutPos]:=Chr($80 or ((ACP shr 12) and $3F)); Inc(OutPos); Res[OutPos]:=Chr($80 or ((ACP shr 6) and $3F)); Inc(OutPos); Res[OutPos]:=Chr($80 or (ACP and $3F)); end; end;
begin Result:=''; if ALen<=0 then Exit; if (ALen and 1)<>0 then Dec(ALen); if ALen<=0 then Exit;
  Cap:=ALen*2+4; SetLength(Res,Cap); OutPos:=0; I:=0;
  while I+1<ALen do begin
    if AIsBE then U:=(UInt32(B[AOff+I]) shl 8) or UInt32(B[AOff+I+1]) else U:=UInt32(B[AOff+I]) or (UInt32(B[AOff+I+1]) shl 8);
    Inc(I,2);
    if (U>=$D800) and (U<=$DBFF) then begin
      if I+1>=ALen then begin AppendUtf8($FFFD); Break; end;
      if AIsBE then U2:=(UInt32(B[AOff+I]) shl 8) or UInt32(B[AOff+I+1]) else U2:=UInt32(B[AOff+I]) or (UInt32(B[AOff+I+1]) shl 8);
      if (U2<$DC00) or (U2>$DFFF) then begin AppendUtf8($FFFD); Continue; end;
      Inc(I,2); CP:=$10000+((U-$D800) shl 10)+(U2-$DC00); AppendUtf8(CP);
    end else if (U>=$DC00) and (U<=$DFFF) then AppendUtf8($FFFD) else AppendUtf8(U); end;
  SetLength(Res,OutPos); Result:=Res; end;
function ReadBE32(const B: TBytes; AOff: Integer; out V: UInt32): Boolean;
begin Result:=False; if (AOff<0) or (AOff+4>Length(B)) then Exit;
  V:=(UInt32(B[AOff]) shl 24) or (UInt32(B[AOff+1]) shl 16) or (UInt32(B[AOff+2]) shl 8) or UInt32(B[AOff+3]); Result:=True; end;
function ReadLE32(const B: TBytes; AOff: Integer; out V: UInt32): Boolean;
begin Result:=False; if (AOff<0) or (AOff+4>Length(B)) then Exit;
  V:=UInt32(B[AOff]) or (UInt32(B[AOff+1]) shl 8) or (UInt32(B[AOff+2]) shl 16) or (UInt32(B[AOff+3]) shl 24); Result:=True; end;
function ReadSynchsafe(const B: TBytes; AOff: Integer; out V: UInt32): Boolean;
var B0,B1,B2,B3: Byte;
begin Result:=False; if (AOff<0) or (AOff+4>Length(B)) then Exit;
  B0:=B[AOff]; B1:=B[AOff+1]; B2:=B[AOff+2]; B3:=B[AOff+3];
  if (B0>$7F) or (B1>$7F) or (B2>$7F) or (B3>$7F) then Exit;
  V:=(UInt32(B0) shl 21) or (UInt32(B1) shl 14) or (UInt32(B2) shl 7) or UInt32(B3); Result:=True; end;
procedure AddExtra(var ATags: TAudioTags; const AKey,AValue: string);
var L: Integer;
begin if (AValue='') or (AKey='') then Exit; L:=Length(ATags.Extra); SetLength(ATags.Extra,L+1); ATags.Extra[L].Key:=AKey; ATags.Extra[L].Value:=AValue; end;
function ExtraExists(const ATags: TAudioTags; const AKey: string): Boolean;
var I: Integer;
begin for I:=0 to High(ATags.Extra) do if SameTextCI(ATags.Extra[I].Key,AKey) then Exit(True); Result:=False; end;
function DecodeTextPayload(const B: TBytes; AOff,ALen: Integer; out S: string): Boolean;
var Enc: Byte; RawOff,RawLen,P,TermPos: Integer; BOM0,BOM1: Byte; IsBE: Boolean;
begin Result:=True; S:=''; if ALen<=0 then Exit; Enc:=B[AOff]; RawOff:=AOff+1; RawLen:=ALen-1; if RawLen<0 then RawLen:=0; if RawLen=0 then Exit;
  case Enc of
    0: begin P:=-1; for TermPos:=0 to RawLen-1 do if B[RawOff+TermPos]=0 then begin P:=TermPos; Break; end;
         if P>=0 then RawLen:=P; S:=Latin1ToUtf8(B,RawOff,RawLen); end;
    1: begin IsBE:=False; if RawLen>=2 then begin BOM0:=B[RawOff]; BOM1:=B[RawOff+1];
         if (BOM0=$FF)and(BOM1=$FE) then begin IsBE:=False; Inc(RawOff,2); Dec(RawLen,2); end
         else if (BOM0=$FE)and(BOM1=$FF) then begin IsBE:=True; Inc(RawOff,2); Dec(RawLen,2); end; end;
         TermPos:=-1; if RawLen>=2 then begin P:=0; while P+1<RawLen do begin if (B[RawOff+P]=0)and(B[RawOff+P+1]=0) then begin TermPos:=P; Break; end; Inc(P,2); end; end;
         if TermPos>=0 then RawLen:=TermPos; if (RawLen and 1)<>0 then Dec(RawLen); S:=Utf16ToUtf8(B,RawOff,RawLen,IsBE); end;
    2: begin TermPos:=-1; if RawLen>=2 then begin P:=0; while P+1<RawLen do begin if (B[RawOff+P]=0)and(B[RawOff+P+1]=0) then begin TermPos:=P; Break; end; Inc(P,2); end; end;
         if TermPos>=0 then RawLen:=TermPos; if (RawLen and 1)<>0 then Dec(RawLen); S:=Utf16ToUtf8(B,RawOff,RawLen,True); end;
    3: begin P:=-1; for TermPos:=0 to RawLen-1 do if B[RawOff+TermPos]=0 then begin P:=TermPos; Break; end;
         if P>=0 then RawLen:=P; SetLength(S,RawLen); if RawLen>0 then Move(B[RawOff],S[1],RawLen); end;
  else S:=''; end; end;
function DecodeUSLTOrCOMM(const B: TBytes; AOff,ALen: Integer; out S: string): Boolean;
var Enc: Byte; RawOff,RawLen,P,DPos: Integer; IsBE: Boolean;
begin Result:=True; S:=''; if ALen<4 then Exit;
  Enc:=B[AOff]; RawOff:=AOff+1+3; RawLen:=ALen-1-3; if RawLen<0 then RawLen:=0; if RawLen=0 then Exit;
  case Enc of 0,3: begin DPos:=-1; for P:=0 to RawLen-1 do if B[RawOff+P]=0 then begin DPos:=P; Break; end;
      if DPos>=0 then begin RawOff:=RawOff+DPos+1; RawLen:=RawLen-DPos-1; end else Exit; end;
    1,2: begin DPos:=-1; P:=0; while P+1<RawLen do begin if (B[RawOff+P]=0)and(B[RawOff+P+1]=0) then begin DPos:=P; Break; end; Inc(P,2); end;
      if DPos>=0 then begin RawOff:=RawOff+DPos+2; RawLen:=RawLen-DPos-2; end else Exit; end; else Exit; end;
  if RawLen<=0 then Exit;
  case Enc of
    0: begin P:=-1; for DPos:=0 to RawLen-1 do if B[RawOff+DPos]=0 then begin P:=DPos; Break; end; if P>=0 then RawLen:=P; S:=Latin1ToUtf8(B,RawOff,RawLen); end;
    1: begin IsBE:=False; if RawLen>=2 then begin if (B[RawOff]=$FF)and(B[RawOff+1]=$FE) then begin IsBE:=False; Inc(RawOff,2); Dec(RawLen,2); end
         else if (B[RawOff]=$FE)and(B[RawOff+1]=$FF) then begin IsBE:=True; Inc(RawOff,2); Dec(RawLen,2); end; end;
         P:=-1; if RawLen>=2 then begin DPos:=0; while DPos+1<RawLen do begin if (B[RawOff+DPos]=0)and(B[RawOff+DPos+1]=0) then begin P:=DPos; Break; end; Inc(DPos,2); end; end;
         if P>=0 then RawLen:=P; if (RawLen and 1)<>0 then Dec(RawLen); S:=Utf16ToUtf8(B,RawOff,RawLen,IsBE); end;
    2: begin P:=-1; if RawLen>=2 then begin DPos:=0; while DPos+1<RawLen do begin if (B[RawOff+DPos]=0)and(B[RawOff+DPos+1]=0) then begin P:=DPos; Break; end; Inc(DPos,2); end; end;
         if P>=0 then RawLen:=P; if (RawLen and 1)<>0 then Dec(RawLen); S:=Utf16ToUtf8(B,RawOff,RawLen,True); end;
    3: begin P:=-1; for DPos:=0 to RawLen-1 do if B[RawOff+DPos]=0 then begin P:=DPos; Break; end; if P>=0 then RawLen:=P;
         SetLength(S,RawLen); if RawLen>0 then Move(B[RawOff],S[1],RawLen); end; end; end;
function TryParseID3v2(const APrefix: TBytes; out ATags: TAudioTags; out ASkipped: Integer): Boolean;
var Ver,Flags: Byte; TagSize: UInt32; EndPos,Pos,FrameSize: Integer; ID: string; DataOff,DataLen: Integer; Text: string; Tmp,ExtSize: UInt32;
begin Result:=False; ATags:=Default(TAudioTags); ASkipped:=0; try
    if Length(APrefix)<10 then Exit;
    if (APrefix[0]<>Ord('I'))or(APrefix[1]<>Ord('D'))or(APrefix[2]<>Ord('3')) then Exit;
    Ver:=APrefix[3]; if not (Ver in [3,4]) then Exit; Flags:=APrefix[5];
    if not ReadSynchsafe(APrefix,6,TagSize) then Exit; ASkipped:=10+Integer(TagSize);
    if ASkipped<10 then Exit; if Length(APrefix)<ASkipped then Exit; EndPos:=ASkipped; Pos:=10;
    if (Flags and $40)<>0 then begin if Ver=4 then begin if Pos+4>EndPos then Exit;
        if not ReadSynchsafe(APrefix,Pos,ExtSize) then Exit; if ExtSize<4 then Exit;
        if Pos+Integer(ExtSize)>EndPos then Exit; Pos:=Pos+Integer(ExtSize); end
      else begin if Pos+4>EndPos then Exit; if not ReadBE32(APrefix,Pos,ExtSize) then Exit;
        if Pos+4+Integer(ExtSize)>EndPos then Exit; Pos:=Pos+4+Integer(ExtSize); end; end;
    while Pos+10<=EndPos do begin
      if APrefix[Pos]=0 then Break; SetLength(ID,4); ID[1]:=Chr(APrefix[Pos]); ID[2]:=Chr(APrefix[Pos+1]); ID[3]:=Chr(APrefix[Pos+2]); ID[4]:=Chr(APrefix[Pos+3]);
      if Ver=3 then begin if not ReadBE32(APrefix,Pos+4,Tmp) then Exit; FrameSize:=Integer(Tmp); end
      else begin if not ReadSynchsafe(APrefix,Pos+4,Tmp) then Exit; FrameSize:=Integer(Tmp); end;
      if FrameSize<0 then Exit; if Pos+10+FrameSize>EndPos then Exit;
      DataOff:=Pos+10; DataLen:=FrameSize; Text:='';
      if (Length(ID)=4) and (ID[1]='T') then begin
        DecodeTextPayload(APrefix,DataOff,DataLen,Text); Text:=TrimStr(Text);
        if ID='TIT2' then begin if ATags.Title='' then ATags.Title:=Text; end
        else if ID='TPE1' then begin if ATags.Artist='' then ATags.Artist:=Text; end
        else if ID='TPE2' then AddExtra(ATags,'AlbumArtist',Text)
        else if ID='TALB' then begin if ATags.Album='' then ATags.Album:=Text; end
        else if ID='TCON' then AddExtra(ATags,'Genre',Text)
        else if ID='TCOM' then AddExtra(ATags,'Composer',Text)
        else if ID='TPUB' then AddExtra(ATags,'Publisher',Text)
        else if ID='TRCK' then ATags.TrackNo:=ExtractTrackNo(Text)
        else if ID='TPOS' then AddExtra(ATags,'DiscNumber',Text)
        else if ID='TYER' then begin if ATags.Date='' then ATags.Date:=ExtractYear(Text); end
        else if ID='TDRC' then begin if ATags.Date='' then ATags.Date:=ExtractYear(Text); end
        else if ID='TLEN' then AddExtra(ATags,'Length',Text)
        else if ID='TBPM' then AddExtra(ATags,'BPM',Text)
        else if ID='TSRC' then AddExtra(ATags,'ISRC',Text)
        else if ID='TSOT' then AddExtra(ATags,'TitleSort',Text)
        else if ID='TSOP' then AddExtra(ATags,'ArtistSort',Text)
        else if ID='TSOA' then AddExtra(ATags,'AlbumSort',Text);
      end else if ID='USLT' then begin if DecodeUSLTOrCOMM(APrefix,DataOff,DataLen,Text) then begin Text:=TrimStr(Text); if Text<>'' then AddExtra(ATags,'Lyrics',Text); end;
      end else if ID='COMM' then begin if DecodeUSLTOrCOMM(APrefix,DataOff,DataLen,Text) then begin Text:=TrimStr(Text); if Text<>'' then AddExtra(ATags,'Comment',Text); end; end;
      Pos:=Pos+10+FrameSize; end; Result:=True; except Result:=False; end; end;
function TryParseVorbisComment(const AData: TBytes; out ATags: TAudioTags): Boolean;
var Pos: Integer; VLen,Count,Len: UInt32; Key,Val,UKey,S: string; Eq,I: Integer;
begin Result:=False; ATags:=Default(TAudioTags); try
    Pos:=0; if Length(AData)<4 then Exit; if not ReadLE32(AData,Pos,VLen) then Exit; Pos+=4;
    if Pos+Integer(VLen)>Length(AData) then Exit; Pos+=Integer(VLen);
    if Pos+4>Length(AData) then Exit; if not ReadLE32(AData,Pos,Count) then Exit; Pos+=4;
    for I:=0 to Integer(Count)-1 do begin if Pos+4>Length(AData) then Exit;
      if not ReadLE32(AData,Pos,Len) then Exit; Pos+=4; if Pos+Integer(Len)>Length(AData) then Exit;
      SetLength(S,Len); if Len>0 then Move(AData[Pos],S[1],Len); Pos+=Integer(Len);
      Eq:=0; for Eq:=1 to Length(S) do if S[Eq]='=' then Break;
      if (Eq<1) or (Eq>Length(S)) or (S[Eq]<>'=') then Continue;
      Key:=Copy(S,1,Eq-1); Val:=Copy(S,Eq+1,Length(S)-Eq); UKey:=UpperCaseStr(TrimStr(Key)); Val:=TrimStr(Val);
      if UKey='TITLE' then begin if ATags.Title='' then ATags.Title:=Val; end
      else if UKey='ARTIST' then begin if ATags.Artist='' then ATags.Artist:=Val; end
      else if UKey='ALBUM' then begin if ATags.Album='' then ATags.Album:=Val; end
      else if UKey='DATE' then begin if ATags.Date='' then ATags.Date:=Val; end
      else if UKey='TRACKNUMBER' then ATags.TrackNo:=ExtractTrackNo(Val)
      else if UKey='GENRE' then AddExtra(ATags,'Genre',Val) else AddExtra(ATags,UKey,Val); end;
    Result:=True; except Result:=False; end; end;
function StreamRead(const AStream: IStream; var B: Byte; Cnt: Integer): Boolean;
var Got: SizeUInt;
begin Result:=False; if Cnt<=0 then Exit(True); if AStream=nil then Exit; Got:=AStream.Read(B,SizeUInt(Cnt)); Result:=Got=SizeUInt(Cnt); end;
function TryParseRiffInfo(const AStream: IStream; ALimit: Int64; out ATags: TAudioTags): Boolean;
var Header,IDBytes,SizeBytes: array[0..3] of Byte; ChunkSize: UInt32; Data: TBytes; S,Key: string; I: Integer; NeedPad: Boolean;
begin Result:=False; ATags:=Default(TAudioTags); try
    if AStream=nil then Exit; if ALimit<0 then Exit;
    if AStream.Position+4>ALimit then Exit; if AStream.Position+4>AStream.Size then Exit;
    if not StreamRead(AStream,Header[0],4) then Exit;
    if not ((Header[0]=Ord('I'))and(Header[1]=Ord('N'))and(Header[2]=Ord('F'))and(Header[3]=Ord('O'))) then Exit;
    while True do begin
      if AStream.Position+8>ALimit then Break; if AStream.Position+8>AStream.Size then Break;
      if not StreamRead(AStream,IDBytes[0],4) then Exit; if not StreamRead(AStream,SizeBytes[0],4) then Exit;
      ChunkSize:=UInt32(SizeBytes[0]) or (UInt32(SizeBytes[1]) shl 8) or (UInt32(SizeBytes[2]) shl 16) or (UInt32(SizeBytes[3]) shl 24);
      if AStream.Position+Int64(ChunkSize)>ALimit then Exit; if AStream.Position+Int64(ChunkSize)>AStream.Size then Exit;
      SetLength(Data,ChunkSize); if ChunkSize>0 then if AStream.Read(Data[0],SizeUInt(ChunkSize))<>SizeUInt(ChunkSize) then Exit;
      I:=Length(Data); while (I>0) and (Data[I-1]=0) do Dec(I); SetLength(Data,I);
      if IsValidUtf8Bytes(Data,0,Length(Data)) then begin SetLength(S,Length(Data)); if Length(Data)>0 then Move(Data[0],S[1],Length(Data)); end
      else S:=Latin1ToUtf8(Data,0,Length(Data)); S:=TrimStr(S);
      Key:=Chr(IDBytes[0])+Chr(IDBytes[1])+Chr(IDBytes[2])+Chr(IDBytes[3]);
      if Key='INAM' then begin if ATags.Title='' then ATags.Title:=S; end
      else if Key='IART' then begin if ATags.Artist='' then ATags.Artist:=S; end
      else if Key='IPRD' then begin if ATags.Album='' then ATags.Album:=S; end
      else if Key='ICRD' then begin if ATags.Date='' then ATags.Date:=ExtractYear(S); if ATags.Date='' then ATags.Date:=S; end
      else if Key='ITRK' then ATags.TrackNo:=ExtractTrackNo(S) else if S<>'' then AddExtra(ATags,Key,S);
      NeedPad:=(ChunkSize and 1)<>0;
      if NeedPad then begin if AStream.Position+1>ALimit then Break; if AStream.Position+1>AStream.Size then Break;
        AStream.Position:=AStream.Position+1; end; end; Result:=True; except Result:=False; end; end;
function MergeTags(const APrimary,AFallback: TAudioTags): TAudioTags;
var I: Integer;
begin Result:=APrimary;
  if Result.Title='' then Result.Title:=AFallback.Title;
  if Result.Artist='' then Result.Artist:=AFallback.Artist;
  if Result.Album='' then Result.Album:=AFallback.Album;
  if Result.Date='' then Result.Date:=AFallback.Date;
  if Result.TrackNo=0 then Result.TrackNo:=AFallback.TrackNo;
  for I:=0 to High(AFallback.Extra) do if not ExtraExists(Result,AFallback.Extra[I].Key) then AddExtra(Result,AFallback.Extra[I].Key,AFallback.Extra[I].Value); end;
end.
