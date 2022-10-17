global _start


section .text
clearScreen:
  mov rax, 1
  mov rdi, 1
  mov rsi, strClear
  mov rdx, 2
  syscall
  ret
 
bluePrint:
  push r12
  push r13

  mov r12, rsi
  mov r13, rdx

  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, blue     
  mov rdx, bluelen 
  syscall          ; );

  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, r12 
  mov rdx, r13 
  syscall          ; );

  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, defaultcolor
  mov rdx, defaultcolorlen 
  syscall          ; );

  pop r13
  pop r12
  ret

_start:
  call clearScreen
  mov rbx, 10
loop:
; mov rax, 1       ; write(
;  mov rdi, 1       ; stdout,
  mov rsi, msg     ; "Hello world!\n"
  mov rdx, msglen  ; sizeof(msg)
;  syscall          ; );
  call bluePrint
  dec rbx
  jnz loop


  mov rax, 60      ; exit(
  mov rdi, 0       ;  EXIT_SUCCESS
  syscall          ; );

section .rodata
  blue: db 0o33, "[94m"
  bluelen: equ $ - blue
  defaultcolor: db 0o33, "[0m"
  defaultcolorlen: equ $ - defaultcolor
  msg: db "Hello world!", 10
  msglen: equ $ - msg
  strClear: db 0o33, "c"

