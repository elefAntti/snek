global _start


section .text

; write a two digit number in a buffer
; rdi is the adress of a buffer
; rsi is the number to format
; returns the number of digits in rax 
numForm:
  mov rax, rsi
  mov r11, rdi
  cqo
  mov rcx, 10
  div rcx ; rax = rax/10, rdx = rax%10
  test rax, rax
  je numForm_skipTens
  mov byte [rdi], '0'
  add byte [rdi], al
  inc rdi
numForm_skipTens:
  mov byte [rdi], '0'
  add byte [rdi], dl
  inc rdi
  mov rax, rdi
  sub rax, r11 
  ret  

;move cursor to coords given in rdi, rsi
moveCursor:
  inc rdi              ; Make the origin (0,0)
  inc rsi
  push rbp             ; callee saved registeris, pushing also aligns the stack
  push r12
  push r13
  mov r12, rsi         ; Make a backup of the second argument
  mov rbp, msgBuff
  mov byte [rbp], 0o33
  inc rbp
  mov byte [rbp], '['
  inc rbp
  mov rsi, rdi         ; the second argument is the first argument of this function
  mov rdi, rbp         ; the first argument is the buffer
  call numForm
  add rbp, rax         ; progress the pointer by the number of digits

  mov byte [rbp], ';'
  inc rbp
  mov rsi, r12         ; the second argument is the second argument of this function
  mov rdi, rbp         ; the first argument is the buffer
  call numForm
  add rbp, rax         ; progress the pointer by the number of digits
  mov byte [rbp], 'H'
  inc rbp
  mov rax, 1
  mov rdi, 1
  mov rsi, msgBuff 
  mov rdx, rbp
  sub rdx, rsi
  syscall
  pop r13
  pop r12
  pop rbp
  ret

clearScreen:
  mov rax, 1
  mov rdi, 1
  mov rsi, strClear
  mov rdx, 2
  syscall
  ret

; put a single cher from register rdi to screen
putChar:
  push rdi
  mov rsi, rsp
  mov rax, 1
  mov rdi, 1
  mov rdx, 1
  syscall
  pop rdi
  ret

; Can be used to sleep for rdi milliseconds, where rdi < 1000
msleep:
  imul rdi, rdi, 1000 ; ms to us
  imul rdi, rdi, 1000 ; us to ns
  push rdi            ; tv_nsec
  xor rax, rax
  push rax            ; tv_sec
  mov rax, 35         ; nanosleep
  mov rdi, rsp
  mov rdx, rsp
  syscall
  pop rax
  pop rax
  ret

drawFrame:
  push rbx
  mov rbx, areaHeight 
drawFrame_loop:
  mov rdi, rbx
  mov rsi, 2
  call moveCursor
  mov rdi, '*'
  call putChar
  dec rbx
  jnz drawFrame_loop

  mov rbx, areaWidth
drawFrame_loop2:
  mov rdi, 1
  mov rsi, rbx
  call moveCursor
  mov rdi, '*'
  call putChar
  mov rdi, areaHeight
  mov rsi, rbx
  call moveCursor
  mov rdi, '*'
  call putChar
  dec rbx
  jnz drawFrame_loop2
  pop rbx
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
  call drawFrame

  mov rdi, 500
  call msleep
  mov rdi, 500
  call msleep
  mov rax, 60      ; exit(
  mov rdi, 0       ;  EXIT_SUCCESS
  syscall          ; );

section .bss
  msgBuff: resb   64 ; 64 byte buffer   
section .rodata
  areaWidth: equ 60
  areaHeight: equ 30
  strCUP: db 0o33, "[5;5H"
  blue: db 0o33, "[94m"
  bluelen: equ $ - blue
  defaultcolor: db 0o33, "[0m"
  defaultcolorlen: equ $ - defaultcolor
  strClear: db 0o33, "c"

