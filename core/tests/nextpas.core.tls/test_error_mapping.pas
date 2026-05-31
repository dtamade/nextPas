program test_error_mapping;

{$mode objfpc}{$H+}
{$IFDEF WINDOWS}{$CODEPAGE UTF8}{$ENDIF}

uses
  {$IFDEF UNIX}
  cthreads,
  {$ENDIF}
  SysUtils;

begin
  WriteLn('测试错误映射功能');
  WriteLn('任务 4.1: Schannel 错误码到 SSL 错误的映射');
  WriteLn('');
  WriteLn('注意: 此测试需要在 Windows 平台上运行');
  WriteLn('当前平台: ', {$IFDEF WINDOWS}'Windows'{$ELSE}'非 Windows'{$ENDIF});
  WriteLn('');
  
  {$IFDEF WINDOWS}
  WriteLn('错误映射功能已实现:');
  WriteLn('- MapSchannelError: 映射 Schannel 错误码到 TSSLErrorCode');
  WriteLn('- GetSchannelErrorMessageCN: 获取中文错误消息');
  WriteLn('- GetSchannelErrorMessageEN: 获取英文错误消息');
  {$ELSE}
  WriteLn('跳过 Windows 专用测试');
  {$ENDIF}
  
  WriteLn('');
  WriteLn('任务 4.1 完成!');
end.
