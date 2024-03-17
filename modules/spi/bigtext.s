        # test that memory access works over a large address range using
        # a long sequence of instructions. one use is to test wiring and
        # signal issues along the address datapath.
        
        .macro  sum from=0, to=5
        movel   4*\from, %d0
        movew   2*\from, %d1
        moveb   \from, %d2
        .if     \to-\from
        sum     "(\from+1)",\to
        .endif
        .endm

        .org    0
        dc.l    0
        dc.l    _start

        .globl  _start
_start:
        sum     0,63
        #sum     0,99
        #sum     100,199
        jmp     _start
