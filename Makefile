build: clean
	mkdir build

run32: build32
	riscv_sim_rv32d build/test.elf 2>build/sail.out 1>build/sail.log

run64: build64
	riscv_sim_rv64d build/test.elf 2>build/sail.out 1>build/sail.log

build64:
	riscv64-unknown-elf-gcc -march=rv64gc -mabi=lp64 -nostdlib -T link.ld test.S -o build/test.elf
	riscv64-unknown-elf-objdump -D build/test.elf > build/test.disass

build32:
	riscv32-unknown-elf-gcc -march=rv32gc -nostdlib -T link.ld test.S -o build/test.elf
	riscv32-unknown-elf-objdump -D build/test.elf > build/test.disass

clean:
	rm -rf build