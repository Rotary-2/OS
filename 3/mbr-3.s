%include "boot.inc"
; 主引导程序
SECTION MBR vstart=0x7c00 ; 不能写SECTION MBR vstart = 0x7c00
    ; 初始化段寄存器
    mov ax, cs
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov fs, ax
    mov sp, 0x7c00  ; 栈指针初始化
    mov ax, 0xb800  ; 显存设置
    mov gs, ax      ; 设置gs指向显存段

    ; 清屏功能(INT 0x10, AH = 0x06)
    ; AL = 0:全部行; BH = 属性(0x07灰底白字)
    ; CX = (0, 0):左上角坐标; DX = (24, 79):右下角坐标
    mov ax, 0x0600
    mov bx, 0x0700
    mov cx, 0x0000
    mov dx, 0x184f
    int 0x10

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

    mov eax, LOADER_START_SECTOR    ; 起始扇区lba地址
    mov bx, LOADER_BASE_ADDR        ; 写入的地址
    mov cx, 1                       ; 待读入的扇区
    call rd_disk_m_16               ; 以下读取程序的起始部分（一个扇区）

    jmp LOADER_BASE_ADDR

;------------------------------------------------------------------------------
; 功能：读取硬盘n个扇区
; eax = LBA扇区号
;bx = 将数据写入的内存地址
;cx = 读入的扇区数
;------------------------------------------------------------------------------
rd_disk_m_16:
    mov esi, eax    ; 备份eax
    mov di, cx      ; 备份cx
; 读写硬盘：
; 第一步：设置要读取的扇区数
    mov dx, 0x1f2
    mov al, cl 
    out dx, al      ; 读取的扇区数

    mov eax, esi    ; 回复eax

; 第二步：将LBA地址存入0x1f3~0x1f6
    
    ; LBA地址7~0位写入端口0x1f3
    mov dx, 0x1f3
    out dx, al

    ; LBA地址15~8位写入端口0x1f4
    ;mov cl, 8
    ;shr eax, cl
    shr eax, 8
    mov dx, 0x1f4
    out dx, al
    
    ; LBA地址23~16位写入端口0x1f5
    ;shr eax, cl
    shr eax, 8
    mov dx, 0x1f5
    out dx, al

    ; LBA地址27~24位写入端口0x1f6 设置LBA方式操作磁盘
    ;shr eax, cl
    shr eax, 8
    and al, 0x0f      ; LBA第24~27位
    or al, 0xe0     ; 设置7~4位为1110， 表示LBA模式
    mov dx, 0x1f6
    out dx, al 

; 第三步：向0x1f7端口写入读命令, 0x20
    mov dx, 0x1f7
    mov al, 0x20
    out dx, al

; 第四步：读取0x1f7端口，检测硬盘状态
.not_ready:
    ; 同一端口，写时表示写入命令字， 读时表示读入硬盘状态
    nop 
    in al, dx
    and al, 0x88   ; 第四位为1表示硬盘控制器已准备好数据传输
                   ; 第八位为1表示硬盘很忙
    cmp al, 0x08    
    jnz .not_ready  ; 若未准备好，继续等

; 第五步：从0x1f0端口读数据
    mov ax, di      ; 要读取的扇区数
    mov dx, 256     ; 一个扇区有512字节，每次读入一个字，共需di*512/2次
    mul dx          ; 所以di*256
    mov cx, ax
    mov dx, 0x1f0
.go_on_read:
    in ax, dx
    mov [bx], ax
    add bx, 2
    loop .go_on_read
    ret

times 510 - ($ - $$) db 0   ; 计算剩余空间填充
db 0x55, 0xaa   ; MBR结束标志
