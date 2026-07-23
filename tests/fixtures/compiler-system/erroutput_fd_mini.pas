{ Batch 27: host-free WriteLn(ErrOutput/Output) fd routing.
  ErrOutput/StdErr → fd 2; Output/default → fd 1. Not M2-A. }
program erroutput_fd_mini;
begin
  WriteLn(Output, 'stdout-marker');
  WriteLn(ErrOutput, 'stderr-marker');
  WriteLn(ErrOutput, 'status=failure');
  Halt(0);
end.