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

hideCursor:
  mov rax, 1
  mov rdi, 1
  mov rsi, strHideCursor
  mov rdx, strHideCursorLen
  syscall
  ret

showCursor:
  mov rax, 1
  mov rdi, 1
  mov rsi, strShowCursor
  mov rdx, strShowCursorLen
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
; and rdx seconds
msleep:
  imul rdi, rdi, 1000 ; ms to us
  imul rdi, rdi, 1000 ; us to ns
  push rdi            ; tv_nsec
  push rdx            ; tv_sec
  mov rax, 35         ; nanosleep
  mov rdi, rsp
  mov rdx, rsp
  syscall
  pop rax
  pop rax
  ret

drawFrame:
  push rbx
  mov rdi, 1
  mov rsi, 0
  call moveCursor
  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, strEdge
  mov rdx, edgeLen 
  syscall          ; );

  mov rbx, areaHeight 
drawFrameLoop:
  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, strMid
  mov rdx, edgeLen 
  syscall          ; );
  dec rbx
  jnz drawFrameLoop
  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, strEdge
  mov rdx, edgeLen 
  syscall          ; );
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

readTermios:
  mov rax, 16 ;ioctl
  xor rdi, rdi ; STDIN
  mov rsi, TCGETS
  mov rdx, termios
  syscall
  ret

writeTermios:
  mov rax, 16 ;ioctl
  xor rdi, rdi ; STDIN
  mov rsi, TCPUTS
  mov rdx, termios
  syscall
  ret

setNonCanonical:
  push rax ;to align the stack
  call readTermios
  and dword [termios+12], ~CANON
  and dword [termios+12], ~ECHO
  call writeTermios
  pop rax
  ret

setCanonical:
  push rax ;to align the stack
  call readTermios
  or dword [termios+12], CANON
  or dword [termios+12], ECHO
  call writeTermios
  pop rax
  ret


readKey:
  push rax
  mov rax, 4294967296
  mov qword [rsp], rax
  mov rax, 7       ; poll(
  ;mov rdi, pollfd_buffer
  mov rdi, rsp
  mov rsi, 1       ; nfds
  mov rdx, 0       ; timeout
  syscall          ; );
  cmp rax, 1
  jl readKey_skip
  mov rax, 0       ; read(
  mov rdi, 0       ; stdin,
  mov rsi, inkey   ; &inkey,
  mov rdx, 1       ; size
  syscall          ; );
readKey_skip:
  pop rax
  ret


; Store snake coordinates in the buffer and grow the snake towards the target len
; return rax = tailx or 0 if no erasing needs to be done
;        rdx = tailx or 0
storeSnake:
  push rbx
  mov rbx, qword [snakeHeadIdx]
  mov rax, qword [headx]
  mov qword [snakeX + 8 * rbx], rax
  mov rax, qword [heady]
  mov qword [snakeY + 8 * rbx], rax
  inc rbx 
  cmp rbx, maxLen
  jl skip_head_wraparound
  mov rbx, 0
skip_head_wraparound:
  mov qword [snakeHeadIdx], rbx
  mov rbx, qword[snakeTargetLen]
  cmp qword[snakeLen], rbx
  jl need_to_grow
  mov rbx, qword [snakeTailIdx]
  mov r8, qword [snakeX + rbx * 8]
  mov r9, qword [snakeY + rbx * 8]
  inc rbx
  cmp rbx, maxLen
  jl skip_tail_wraparound
  mov rbx, 0
skip_tail_wraparound:
  mov qword [snakeTailIdx], rbx
  jmp skip_grow
need_to_grow:
  inc qword[snakeLen] ; TODO: ensure that it doesn't exceed maxLen
  mov r8, 0
  mov r9, 0
skip_grow:
  pop rbx
  mov rax, r8
  mov rdx, r9
  ret

detectWallCollisions:
  mov rax, 0
  cmp qword [headx], 1
  jle wall_collision
  cmp qword [heady], 2
  jle wall_collision
  cmp qword [headx], areaWidth
  jg wall_collision
  cmp qword [heady], areaHeight
  jg wall_collision
  ret
wall_collision:
  mov rax, 1
  ret

_start:
  call clearScreen
  call hideCursor
  mov rbx, 10
  call drawFrame

  call setNonCanonical
  mov qword [headx], 2
  mov qword [heady], areaHeight>>1 
  mov qword [snakeTargetLen], 10
mainLoop:
  mov rdi, 500
  mov rdx, 0
  call msleep
  call readKey
  cmp byte[inkey], 'd'
  je right_pressed
  cmp byte[inkey], 'a'
  je left_pressed
  cmp byte[inkey], 's'
  je down_pressed
  cmp byte[inkey], 'w'
  je up_pressed
  jmp keys_handled

up_pressed:
  sub qword [heady], 1
  jmp keys_handled
down_pressed:
  add qword [heady], 1
  jmp keys_handled
left_pressed:
  sub qword [headx], 1
  jmp keys_handled
right_pressed:
  add qword [headx], 1
keys_handled:
  mov rdi, qword [heady]
  mov rsi, qword [headx]
  call moveCursor
  mov rdi, '*'
  call putChar
  call storeSnake
  mov rsi, rax
  mov rdi, rdx
  call moveCursor
  mov rdi, ' '
  call putChar
  call detectWallCollisions
  cmp rax, 1
  je die
  cmp byte[inkey], 27  ; ESC
  jne mainLoop
die:
  mov rdi, 0
  mov rsi, 10
  call moveCursor
  mov rax, 1 ;write
  mov rdi, 1 ;stdout
  mov rsi, strDeath
  mov rdx, strDeathLen
  syscall
  mov rdi, 0
  mov rdx, 3
  call msleep
exit:
  call setCanonical
  call clearScreen
  call showCursor
  mov rax, 60      ; exit(
  mov rdi, 0       ;  EXIT_SUCCESS
  syscall          ; );

section .bss
  msgBuff: resb   64 ; 64 byte buffer   
  termios: resb   36 
  CANON: equ 1<<1 
  ECHO: equ 1<<3 
  inkey: resb 4
  headx: resq 1
  heady: resq 1
  maxLen: equ 200
  snakeX: resq maxLen
  snakeY: resq maxLen
  snakeHeadIdx: resq 1
  snakeTailIdx: resq 1
  snakeLen: resq 1
  snakeTargetLen: resq 1

section .rodata
  TCGETS: equ 0x5401
  TCPUTS: equ 0x5402
  areaWidth: equ 40
  areaHeight: equ 30
  strCUP: db 0o33, "[5;5H"
  blue: db 0o33, "[94m"
  bluelen: equ $ - blue
  defaultcolor: db 0o33, "[0m"
  defaultcolorlen: equ $ - defaultcolor
  strShowCursor: db 0o33, "[?25h"
  strShowCursorLen: equ $ - strShowCursor
  strHideCursor: db 0o33, "[?25l"
  strHideCursorLen: equ $ - strHideCursor
  strClear: db 0o33, "c"
  strEdge: db "+-----------------------------------------+", 10
  strMid:  db "|                                         |", 10
  edgeLen: equ $ - strMid
  strDeath: db "Oh noes!"
  strDeathLen: equ $ - strDeath
