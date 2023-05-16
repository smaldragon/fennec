.cpu 65c02

.var M_DUMMY    $8000
.var M_A0       $8010
.var M_LCD      $8020
.var M_RTC      $8040
.var M_BEEP     $8070
.var M_BANK     $8001
.var ROM        $E000


.macro spi_lcd
    lda {0}; sta [M_LCD]; nop; nop; nop; lda [M_LCD]
.endmacro

.org [ROM]
    # setup spi ports (all ports are set low on reset)
    #   Dummy        A0           LCD              SD Card              n/a           Beeper
    lda [$8000];                  lda [$8020]; lda [$8030];             lda [$8050]; lda [$8060];
    jsr [beep]
    
    lda %1010_1111; sta [$8020]; nop; nop; nop; lda [$8020] # Display ON
    lda %0010_1111; sta [$8020]; nop; nop; nop; lda [$8020] # Enable Power
    
    # Set mirroring
    lda %1010_0001; sta [$8020]; nop; nop; nop; lda [$8020] # MX
    lda %1100_1000; sta [$8020]; nop; nop; nop; lda [$8020] # MY
    jsr [beep]
    
    lda 235; jsr [contrast]
    jsr [clrscreen]
    
    # Loading the string data into all 8 banks
    ldx 8
_bank_write
    dec X; stx [M_BANK]
    lda "B"; sta [$4300]; lda "a"; sta [$4301]; lda "n"; sta [$4302]; lda "k"; sta [$4303]; lda " "; sta [$4304]
    txa; ora %0011_0000; sta [$4305]
    stz [$4306]
    txa; bne (bank_write)
    
    # Reading bank (and printing all these values)
    ldx 8
    lda $00; sta <$00>; lda $43; sta <$01>
_bank_read
    dec X; stx [M_BANK]
    
    clc; txa; ror; ror; ror; ror
    jsr [setcursor]
    # lda 8; jsr [setline]; txa; jsr [setpage]
    
    txa; clc; adc $40; jsr [charout]
    jsr [stringout]
    lda [$4305]; jsr [charout]
    
    txa; bne (bank_read)
    
_rtc_config
    # RTC logic
    # Disable write protect
    lda [M_RTC] #%1000_1110
    lda %0111_0001; sta [M_DUMMY]; nop; nop; nop
    stz [M_DUMMY]; nop; nop; nop
    
    sta [M_RTC]; nop; nop; nop
    
    # Enable Counting
    lda [M_RTC] 
    lda %0000_0001; sta [M_DUMMY]; nop; nop; nop
    stz [M_DUMMY]; nop; nop; nop
    
    sta [M_RTC]; nop; nop; nop 

_fim
    # set cursor
    lda $4F; jsr [setcursor]
    #lda 3; jsr [setpage]
    #lda 88; jsr [setline]
    
    # Read Hours
    lda [M_RTC] 
    lda %1010_0001; sta [M_DUMMY]; nop; nop; nop; 
    stz [M_DUMMY]; nop; nop; nop; lda [M_RTC]; sta [M_RTC]
    
    sta <$03>
    lda <$03>; and $0F; 
    tax; lda [weird_conv+X]; jsr [charout]
    lda <$03>; lsr A; lsr A; lsr A; lsr A;
    tax; lda [weird_conv+X]; jsr [charout]
    
    lda ':'; jsr [charout]
    
    # Read Minutes
    lda [M_RTC] 
    lda %1100_0001; sta [M_DUMMY]; nop; nop; nop; 
    stz [M_DUMMY]; nop; nop; nop; lda [M_RTC]; sta [M_RTC]
    
    sta <$03>
    lda <$03>; and $0F; 
    tax; lda [weird_conv+X]; jsr [charout]
    lda <$03>; lsr A; lsr A; lsr A; lsr A; 
    tax; lda [weird_conv+X]; jsr [charout]
    
    lda ':'; jsr [charout]
    
    # Read Seconds
    lda [M_RTC] 
    lda %1000_0001; sta [M_DUMMY]; nop; nop; nop; 
    stz [M_DUMMY]; nop; nop; nop; lda [M_RTC]; sta [M_RTC]
    
    sta <$03>
    lda <$03>; and $0F; 
    tax; lda [weird_conv+X]; jsr [charout]
    lda <$03>; lsr A; lsr A; lsr A; lsr A; 
    tax; lda [weird_conv+X]; jsr [charout]
    
    jmp [fim]
    
_weird_conv
# Table for converting the bit reversed nibbles of the RTC module into appropriate ascii representations
.byte '0'   # 0 0000 0000
.byte '8'   # 1 0001 1000
.byte '4'   # 2 0010 0100
.byte 'C'   # 3 0011 1100
.byte '2'   # 4 0100 0010
.byte 'A'   # 5 0101 1010
.byte '6'   # 6 0110 0110
.byte 'E'   # 7 0111 1110
.byte '1'   # 8 1000 0001
.byte '9'   # 9 1001 1001
.byte '5'   # A 1010 0101
.byte 'D'   # B 1011 1101
.byte '3'   # C 1100 0011
.byte 'B'   # D 1101 1011
.byte '7'   # E 1110 0111
.byte 'F'   # F 1111 1111

.asm "lib.asm"

.pad [VECTORS]
.word ROM       # /nmi
.word ROM       # /reset
.word ROM       # brk and /irq