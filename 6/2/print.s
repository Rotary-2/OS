TI_GDT equ 0
RPL0 equ 0
SELECTOR_VIDEO equ (0x0003<<3)+TI_GDT+RPL0

[bits 32]
section .text
global put_char

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