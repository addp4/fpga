STACK  =     0xd0
        .org    0
        dc.l    STACK
        dc.l    loop
        .globl  _start
_start:
        # jsr     sub
        # move   #STACK,%a7
        #dc.w    0x60fe
        .org    0x10
loop:
        # store a byte at an even location
        # movew    #0x1337,word+0x99999900
        #lea     STACK,%a7
        #mulu    0xc0,%d1
        #mulu    %d0,%d2
        #addw    %d0,%d2
        #addw    #0x1234,%d0
        jsr     sub
        # move    #0x1337, (%a7)
        jmp     loop
sub:    rts
        dc.w    0x60fe
        dc.w    0x60fe
        dc.w    0x60fe
        dc.w    0xc0c4
        dc.w    0x1111
        dc.w    0x2222
        dc.w    0x7777
word:   dc.w    0x0
