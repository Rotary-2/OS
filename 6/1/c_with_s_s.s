section .data
    str:db "asm_print says hello!", 0xa, 0      ; 0xa是换行符, 0是手工加上的字符串结束符的ASCII码
    str_len equ $-str

section .text
extern c_print          ; 声明C函数
global _start

_start:
    push str            ; 参数入栈
    call c_print        ; 调用C函数
    add esp, 4          ; 清理栈

    mov eax, 1          ; 退出程序
    int 0x80

global asm_print

asm_print:
    push ebp
    mov ebp, esp
    mov ebx, 1
    mov ecx, [ebp + 8]  ; 第一个参数 
    mov edx, [ebp + 12] ; 第二个参数
    mov eax, 4          ; write系统调用
    int 0x80
    pop ebp
    ret