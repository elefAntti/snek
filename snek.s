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

snakeColor:
  mov rax, 1
  mov rdi, 1
  mov rsi, strGreen
  mov rdx, strGreenLen
  syscall
  ret

appleColor:
  mov rax, 1
  mov rdi, 1
  mov rsi, strRed
  mov rdx, strRedLen
  syscall
  ret

defaultColor:
  mov rax, 1
  mov rdi, 1
  mov rsi, strDefaultColor
  mov rdx, strDefaultColorLen
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
  mov rdi, 0
  mov rsi, 0
  call moveCursor
  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, strScore
  mov rdx, strScoreLen 
  syscall          ; );
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
  mov rax, 1       ; write(
  mov rdi, 1       ; stdout,
  mov rsi, strHelp
  mov rdx, strHelpLen 
  syscall          ; );
  pop rbx
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

; In the non-canonical mode, the terminal doesnt wait for enter key
; Also turn off terminal echo, so the pressed keys dont get printed
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

; First poll whether there are characters to read
; This avoids blocking
readKey:
  push rax
  mov rax, 4294967296 ; 32bits fd 0, 16bits 1 POLLIN, 16 bits 0 for the result of poll 
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
  inc qword[snakeLen] 
  cmp qword[snakeLen], maxLen
  jl len_ok
  mov qword[snakeLen], maxLen - 1
len_ok:
  mov r8, 0
  mov r9, 0
skip_grow:
  pop rbx
  mov rax, r8
  mov rdx, r9
  ret


lfsrRnd_init:
  mov word[lfsrState], 0xACE1
  ret

;Linear-feedback shift register
;bit = ((lfsr >> 0) ^ (lfsr >> 2) ^ (lfsr >> 3) ^ (lfsr >> 5)) & 1u;
;lfsr = (lfsr >> 1) | (bit << 15);
lfsrRnd:
  mov r8w, word[lfsrState]
  mov r9w, r8w
  mov r10w, r8w
  shr r10w, 2
  xor r9w, r10w
  shr r10w, 1
  xor r9w, r10w
  shr r10w, 2
  xor r9w, r10w
  and r9w, 1 ; bit
  shl r9w, 15
  shr r8w, 1
  or r8w, r9w
  mov word[lfsrState], r8w
  ret

;rsi = maxRnd
getRnd:
  xor rax, rax
  mov ax, word[lfsrState]
  cqo
  mov rcx, rsi
  div rcx ; rax = rax/rsi, rdx = rax%rsi
  mov rax, rdx
  push rax
  call lfsrRnd
  pop rax
  ret

placeApple:
  push rax
placeApple_again:
  mov rsi, areaWidth
  dec rsi
  call getRnd
  inc rax
  mov qword[rsp], rax
  mov rsi, areaHeight  
  dec rsi
  dec rsi
  call getRnd
  inc rax
  inc rax
  mov rbx, rax
  mov rdi, rbx 
  mov rsi, qword [rsp]
  call collisionPtr
  cmp byte [rax], 0
  jne placeApple_again
  mov byte [rax], 2 
  call appleColor
  mov rdi, rbx 
  mov rsi, qword [rsp]
  call moveCursor
  mov rdi, '@'
  call putChar
  pop rax
  ret
  
  
; x > 1, x <= areaWidth
; y > 2, y <= areaHeight
detectWallCollisions:
  mov rax, 0
  cmp qword [headx], 1
  jl wall_collision
  cmp qword [heady], 2
  jl wall_collision
  cmp qword [headx], areaWidth + 1
  jg wall_collision
  cmp qword [heady], areaHeight + 1
  jg wall_collision
  ret
wall_collision:
  mov rax, 1
  ret

;rdi x coord, rsi ycoord
collisionPtr:
  dec rdi
  dec rsi
  imul rsi, rsi, areaWidth
  add rdi, rsi
  add rdi, collisionArray
  mov rax, rdi 
  ret

handleDirKeys:
  cmp byte[inkey], 'd'
  je key_ok
  cmp byte[inkey], 'a'
  je key_ok
  cmp byte[inkey], 's'
  je key_ok
  cmp byte[inkey], 'w'
  je key_ok
  jmp keys_fail
key_ok:
  mov al, byte[inkey]
  mov byte[snakeDir], al
keys_fail:
  cmp byte[snakeDir], 'd'
  je right_pressed
  cmp byte[snakeDir], 'a'
  je left_pressed
  cmp byte[snakeDir], 's'
  je down_pressed
  cmp byte[snakeDir], 'w'
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
  mov byte [snakeDir], 'd'
  call lfsrRnd_init
  call placeApple
mainLoop:
  mov rdi, 200         ; The wait len in milliseconds
  mov rdx, 0
  call msleep
  call readKey
  call handleDirKeys
  call detectWallCollisions
  cmp rax, 1
  je die
  mov rdi, qword [heady]
  mov rsi, qword [headx]
  call moveCursor
  call snakeColor
  mov rdi, '*'
  call putChar
  mov rdi, qword [heady]
  mov rsi, qword [headx]
  call collisionPtr
  mov sil, byte[rax]
  mov byte[rax], 1
  cmp sil, 1
  je die
  cmp sil, 2 ; The apple
  jne notAnApple
  call placeApple
  add word[score], 1
  add word[snakeTargetLen], 2
  mov rdi, 0           ; Move to score position
  mov rsi, strScoreLen - 2
  call moveCursor
  call defaultColor
  xor rsi, rsi         ; Preparing to print the score
  mov rdi, msgBuff     ; the first argument is the buffer
  mov sil, byte[score] ; the second argument
  call numForm
  mov rdx, rax 
  mov rax, 1 ;write
  mov rdi, 1 ;stdout
  mov rsi, msgBuff
  syscall
notAnApple:
  call storeSnake      ; Store snake head to buffer
  cmp rax, 0           ; Rax is 0 if snake grew, otherwise rax = tailx, rdx = taily 
  je skip_erase        ; When growing, don't erase the tail
  push rax
  push rdx
  mov rsi, rax
  mov rdi, rdx
  call moveCursor
  pop rdi
  pop rsi
  call collisionPtr
  mov byte[rax], 0     ; Clear the snake from collision buffer
  mov rdi, ' '         ; Clear the snake from screen
  call putChar
skip_erase:
  cmp byte[inkey], 27  ; ESC
  jne mainLoop
  jmp exit
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
  call defaultColor
  mov rax, 60      ; exit(
  mov rdi, 0       ;  EXIT_SUCCESS
  syscall          ; );

section .bss
  areaWidth: equ 40
  areaHeight: equ 30
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
  snakeDir: resb 1
  score: resb 1
  lfsrState: resw 1
  collisionArray: resb areaWidth*areaHeight

section .rodata
  TCGETS: equ 0x5401
  TCPUTS: equ 0x5402
  strGreen: db 0o33, "[32m"
  strGreenLen: equ $ - strGreen
  strRed: db 0o33, "[31m"
  strRedLen: equ $ - strRed
  strDefaultColor: db 0o33, "[0m"
  strDefaultColorLen: equ $ - strDefaultColor
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
  strScore: db "Snek                              Score:0",10
  strScoreLen: equ $ - strScore
  strHelp: db "       WASD to turn, ESC to quit",10
  strHelpLen: equ $ - strHelp
