unit nextpas.core.tui.image_cap;

{**
 * @desc 终端图像协议能力检测。
 *
 * 通过环境变量探测当前终端支持的图像协议：Kitty graphics protocol、
 * Sixel、或回退到半块字符（half-block）。供 buffer 的图像占位与
 * 后端图像渲染选择编码方式。
 *
 * @note 仅做检测，不做渲染。检测基于 TERM / TERM_PROGRAM /
 *       TERM_FEATURES / KITTY_WINDOW_ID 等环境变量启发式判断。
 *}

{$I nextpas.core.settings.inc}
{$packenum 1}

interface

type
  TImageProtocol = (ipAuto, ipKitty, ipSixel, ipHalfBlock);

{**
 * @desc 检测当前终端的图像协议能力。
 * @return ipKitty / ipSixel / ipHalfBlock（无法确定时回退 half-block）
 *}
function DetectImageProtocol: TImageProtocol;

implementation

uses
  SysUtils;

function DetectImageProtocol: TImageProtocol;
var
  LTerm, LTermProgram: AnsiString;
begin
  LTerm := GetEnvironmentVariable('TERM');
  LTermProgram := GetEnvironmentVariable('TERM_PROGRAM');

  { Kitty graphics protocol: kitty, WezTerm, Ghostty }
  if (Pos('kitty', LTerm) > 0) or (Pos('kitty', LTermProgram) > 0) or
     (GetEnvironmentVariable('KITTY_WINDOW_ID') <> '') or
     (Pos('WezTerm', LTermProgram) > 0) or (Pos('ghostty', LTermProgram) > 0) then
    Result := ipKitty

  { Sixel：显式 TERM_FEATURES，或已知支持 sixel 的终端。
    注意：不匹配泛化的 'xterm'——许多非 Sixel 终端
    (gnome-terminal, tilix) 也设 TERM=xterm-256color。 }
  else if (Pos('sixel', GetEnvironmentVariable('TERM_FEATURES')) > 0) or
          (Pos('foot', LTerm) > 0) or (Pos('foot', LTermProgram) > 0) or
          (Pos('mlterm', LTerm) > 0) or (Pos('mlterm', LTermProgram) > 0) or
          (Pos('contour', LTermProgram) > 0) or
          (Pos('yaft', LTerm) > 0) or
          (LTermProgram = 'xterm') then
    Result := ipSixel

  else
    Result := ipHalfBlock;
end;

end.
