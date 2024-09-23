SYS_READ    equ    0x0
SYS_WRITE   equ    0x1
SYS_EXIT    equ    0x3C 

STDIN       equ    0x0
STDOUT      equ    0x1

NULL        equ    0x0
TAB         equ    0x9
NEW_LINE    equ    0xA
SPACE       equ    0x20


section .text

; Принимает код возврата и завершает текущий процесс
exit:
    mov rax, SYS_EXIT                                               ; Set rax to the system call number for exit
    ;xor rdi, rdi                                                    ; Set rdi to 0 (exit code 0, indicating successful termination)
    syscall                                                         ; Make the system call to exit the program
                       


; Принимает указатель на нуль-терминированную строку, возвращает её длину
string_length:
    xor rax, rax                                                    ; Clear rax (used as the string length counter)
.loop:
    cmp byte [rdi + rax], 0                                         ; Compare the current byte with null terminator (0)
    je .end                                                         ; If null terminator is found, jump to the end
    inc rax                                                         ; Increment rax to count the current character
    jmp .loop                                                       ; Repeat the loop for the next character
.end:
    ret                                                             ; Return with rax containing the length of the string




; Принимает указатель на нуль-терминированную строку, выводит её в stdout
print_string:

    push rdi                                                        ; callee register 
    call string_length
    ;pop rdi
    pop rsi

    mov rdx, rax                                                    ; string len -> rdx
    ;mov rsi, rdi                                                    ; string start address -> rsi
 
    mov rax, SYS_WRITE                                              ; write syscall
    mov rdi, STDOUT
    syscall

    ret


; Переводит строку (выводит символ с кодом 0xA)
print_newline:
    mov rdi, NEW_LINE                                               ; Load the newline character into rdi

    ;call print_char                                                 ; Call the print_char function to output the newline

    jmp print_char

    ;ret                                                             ; Return from the function



; Принимает код символа и выводит его в stdout
print_char: 
    push rdi

    mov rdx, 1                                                      ; string len -> rdx
    mov rsi, rsp                                                    ; string start address -> rsi
 
    mov rax, SYS_WRITE                                              ; write syscall
    mov rdi, STDOUT
    syscall

    add rsp, 8                                                      ; Increasing the stack pointer by 8 instead of pop
    ret                                                             ; because we don't need save the value


; Выводит знаковое 8-байтовое число в десятичном формате
print_int:
    cmp rdi, 0                                                      ; Compare rdi with 0 to check if it's negative
    jge print_uint                                                  ; If rdi >= 0, jump to print_uint (positive number)
    neg rdi                                                         ; If rdi < 0, negate rdi to make it positive
    push rdi                                                        ; Save rdi value on the stack
    mov rdi, '-'                                                    ; Load '-' character into rdi
    call print_char                                                 ; Print the minus sign
    pop rdi                                                         ; Restore the original value of rdi
    


; Выводит беззнаковое 8-байтовое число в десятичном формате
; Совет: выделите место в стеке и храните там результаты деления
; Не забудьте перевести цифры в их ASCII коды.
print_uint: 
    mov rax, rdi                                                    ; Move the unsigned integer from rdi to rax
    mov rcx, 10                                                     ; Set the divisor to 10 for decimal conversion
    mov r11, rsp                                                    ; Save the current stack pointer in r11
    sub rsp, 24                                                     ; Allocate space on the stack for the string
    dec r11                                                         ; Decrement r11 to point to the end of the buffer
    mov byte [r11], 0x0                                             ; Null-terminate the string

    divide_loop:                  
        xor rdx, rdx                                                ; Clear rdx before dividing (for div)
        div rcx                                                     ; Divide rax by 10, quotient in rax, remainder in rdx
        add dl, '0'                                                 ; Convert the remainder (digit) to its ASCII value
        dec r11                                                     ; Move the pointer back for the next digit
        mov byte [r11], dl                                          ; Store the ASCII digit in the buffer
        cmp rax, 0x0                                                ; Check if the quotient is 0
        jnz divide_loop                                             ; If not zero, repeat the division

        mov rdi, r11                                                ; Set rdi to point to the resulting string
        call print_string                                           ; Call function to print the string
        add rsp, 24                                                 ; Restore the stack pointer
        ret                                                         ; Return from the function
     


; Принимает два указателя на нуль-терминированные строки, возвращает 1 если они равны, 0 иначе
string_equals:
    xor rax, rax                                                        ; Clear rax (used as return value, 0 means strings are not equal)
    .loop:
        mov bl, byte [rdi]                                              ; Load byte from the string pointed by rdi into bl
        cmp bl, byte [rsi]                                              ; Compare the byte from rdi with the byte from rsi
        jne .false                                                      ; If bytes are not equal, jump to .false (strings are not equal)
        test bl, bl                                                     ; Check if the byte is null (end of string)
        jz .true                                                        ; If null, strings are equal, jump to .true
        inc rdi                                                         ; Move to the next byte in the first string
        inc rsi                                                         ; Move to the next byte in the second string
        jmp .loop                                                       ; Repeat the loop

    .true:
        inc rax                                                         ; Set rax to 1 (strings are equal)
        ret                                                             ; Return with rax = 1

    .false:
        ret                                                             ; Return with rax = 0 (strings are not equal)



; Читает один символ из stdin и возвращает его. Возвращает 0 если достигнут конец потока
read_char:
    push 0                                                              ; Push a zero byte onto the stack as a buffer for the character
    mov rdx, 1                                                          ; Set rdx to 1 (number of bytes to read)
    mov rsi, rsp                                                        ; Set rsi to point to the buffer (top of the stack)
    mov rax, SYS_READ                                                   ; Set rax to the system call number for read
    mov rdi, STDIN                                                      ; Set rdi to the file descriptor for standard input (STDIN)
    syscall                                                             ; Make the system call to read one character from input
    pop rax                                                             ; Pop the read character into rax (return value)
    ret                                                                 ; Return with the character in rax



; Принимает: адрес начала буфера, размер буфера
; Читает в буфер слово из stdin, пропуская пробельные символы в начале, .
; Пробельные символы это пробел 0x20, табуляция 0x9 и перевод строки 0xA.
; Останавливается и возвращает 0 если слово слишком большое для буфера
; При успехе возвращает адрес буфера в rax, длину слова в rdx.
; При неудаче возвращает 0 в rax
; Эта функция должна дописывать к слову нуль-терминатор
read_word:
    push rdi   
    push r12                                                                ; Save rdi (the buffer pointer) and r12 (temporary pointer) on the stack             

    mov r12, rdi                                                            ; Store the buffer address (in rdi) into r12 to use as a current pointer

    push rbx                                                                ; Save rbx (used for the buffer size) on the stack and store the buffer size (in rsi) into rbx
    mov rbx, rsi            

    cmp rbx, 0                                                              ; If the buffer size is 0, jump to the error handling block
    je .error

    ; Skip leading whitespace characters (spaces, tabs, newlines)
    .skip_indent: 
        call read_char                                                      ; Read a character into rax

        cmp rax, 0x20                                                       ; Check if the character is a space (' ')
        je .skip_indent                                                     ; If yes, continue skipping

        cmp rax, 0x9                                                        ; Check if it's a tab ('\t')
        je .skip_indent                                                     ; If yes, continue skipping

        cmp rax, 0xA                                                        ; Check if it's a newline ('\n')
        je .skip_indent                                                     ; If yes, continue skipping

    ; Main word-reading loop begins here
    .read:
        ; Stop reading if one of the following characters is encountered (null, space, tab, newline)
        cmp rax, 0x0                                                        ; Check for null terminator
        je .end                                                             ; End if found

        cmp rax, 0x20                                                       ; Check for space
        je .end                                                             ; End if found

        cmp rax, 0x9                                                        ; Check for tab
        je .end                                                             ; End if found

        cmp rax, 0xA                                                        ; Check for newline
        je .end                                                             ; End if found

        ; Decrement the buffer size (rbx) and check if it's exhausted
        dec rbx
        cmp rbx, 0
        jbe .error                                                          ; If the buffer size is exhausted, jump to error handling

        ; Store the character in the buffer (byte-wise)
        mov byte [r12], al

        ; Move to the next buffer position
        inc r12

        ; Read the next character
        call read_char
        jmp .read                                                           ; Repeat the process

    ; Block for successful termination of reading
    .end: 
        ; Write a null terminator at the end of the word
        mov byte [r12], 0

        ; Restore the saved registers
        pop r12
        pop rbx

        ; Get the length of the word and store it in rdx
        mov rdi, [rsp]                                                      ; Restore the buffer pointer
        call string_length                                                  ; Call string_length to get the word length
        mov rdx, rax                                                        ; Store the result (length) in rdx
        pop rax                                                             ; Restore the value of rax
        ret

    ; Block for error handling
    .error:
        ; Restore the stack and registers
        pop r12
        pop rbx
        add rsp, 8


        ; Set rax to 0 (indicating an error) and return
        xor rax, rax
        ret



; Принимает указатель на строку, пытается
; прочитать из её начала беззнаковое число.
; Возвращает в rax: число, rdx : его длину в символах
; rdx = 0 если число прочитать не удалось
parse_uint:
    xor rax, rax                                                            ; Clear rax (result accumulator)
    xor rdx, rdx                                                            ; Clear rdx (index for the input string)
    xor r12, r12
    xor rcx, rcx                                                            ; Clear rcx (temporary storage for the current digit)
    mov r10, 10                                                             ; Set r10 to 10 (base for decimal conversion)

.conversion_loop:   
    mov cl, byte [rdi+r12]                                                  ; Load the next byte (character) from the input string
    sub cl, '0'                                                             ; Convert ASCII character to its numeric value
    jl .done                                                                ; If character is less than '0', exit (non-digit)
    cmp cl, 9                                                               ; Check if the character is greater than '9'
    jg .done                                                                ; If it's greater than '9', exit (non-digit)
    
    imul r10                                                                ; Multiply rax by 10 to shift digits left
                                                                    
    add rax, rcx                                                            ; Add the current digit to the result in rax
    inc r12                                                                 ; Move to the next character in the string
    jmp .conversion_loop                                                    ; Repeat the loop for the next character

.done:
    mov rdx, r12
    xor r12, r12
    ret                                                                     ; Return the parsed integer in rax



; Принимает указатель на строку, пытается
; прочитать из её начала знаковое число.
; Если есть знак, пробелы между ним и числом не разрешены.
; Возвращает в rax: число, rdx : его длину в символах (включая знак, если он был)
; rdx = 0 если число прочитать не удалось
parse_int:
    cmp byte [rdi], '+'                                                     ; Check if the first character is '+'
    jz .handle_sign                                                         ; If it's '+', jump to handle the sign
    cmp byte [rdi], '-'                                                     ; Check if the first character is '-'
    jnz parse_uint                                                          ; If it's neither '+', nor '-', jump to parse_uint (no sign)

.handle_sign:
    push rdi                                                                ; Save rdi (the current position in the string)
    inc rdi                                                                 ; Move to the next character (after the sign)
    call parse_uint                                                         ; Call parse_uint to parse the number without the sign
    pop rdi                                                                 ; Restore rdi to the original position
    inc rdx                                                                 ; Increment rdx to move past the sign in the string
    cmp byte [rdi], '+'                                                     ; Check if the sign was '+'
    je .exit                                                                ; If it was '+', no need to negate, jump to exit
    neg rax                                                                 ; Negate the result in rax (for negative sign)

.exit:
    ret                                                                     ; Return with the signed integer in rax



; Принимает указатель на строку, указатель на буфер и длину буфера
; Копирует строку в буфер
; Возвращает длину строки если она умещается в буфер, иначе 0
string_copy:
    xor rax, rax                                                            ; Clear rax (used as the index for copying)
    .duplicate_loop:
        cmp rax, rdx                                                        ; Compare index rax with the length limit in rdx
        jge .overflow                                                       ; If rax >= rdx, jump to overflow (buffer size exceeded)
        
        mov r10b, byte [rdi + rax]                                          ; Load the byte from the source string (rdi) into r10b
        mov byte [rsi + rax], r10b                                          ; Copy the byte to the destination string (rsi)

        test r10b, r10b                                                     ; Check if the byte is null (end of string)
        jz .copied_complete                                                 ; If null byte, jump to copied_complete (copy finished)
        
        inc rax                                                             ; Increment the index rax
        jmp .duplicate_loop                                                 ; Repeat the loop for the next byte

    .overflow:
        xor rax, rax                                                        ; If overflow occurs, set rax to 0 (indicating failure)
        
    .copied_complete:
        ret                                                                 ; Return (with rax indicating success or failure)
