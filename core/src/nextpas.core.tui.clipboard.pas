unit nextpas.core.tui.clipboard;

// OS clipboard access for TUI applications.
//
// Supports three methods:
//   cmOSC52    — terminal escape sequence (works over SSH)
//   cmExternal — pipe to xclip/xsel/pbcopy/wl-copy
//   cmNone     — no clipboard available
//
// Detect() probes the environment and picks the best available method.

{$I nextpas.core.settings.inc}


interface

type
  TClipboardMethod = (cmOSC52, cmExternal, cmNone);

  TClipboard = record
    Method: TClipboardMethod;
    ExternalTool: AnsiString;

    class function Detect: TClipboard; static;
    function Copy(const Text: AnsiString): Boolean;
    function Paste: AnsiString;
    function GetOSC52Copy(const Text: AnsiString): AnsiString;
  end;

implementation

uses
  SysUtils{$IFDEF UNIX}, BaseUnix, Unix{$ENDIF};

// ---------- Base64 encoder (self-contained) ----------

const
  Base64Chars: array[0..63] of Char =
    'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';

function Base64Encode(const Input: AnsiString): AnsiString;
var
  Len, I, O: Integer;
  B0, B1, B2: Byte;
begin
  Len := Length(Input);
  if Len = 0 then begin Result := ''; Exit; end;
  SetLength(Result, ((Len + 2) div 3) * 4);
  O := 1;
  I := 1;
  while I <= Len - 2 do
  begin
    B0 := Ord(Input[I]);
    B1 := Ord(Input[I + 1]);
    B2 := Ord(Input[I + 2]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[((B0 and $03) shl 4) or (B1 shr 4)];
    Result[O + 2] := Base64Chars[((B1 and $0F) shl 2) or (B2 shr 6)];
    Result[O + 3] := Base64Chars[B2 and $3F];
    Inc(I, 3);
    Inc(O, 4);
  end;
  // Handle remaining 1 or 2 bytes
  if I = Len then
  begin
    B0 := Ord(Input[I]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[(B0 and $03) shl 4];
    Result[O + 2] := '=';
    Result[O + 3] := '=';
  end
  else if I = Len - 1 then
  begin
    B0 := Ord(Input[I]);
    B1 := Ord(Input[I + 1]);
    Result[O]     := Base64Chars[B0 shr 2];
    Result[O + 1] := Base64Chars[((B0 and $03) shl 4) or (B1 shr 4)];
    Result[O + 2] := Base64Chars[(B1 and $0F) shl 2];
    Result[O + 3] := '=';
  end;
end;

// ---------- Helpers ----------

function ToolExists(const Name: AnsiString): Boolean;
{$IFDEF UNIX}
var
  Ret: Integer;
begin
  Ret := fpSystem('command -v ' + Name + ' >/dev/null 2>&1');
  Result := (Ret = 0);
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function IsOSC52Terminal: Boolean;
var
  TermProg, Term: AnsiString;
begin
  TermProg := GetEnvironmentVariable('TERM_PROGRAM');
  Term := GetEnvironmentVariable('TERM');
  // Known OSC 52 supporters
  if (TermProg = 'iTerm.app') or (TermProg = 'iTerm2') or
     (TermProg = 'kitty') or (TermProg = 'alacritty') or
     (TermProg = 'WezTerm') then
  begin
    Result := True;
    Exit;
  end;
  // tmux and screen pass through OSC 52
  if (Pos('tmux', Term) > 0) or (Pos('screen', Term) > 0) then
  begin
    Result := True;
    Exit;
  end;
  Result := False;
end;

function FindExternalTool: AnsiString;
begin
  // Check Wayland first
  if GetEnvironmentVariable('WAYLAND_DISPLAY') <> '' then
  begin
    if ToolExists('wl-copy') then begin Result := 'wl-copy'; Exit; end;
  end;
  // X11
  if GetEnvironmentVariable('DISPLAY') <> '' then
  begin
    if ToolExists('xclip') then begin Result := 'xclip'; Exit; end;
    if ToolExists('xsel') then begin Result := 'xsel'; Exit; end;
  end;
  // macOS
  if ToolExists('pbcopy') then begin Result := 'pbcopy'; Exit; end;
  Result := '';
end;

function PasteCommand(const Tool: AnsiString): AnsiString;
begin
  if Tool = 'xclip' then
    Result := 'xclip -selection clipboard -o'
  else if Tool = 'xsel' then
    Result := 'xsel --clipboard --output'
  else if Tool = 'pbcopy' then
    Result := 'pbpaste'
  else if Tool = 'wl-copy' then
    Result := 'wl-paste'
  else
    Result := '';
end;

function CopyCommand(const Tool: AnsiString): AnsiString;
begin
  if Tool = 'xclip' then
    Result := 'xclip -selection clipboard'
  else if Tool = 'xsel' then
    Result := 'xsel --clipboard --input'
  else if Tool = 'pbcopy' then
    Result := 'pbcopy'
  else if Tool = 'wl-copy' then
    Result := 'wl-copy'
  else
    Result := '';
end;

// ---------- TClipboard ----------

class function TClipboard.Detect: TClipboard;
var
  Tool: AnsiString;
begin
  Result.Method := cmNone;
  Result.ExternalTool := '';

  if IsOSC52Terminal then
  begin
    Result.Method := cmOSC52;
    Exit;
  end;

  Tool := FindExternalTool;
  if Tool <> '' then
  begin
    Result.Method := cmExternal;
    Result.ExternalTool := Tool;
    Exit;
  end;
end;

function TClipboard.GetOSC52Copy(const Text: AnsiString): AnsiString;
var
  Encoded: AnsiString;
begin
  Encoded := Base64Encode(Text);
  // ESC ] 52 ; c ; <base64> ESC backslash
  Result := #27']52;c;' + Encoded + #27'\';
end;

function TClipboard.Copy(const Text: AnsiString): Boolean;
{$IFDEF UNIX}
var
  Seq, Cmd: AnsiString;
  F: System.Text;
  Written: cint;
begin
  Result := False;
  case Method of
    cmOSC52:
    begin
      Seq := GetOSC52Copy(Text);
      Written := fpWrite(1, @Seq[1], Length(Seq));
      Result := (Written = Length(Seq));
    end;
    cmExternal:
    begin
      Cmd := CopyCommand(ExternalTool);
      if Cmd = '' then Exit;
      if POpen(F, Cmd, 'W') <> 0 then Exit;
      System.Write(F, Text);
      Result := (PClose(F) = 0);
    end;
    cmNone:
      Result := False;
  end;
end;
{$ELSE}
begin
  Result := False;
end;
{$ENDIF}

function TClipboard.Paste: AnsiString;
{$IFDEF UNIX}
var
  Cmd: AnsiString;
  F: System.Text;
  Line: AnsiString;
  First: Boolean;
begin
  Result := '';
  case Method of
    cmOSC52:
      Result := '';
    cmExternal:
    begin
      Cmd := PasteCommand(ExternalTool);
      if Cmd = '' then Exit;
      if POpen(F, Cmd, 'R') <> 0 then Exit;
      First := True;
      while not Eof(F) do
      begin
        ReadLn(F, Line);
        if First then
          First := False
        else
          Result := Result + LineEnding;
        Result := Result + Line;
      end;
      PClose(F);
    end;
    cmNone:
      Result := '';
  end;
end;
{$ELSE}
begin
  Result := '';
end;
{$ENDIF}

end.
