.cpu 65c02

.macro spi_lcd
    lda {0}; sta [M_LCD]; nop; nop; nop; lda [M_LCD]
.endmacro

.var lcd_on     %1010_1111
.var lcd_off    %1010_1110
.var lcd_scroll %01_000000
.var lcd_page   %1011_0000
.var lcd_cmsb   %0001_0000
.var lcd_clsb   %0000_0000
.var lcd_mx     %1010_0000
.var lcd_my     %1100_0000
.var lcd_inv    %1010_0110
.var lcd_all    %1010_0100

.var lcd_power  %0010_1000
.var lcd_regu   %0010_0000
.var lcd_ev     %1000_0001
.var lcd_boost  %1111_1000
.var lcd_bias   %1010_0010

.var lcd_inc    %1110_0000
.var lcd_end    %1110_1110
.var lcd_reset  %1110_0010
.var lcd_nop    %1110_0011

.var M_DUMMY    $8000
.var M_A0       $8010
.var M_LCD      $8020
.var M_BEEP     $8070
.var ROM        $E000

_contrast
    # Takes a 8-bit value and uses it to adjust contrast settings
    tax
    
    lda lcd_ev; sta [M_LCD]; nop; nop; nop; lda [M_LCD]    # EV
    txa; and %000_1111; sta [M_LCD]; nop; nop; nop; lda [M_LCD] # EV
    txa; lsr A; lsr A; lsr A; lsr A; and %0000_0111; clc; adc lcd_regu; sta [M_LCD]; nop; nop; nop; lda [M_LCD] # RES

    lda lcd_boost; sta [M_LCD]; nop; nop; nop; lda [M_LCD]    # BOOST
    txa; rol; rol; and 1; sta [M_LCD]; nop; nop; nop; lda [M_LCD]    # BOOST

    rts

_beep
    ldy $20
    _waitlong
    # beep off
    lda [M_BEEP]
    ldx $80
    __wait1
    dec X; bne (wait1)

    # beep on
    lda $FF
    sta [M_BEEP]
    ldx $80
    __wait2
    dec X; bne (wait2)
    dec Y; bne (waitlong)
    
    rts

_charout
    psh X
    tax
    lda [M_A0]
    
    lda [font + X]
    sta [M_LCD]; nop; lda [font + 256 + X]; bit [M_LCD]
    sta [M_LCD]; nop; lda [font + 512 + X]; bit [M_LCD]
    sta [M_LCD]; nop; lda [font + 768 + X]; bit [M_LCD]
    sta [M_LCD]; nop; pul X; bit [M_LCD]
    sta [M_A0]; nop; nop
    rts
_stringout
    pha
    phx
    phy
    # zp 0-1 contains the address of the string to read, 
    # prints characters to lcd until a zero is hit
    # a string can be max 255 chars
    lda [M_A0]
    ldy 0
    __loop
    lda [<$00>+Y]   # cur char to X
    tax
    beq (end)       # we break if the current char is zero
    
    #1  2  3  4  5  6  7  8  9  A
    #nop...nop...nop...bit.x..y.rd
    #nop...lda.x..y.rd.bit.x..y.rd
    lda [font + X]
    sta [M_LCD]; nop; lda [font + 256 + X]; bit [M_LCD]
    sta [M_LCD]; nop; lda [font + 512 + X]; bit [M_LCD]
    sta [M_LCD]; nop; lda [font + 768 + X]; bit [M_LCD]
    sta [M_LCD]; nop; nop; inc Y; bit [M_LCD]
    
    tya             # get string offset back from Y
    
    bra (loop)
    
    __end
    sta [M_A0]
    pla
    plx
    ply
    rts
    
_setpage
    sta [M_A0]; nop; nop; nop

    clc; adc lcd_page
    sta [M_LCD]; nop; nop; nop; lda [M_LCD]
    
    rts
    
_setline
    phx
    sta [M_A0]; nop; nop; nop

    tax
    and $F0
    lsr A; lsr A; lsr A; lsr A; ora lcd_cmsb
    sta [M_LCD]; txa; and $0F; nop; bit [M_LCD]
    sta [M_LCD]; nop; nop; nop; bit [M_LCD]
    
    plx
    rts
    
_setcursor
    # Cursor location is stored in A and is a value from 0 to 255
    sta <$04>; lsr A; lsr A; lsr A; lsr A; lsr A
    jsr [setpage]
    
    lda <$04>; and %0001_1111; asl A; asl A; clc; adc 4
    jsr [setline]
    
    lda [M_A0]
    rts

_clrscreen
    # Set lcd address (col MSB, col LSB, col wow)
    lda 4; jsr [setline]
    lda 0; jsr [setpage]
    
    lda [M_A0]
    ldx 0
    __clear_loop
    stz [M_LCD]; nop; nop; nop; ldy [M_LCD]
    stz [M_LCD]; nop; nop; nop; ldy [M_LCD]
    stz [M_LCD]; nop; nop; nop; ldy [M_LCD]
    stz [M_LCD]; nop; nop; nop; ldy [M_LCD]
    
    inc X; txa; and %0001_1111
    
    bne (skip)
        sta [M_A0]
        txa
        lsr A; lsr A; lsr A; lsr A; lsr A; ora %1011_0000; sta [M_LCD]; nop; nop; nop; lda [M_LCD]
        lda lcd_cmsb;    sta [M_LCD]; nop; nop; nop; lda [M_LCD] # COLUMN MSB
        lda %0000_0100; sta [M_LCD]; nop; nop; nop; lda [M_LCD] # COLUMN LSB
        lda [M_A0]
    __skip
    
    txa; bne (clear_loop)
    
    sta [M_A0]
    rts

_font
.bin "font.bin"