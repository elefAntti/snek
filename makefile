%.o: %.s
	nasm -f elf64 -o $@ $<
hello: hello.o
	ld -o hello hello.o
snek: snek.o
	ld -o snek snek.o
