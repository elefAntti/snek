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

setNonBlocking:
  xor rdi, rdi ; STDIN
  mov rsi, 3   ; F_GETFL
  mov rax, 72  ; fcntl
  syscall
  or rax, 2048 ; O_NONBLOCK
  mov rdx, rax
  mov rsi, 4   ; F_SETFL
  xor rdi, rdi
  syscall
  ret

setBlocking:
  xor rdi, rdi ; STDIN
  mov rsi, 3   ; F_GETFL
  mov rax, 72  ; fcntl
  syscall
  and rax, ~2048 ; ~O_NONBLOCK
  mov rdx, rax
  mov rsi, 4   ; F_SETFL
  xor rdi, rdi
  syscall
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
  mov rax, 0       ; read(
  mov rdi, 0       ; stdin,
  mov rsi, inkey   ; &inkey,
  mov rdx, 1       ; size
  syscall          ; );
  ret

_start:
  call clearScreen
  mov rbx, 10
  call drawFrame

  call setNonCanonical
  call setNonBlocking
mainLoop:
  call readKey
  mov rdi, 500
  call msleep
  cmp byte[inkey], 27  ; ESC
  jne mainLoop

  call setCanonical
  call setBlocking
  mov rax, 60      ; exit(
  mov rdi, 0       ;  EXIT_SUCCESS
  syscall          ; );

section .bss
  msgBuff: resb   64 ; 64 byte buffer   
  termios: resb   36 
  CANON: equ 1<<1 
  ECHO: equ 1<<3 
  inkey: resb 4
  headx: resw 1
  heady: resw 1


section .rodata
  TCGETS: equ 0x5401
  TCPUTS: equ 0x5402
  areaWidth: equ 60
  areaHeight: equ 30
  strCUP: db 0o33, "[5;5H"
  blue: db 0o33, "[94m"
  bluelen: equ $ - blue
  defaultcolor: db 0o33, "[0m"
  defaultcolorlen: equ $ - defaultcolor
  strClear: db 0o33, "c"
  strEdge: db "+----------------------------------------+", 10
  strMid:  db "|                                        |", 10
  edgeLen: equ $ - strMid
