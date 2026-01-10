; 主引导程序
SECTION MBR vstart = 0x7c00
    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00  ;  栈指针初始化
    
    ; 清屏功能(INT 0x10, AH = 0x06)
    ; AL = 0:全部行; BH = 属性(0x07灰底白字)
    ; CX = (0, 0):左上角坐标; DX = (24, 79):右下角坐标
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10

    mov ax, 0xb800
    mov gs, ax  ; 设置显存段
    ; 显示绿色背景、红色闪烁的"1 MBR"
    mov byte [gs:0x00], '1'
    mov byte [gs:0x01], 0xA4    ; A4 = 10100100b(闪烁+绿背景+红前景)
    mov byte [gs:0x02], ' '
    mov byte [gs:0x03], 0xA4
    mov byte [gs:0x04], 'M'
    mov byte [gs:0x05], 0xA4
    mov byte [gs:0x06], 'B'
    mov byte [gs:0x07], 0xA4
    mov byte [gs:0x08], 'R'
    mov byte [gs:0x09], 0xA4

    jmp $   ; 无限循环

times 510 - ($ - $$) db 0   ; 计算剩余空间填充
db 0x55, 0xaa   ; MBR结束标志
