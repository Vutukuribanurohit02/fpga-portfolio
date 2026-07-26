# start.s - Bare-metal entry point: sets up the stack pointer before
# any C code runs, then calls main(). This must run first, unmodified
# by any C compiler prologue (hence hand-written assembly, not C).
.section .text.start
.global _start
_start:
    li sp, 0x1ffc      # stack top: near end of 8KB RAM, word-aligned, leaves headroom below MEM_BYTES
    call main

1:
    j 1b               # halt: infinite loop, same "done" signal the testbench watches for
