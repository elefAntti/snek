hello.o: hello.s
	nasm -f elf64 -o hello.o hello.s
hello: hello.o
	ld -o hello hello.o
