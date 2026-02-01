BOCHS_HOME = ../../btools/bochs
ASMBFLAGS  = -I boot/include/
LIB        = -I lib/ -I lib/kernel -I lib/user/ -I kernel/ -I device/
CFLAGS     = -fno-builtin -c
NASM       = nasm
MAKE       = make -r
COPY       = copy
DEL        = del
DD         = dd
LD         = i686-elf-ld
GCC        = i686-elf-gcc

OBJECTS = 	\
	bin/main.o		\
	bin/init.o		\
	bin/interrupt.o		\
  bin/timer.o \
	bin/kernel.o		\
	bin/print.o		\
	bin/debug.o

# 默认动作

default :
	$(MAKE) os.raw

# 文件生成规则

os.raw : bin/mbr.bin bin/loader.bin bin/kernel.bin
	$(COPY) /Y ..\..\btools\bochs\os.disk bin\os.raw
	$(COPY) /Y ..\..\btools\bochs\file.disk bin\file.raw
	$(DD) if=bin/mbr.bin of=bin/os.raw bs=512 count=1
	$(DD) if=bin/loader.bin of=bin/os.raw bs=512 count=4 seek=2
	$(DD) if=bin/kernel.bin of=bin/os.raw bs=512 count=200 seek=9
	
bin/mbr.bin : boot/mbr.s
	$(NASM) $(ASMBFLAGS) -o bin/mbr.bin boot/mbr.s
  
bin/loader.bin : boot/loader.s
	$(NASM) $(ASMBFLAGS) -o bin/loader.bin boot/loader.s
	
bin/kernel.bin : $(OBJECTS)
	$(LD) $(OBJECTS) -Ttext 0xc0001500 -e main -o bin/kernel.bin
	
bin/kernel.o : kernel/kernel.s
	$(NASM) -f elf $(LIB) -o $@ $<
	
bin/print.o : lib/kernel/print.s
	$(NASM) -f elf $(LIB) -o $@ $<

bin/%.o : kernel/%.c
	$(GCC) $(LIB) $(CFLAGS) -o $@ $<
	
bin/%.o : device/%.c
	$(GCC) $(LIB) $(CFLAGS) -o $@ $<
	
# 命令

run :
	$(MAKE) os.raw
	bochs -f $(BOCHS_HOME)/bochsrc.disk -q
	
brun :
	$(MAKE) os.raw
	bochsdbg -f $(BOCHS_HOME)/bochsrc.disk -q
		

clean :
	$(DEL) /q bin\*.*

