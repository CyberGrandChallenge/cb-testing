
void abort(void) {
    __asm__ ("movl $0x1, %eax\n"
            "movl $0x1, %ebx\n"
            "int $0x80"
            );
} 

void _start(void) {abort();}
void _terminate(void) {abort();}
void transmit(void) {abort();}
void receive(void) {abort();}
void fdwait(void) {abort();}
void allocate(void) {abort();}
void deallocate(void) {abort();}
void random(void) {abort();}
