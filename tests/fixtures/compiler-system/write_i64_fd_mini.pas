{ Batch 29: WriteLn integer on Output vs ErrOutput routes write_i64_decimal fd.
  Not M2-A. }
program write_i64_fd_mini;
begin
  WriteLn(Output, 42);
  WriteLn(ErrOutput, 7);
  Halt(0);
end.