#!/usr/bin/python3
import sys

CPLD = 'cpld'
CON = 'connector'
DIR = 'dir'
NAME = 'name'
IOBANK = 'iobank'
PINOUT = {}

def pin(n, con=None, dir=None, name=None):
    if con:
        assert(CON not in PINOUT[n])
        PINOUT[n][CON] = con
    if dir:
        assert(DIR not in PINOUT[n])
        PINOUT[n][DIR] = dir
    if name:
        if NAME in PINOUT[n]:
            print(f"*** assign {name} to pin {n} but already named {PINOUT[n][NAME]}")
            sys.exit(1)
        PINOUT[n][NAME] = name

def main():
    for i in range(1,101):
        PINOUT[i] = {CPLD:i}
        PINOUT[i] = {IOBANK: 1 if 2<=i<=51 else 2}

    # J8 connector
    pin(33, con='J8-1', dir=2, name='J8[0]')
    pin(34, con='J8-2', dir=2, name='J8[1]')
    pin(35, con='J8-3', dir=2, name='J8[2]')
    pin(36, con='J8-4', dir=2, name='J8[3]')
    pin(38, con='J8-5', dir=2, name='J8[4]')
    pin(40, con='J8-6', dir=2, name='J8[5]')
    pin(41, con='J8-7', dir=2, name='J8[6]')
    pin(42, con='J8-8', dir=2, name='J8[7]')

    # J9 connector
    pin(87, con='J9-1', dir=3, name='J9[0]')
    pin(89, con='J9-2', dir=3, name='J9[1]')
    pin(91, con='J9-3', dir=3, name='J9[2]')
    pin(92, con='J9-4', dir=3, name='J9[3]')
    pin(96, con='J9-5', dir=3, name='J9[4]')
    pin(97, con='J9-6', dir=3, name='J9[5]')
    pin(98, con='J9-7', dir=3, name='J9[6]')
    pin(99, con='J9-8', dir=3, name='J9[7]')

    # J10 connector
    pin(1, con='J10-1', dir=1, name='J10[0]')
    pin(2, con='J10-2', dir=1, name='J10[1]')
    pin(3, con='J10-3', dir=1, name='J10[2]')
    pin(4, con='J10-4', dir=1, name='J10[3]')
    pin(5, con='J10-5', dir=1, name='J10[4]')
    pin(6, con='J10-6', dir=1, name='J10[5]')
    pin(7, con='J10-7', dir=1, name='J10[6]')
    pin(15, con='J10-8', dir=1, name='J10[7]')

    # J16 connector
    pin(83, con='J16-3', name='J16[0]')
    pin(84, con='J16-4', name='J16[1]')
    pin(81, con='J16-5', name='J16[2]')
    pin(82, con='J16-6', name='J16[3]')
    pin(77, con='J16-7', name='J16[4]')
    pin(78, con='J16-8', name='J16[5]')
    pin(75, con='J16-9', name='J16[6]')
    pin(76, con='J16-10', name='J16[7]')
    pin(72, con='J16-23', name='J16[8]')
    pin(44, con='J16-24', name='J16[9]')
    pin(70, con='J16-25', name='J16[10]')
    pin(71, con='J16-26', name='J16[12]')
    pin(69, con='J16-27', name='J16[13]')
    pin(68, con='J16-28', name='J16[14]')
    pin(67, con='J16-29', name='J16[15]')
    pin(66, con='J16-30', name='J16[16]')
    pin(64, con='J16-31', name='J16[17]')
    pin(62, con='J16-32', name='J16[18]')
    pin(61, con='J16-33', name='J16[19]')
    pin(58, con='J16-34', name='J16[20]')

    # not pinned out
    pin(16, name='SLIDE_SWITCH_1')
    pin(17, name='SLIDE_SWITCH_2')
    pin(20, name='SW_USER_1')
    pin(21, name='SW_USER_2')
    
    pin(100, name='TR_DIR_1')
    pin(29, name='TR_DIR_2')
    pin(85, name='TR_DIR_3')
    pin(30, name='TR_DIR_4')
    pin(27, name='TR_DIR_5')
    
    pin(86, name='TR_OE_1')
    pin(28, name='TR_OE_2')
    pin(74, name='TR_OE_3')
    pin(73, name='TR_OE_4')
    pin(26, name='TR_OE_5')

    pin(57, name='LED_GR_1_N')
    pin(56, name='LED_BL_1_N')
    pin(55, name='LED_RD_1_N')
    pin(54, name='LED_GR_2_N')
    pin(53, name='LED_BL_2_N')
    pin(52, name='LED_RD_2_N')
    pin(51, name='LED_GR_3_N')
    pin(50, name='LED_BL_3_N')
    pin(49, name='LED_RD_3_N')
    pin(48, name='LED_GR_4_N')
    pin(47, name='LED_BL_4_N')
    pin(43, name='LED_RD_4_N')

    pin(12, name='CLK_66MHZ')
    pin(14, name='CLK')
    # pin(62, name='CLK')
    # pin(64, name='CLK')
    # pin(44, name='RST')
    pin(24, name='JTAG_TCK')
    pin(23, name='JTAG_TDI')
    pin(25, name='JTAG_TDO')
    pin(22, name='JTAG_TMS')
    pin(18, name='UART_IN')
    pin(19, name='UART_OUT')

    for p in [8, 10, 11, 32, 37, 46, 60, 65, 79, 90, 93, 95]: pin(p, name='GND')
    for p in [9, 31, 45, 59, 80, 94]: pin(p, name='VCCIO')
    for p in [13, 39, 63, 88]: pin(p, name='VCCINT')
    
    for i in range(1,100):
        name = PINOUT[i].get(NAME)
        print(f'set_location_assignment PIN_{i} -to {name}')
    for i in range(1,100):
        print(PINOUT[i])


main()
