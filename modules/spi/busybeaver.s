        .macro  intvec num,handler
        .org    4*\num
        dc.l    \handler
        .endm

        .macro  dummy_inthandler name
\name:   bras    \name
        .endm

        .org    0
        dc.l    stack
        dc.l    _start

        intvec  2,_buserr
        intvec  3,_addrerr
        intvec  4,_illegal
        intvec  5,_zerodiv
        intvec  6,_chk
        intvec  7,_trapv
        intvec  8,_priv
        intvec  9,_trace
        intvec  10,_line1010
        intvec  11,_line1111
        intvec  24,_spurious
        intvec  25,_intlvl1
        intvec  26,_intlvl2
        intvec  27,_intlvl3
        intvec  28,_intlvl4
        intvec  29,_intlvl5
        intvec  30,_intlvl6
        intvec  31,_intlvl7
        intvec  32,_trap0
        intvec  33,_trap1
        intvec  34,_trap2
        intvec  35,_trap3
        intvec  36,_trap4
        intvec  37,_trap5
        intvec  38,_trap6
        intvec  39,_trap7
        intvec  40,_trap8
        intvec  41,_trap9
        intvec  42,_trap10
        intvec  43,_trap11
        intvec  44,_trap12
        intvec  45,_trap13
        intvec  46,_trap14
        intvec  47,_trap15
        intvec  48,_trap16
        intvec  49,_trap17
        intvec  50,_trap18
        intvec  51,_trap19
        intvec  52,_trap20
        intvec  53,_trap21
        intvec  54,_trap22
        intvec  55,_trap23
        intvec  56,_trap24
        intvec  57,_trap25
        intvec  58,_trap26
        intvec  59,_trap27
        intvec  60,_trap28
        intvec  61,_trap29
        intvec  62,_trap30
        intvec  63,_trap31
        intvec  64,_user0
        intvec  255,_user191
        
        .org    0x1000
_buserr:        bras    _buserr
_addrerr:       bras    _addrerr
_illegal:       bras    _illegal
_zerodiv:       bras    _zerodiv
_chk:           bras    _chk
_trapv:         bras    _trapv
_priv:          bras    _priv
_trace:         bras    _trace
_line1010:      bras    _line1010
_line1111:      bras    _line1111
_spurious:      bras    _spurious
_intlvl1:        bras    _intlvl1
_intlvl2:        bras    _intlvl2
_intlvl3:        bras    _intlvl3
_intlvl4:        bras    _intlvl4
_intlvl5:        bras    _intlvl5
_intlvl6:        bras    _intlvl6
_intlvl7:        bras    _intlvl7
_trap0:         bras    _trap0
_trap1:         bras    _trap1
_trap2:         bras    _trap2
_trap3:         bras    _trap3
_trap4:         bras    _trap4
_trap5:         bras    _trap5
_trap6:         bras    _trap6
_trap7:         bras    _trap7
_trap8:         bras    _trap8
_trap9:         bras    _trap9
_trap10:        bras    _trap10
_trap11:        bras    _trap11
_trap12:        bras    _trap12
_trap13:        bras    _trap13
_trap14:        bras    _trap14
_trap15:        bras    _trap15
_trap16:        bras    _trap16
_trap17:        bras    _trap17
_trap18:        bras    _trap18
_trap19:        bras    _trap19
_trap20:        bras    _trap20
_trap21:        bras    _trap21
_trap22:        bras    _trap22
_trap23:        bras    _trap23
_trap24:        bras    _trap24
_trap25:        bras    _trap25
_trap26:        bras    _trap26
_trap27:        bras    _trap27
_trap28:        bras    _trap28
_trap29:        bras    _trap29
_trap30:        bras    _trap30
_trap31:        bras    _trap31
_user0:         bras    _user0
_user191:       bras    _user191

        
        .globl  _start
_start:
        # add reset initializations here
        jsr     busybeaver
        cmpl    expected_steps, %d4
        beq     _start
        trap    #0
expected_steps:    dc.l    0x2cfdca6
        
busybeaver:
#   A0  A1  B0  B1  C0  C1  D0  D1  E0  E1  s(M)       σ(M)
#   1RB 1LC 1RC 1RB 1RD 0LE 1LA 1LD 1RH 0LA 47,176,870 4098

        movel   #0, %d4
loop:
        # Initialize tape to 0
        #lea     tape+0x30000, %a1
        lea     tape, %a1
        movel   #0xf000-tape, %d1
1:
        moveb   #0, (%a1)+
        addql   #1, %d4
        movel   %d4, 0x80034
        dbra    %d1, 1b

        # jmp     loop

        
        # a1 = tape head
        # a4 = 32-bit turing step counter
        lea     tape+0x5000, %a1
        movel   #0, %d4
        
a_:
        addql   #1, %d4
        movel   %d4, 0x80034
        tstb    (%a1)
        bne     a1
a0:     # 1RB
        moveb   #1, (%a1)+
        br      b_
a1:     # 1LC
        moveb   #1, (%a1)
        sub     #1, %a1
        br      c_
        
b_:
        addql   #1, %d4
        movel   %d4, 0x80034
        tstb    (%a1)
        bne     b1
b0:     # 1RC
        moveb   #1, (%a1)+
        br      c_
b1:     # 1RB
        moveb   #1, (%a1)+
        br      b_

c_:
        addql   #1, %d4
        movel   %d4, 0x80034
        tstb    (%a1)
        bne     c1
c0:     # 1RD
        moveb   #1, (%a1)+
        br      d_
c1:     # 0LE
        moveb   #0, (%a1)
        sub     #1, %a1
        br      e_

d_:
        addql   #1, %d4
        movel   %d4, 0x80034
        tstb    (%a1)
        bne     d1
d0:     # 1LA
        moveb   #1, (%a1)
        sub     #1, %a1
        br      a_
d1:     # 1LD
        moveb   #1, (%a1)
        sub     #1, %a1
        br      d_

e_:
        addql   #1, %d4
        movel   %d4, 0x80034
        tstb    (%a1)
        bne     e1
e0:     # 1RH
        tas     (%a1)+
        br      h_
e1:     # 0LA
        moveb   #0, (%a1)
        sub     #1, %a1
        br      a_

h_:     rts
        

        tape = 0x2000
        stack = 0xff00
