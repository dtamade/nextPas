#!/bin/bash
set -e
cd /home/dtamade/projects/nextPas/.worktrees/bench/bench/copy
go test -bench=. -benchtime=1x -cpu=1 2>&1
