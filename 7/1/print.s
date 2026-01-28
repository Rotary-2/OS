TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3)+TI_GDT+RPL0

[bits 32]
section .data
    put_int_buffer dq 0
section .text
global put_char
global put_str
global put_int

put_int:
    pushad
    mov ebp, esp
    mov eax, [ebp+4 * 9]    ; 获取参数
    mov edx, eax
    mov edi, 7              ; 缓冲区偏移(从高位开始)
    mov ecx, 8              ; 8个十六进制数字
    mov ebx, put_int_buffer

.convert_loop:
    and edx, 0x0000000F     ; 取最低4位
    cmp edx, 9
    jg .hex_letter
    add edx, '0'            ; 数字0-9
    jmp .store
.hex_letter:
    sub edx, 10
    add edx, 'A'            ; 字母A-F
.store:
    mov [ebx+edi], dl       ; 存入缓冲区
    dec edi
    shr eax, 4              ; 处理下4位
    mov edx, eax
    loop .convert_loop

    ; 跳过高位0
    inc edi
    cmp edi, 8
    je .full_zero
.skip_zeros:
    mov cl,  [ebx+edi]
    inc edi
    cmp cl, '0'
    jz .skip_zeros
    dec edi                 ; 指向第一个非零字符 

.full_zero:
    cmp edi, 8
    jne .print
    mov cl, '0'             ; 全零时输出单个0
.print:
    mov cl, [ebx+edi]
    push ecx
    call put_char
    add esp, 4
    inc edi
    cmp edi, 8
    jl .print

    popad
    ret

put_str:
    push ebx
    push ecx
    xor ecx, ecx
    mov ebx, [esp+12]       ; 获取字符串地址

.next_char:
    mov cl, [ebx]
    cmp cl, 0               ; 遇到\0结束
    jz .done
    push ecx                ; 参数入栈
    call put_char
    add esp, 4              ; 清理栈
    inc ebx                 ; 下一个字符
    jmp .next_char

.done:
    pop ecx
    pop ebx
    ret

put_char:
    pushad                  ; 备份寄存器
    mov ax, SELECTOR_VIDEO  ; 设置视频段选择子
    mov gs, ax

    ; 获取光标位置(高8位)
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al
    mov dx, 0x3D5
    in al, dx
    mov ah, al

    ; 获取光标位置(低8位)
    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al
    mov dx, 0x3D5
    in al, dx

    ; 光标值存入bx
    mov bx, ax
    mov ecx, [esp+36]       ; 获取传入的字符

    ; 判断字符类型
    cmp cl, 0x0D            ; 回车符
    jz .carriage_return 
    cmp cl, 0x0A            ; 换行符
    jz .line_feed
    cmp cl, 0x08            ; 退格符
    jz .backspace           

    jmp .printable

.backspace:
    dec bx                  ; 光标前移
    shl bx, 1               ; 转换为显存偏移 
    mov byte [gs:bx], 0x20  ; 写入空格
    inc bx
    mov byte [gs:bx], 0x07  ; 属性字节
    shr bx, 1
    jmp .set_cursor

.printable:
    shl bx, 1
    mov [gs:bx], cl         ; 写入字符
    inc bx
    mov byte [gs:bx], 0x07  ; 属性字节
    shr bx, 1
    inc bx                  ; 光标后移
    cmp bx, 2000            ; 是否需滚屏
    jl .set_cursor

.line_feed:
.carriage_return:
    ; 处理换行/回车：光标移到下一行首
    xor dx, dx
    mov ax, bx
    mov si, 80
    div si                  ; bx/80, 商在ax, 余数在dx
    sub bx, dx              ; 回车：回到行首
    add bx, 80              ; 换行：移到下一行
    cmp bx, 2000
    jl .set_cursor

.roll_screen:
    ; 滚屏：第1-24行内容上移, 清空最后一行
    cld
    mov ecx, 960            ; 3840字节/4
    mov esi, 0xC00B80A0     ; 第一行起始
    mov edi, 0xC00B8000     ; 第零行起始
    rep movsd               ; 复制内存

    mov ebx, 3840           ; 最后一行起始偏移
    mov ecx, 80

.clear_line:
    mov word [gs:ebx], 0x0720   ; 黑底白字空格
    add ebx, 2
    loop .clear_line
    mov bx, 1920            ; 光标置最后一行首

.set_cursor:
    ; 更新光标位置寄存器
    mov dx, 0x3D4
    mov al, 0x0E
    out dx, al

    mov dx, 0x3D5
    mov al, bh
    out dx, al              ; 写入高8位

    mov dx, 0x3D4
    mov al, 0x0F
    out dx, al

    mov dx, 0x3D5
    mov al, bl
    out dx, al              ; 写入低8位

    popad                   ; 恢复寄存器
    ret