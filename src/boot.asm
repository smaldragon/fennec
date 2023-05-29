.cpu 65c02

.var M_DUMMY    $8000
.var M_A0       $8010
.var M_LCD      $8020
.var M_SD       $8030
.var M_RTC      $8040
.var M_BEEP     $8070
.var M_BANK     $8001
.var ROM        $E000

.var zp_fat32_variables $10

.var f32_vbr                  zp_fat32_variables + $00
.var f32_tables               zp_fat32_variables + $04
.var f32_data                 zp_fat32_variables + $08
.var f32_cur                  zp_fat32_variables + $0C
.var f32_clustersize          zp_fat32_variables + $10  # 1 byte
.var f32_sectorcount          zp_fat32_variables + $11


.macro spi_lcd
    lda {0}; sta [M_LCD]; nop; nop; nop; lda [M_LCD]
.endmacro


.macro spi_sd
    lda {0}; sta [M_LCD]; nop; nop; nop; lda [M_LCD]
.endmacro

.org [ROM]
    # setup spi ports (all ports are set low on reset)
    #   Dummy        A0           LCD              SD Card              n/a           Beeper
    lda [$8000];                  lda [$8020];                          lda [$8050]; lda [$8060];
    
    jsr [beep]
    
    # SD CARD INIT
    
    lda 'F'; sta [$0403]; stz [$0404];stz [$0405]
    # cmd0 reset
    lda sdcmd0.lo; sta <$00>
    lda sdcmd0.hi; sta <$01>
    ldx $FF
    stx [M_DUMMY]; nop; nop; nop; nop
    stx [M_SD]; nop; nop; nop; nop
    
    jsr [sdcmd]; sta [$0400]
    bit [M_SD]

    # cmd8 if_cond
    lda sdcmd8.lo; sta <$00>
    lda sdcmd8.hi; sta <$01>
    jsr [sdcmd]; sta [$0401]
    lda $FF
    sta [M_DUMMY]; nop; nop; nop; nop
    sta [M_DUMMY]; nop; nop; nop; nop
    sta [M_DUMMY]; nop; nop; nop; nop
    sta [M_DUMMY]; nop; nop; nop; nop
    bit [M_SD]
    
    ldx $FF
    _sdinit
        ldy $FF
        __delay
            nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop; nop;
            dec Y
        bne (delay)
        # This is a two byte command, cmd55 followed by acmd41
        dec X
        bne (next)
        jmp [initfail]
        __next
        lda sdcmd55.lo; sta <$00>
        lda sdcmd55.hi; sta <$01>
        jsr [sdcmd]; sta [$0402]
        bit [M_SD]
        
        lda sdcmd41.lo; sta <$00>
        lda sdcmd41.hi; sta <$01>
        jsr [sdcmd]; sta [$0403]
        bit [M_SD]; clc; adc 0
    bne (sdinit)
    
    # Open SD CARD Sector 0 (MASTER BOOT RECORD MBR) and find a FAT32 PART
    stz <$00>; stz <$01>; stz <$02>; stz <$03>; stz <$04>; lda $05; sta <$05>; jsr [sdsector]
    
    lda [$06FE]; sta [$0404]
    lda [$06FF]; sta [$0405]
    stz [$0406]
    
    ldx 0
    lda [$06BE+$04+X]
    cmp 12; beq (foundpart)
    ldx 16
    lda [$06BE+$04+X]
    cmp 12; beq (foundpart)
    ldx 32
    lda [$06BE+$04+X]
    cmp 12; beq (foundpart)
    ldx 48
    lda [$06BE+$04+X]
    cmp 12; beq (foundpart)
    
    jmp [initfail]
    
    _foundpart
    # JUMP to and Save FAT32 VBR VOLUME BOOT RECORD
    lda [$06BE+$08+X]; sta <$00>
    lda [$06BE+$09+X]; sta <$01>
    lda [$06BE+$0A+X]; sta <$02>
    lda [$06BE+$0B+X]; sta <$03>
    stz <$04>; lda $05; sta <$05>
    jsr [sdsector]
    
    lda [$06FE]; sta [$0406]
    lda [$06FF]; sta [$0407]
    stz [$0408]
    
    lda <$00>; sta <f32_vbr+0>
    lda <$01>; sta <f32_vbr+1>
    lda <$02>; sta <f32_vbr+2>
    lda <$03>; sta <f32_vbr+3>
    
    # Calculate start of FAT tables
    clc
    lda [$050E]; adc <$00>; sta <f32_tables+0>
    lda [$050F]; adc <$01>; sta <f32_tables+1>
    lda 0      ; adc <$02>; sta <f32_tables+2>
    lda 0      ; adc <$03>; sta <f32_tables+3>
    
    lda [$050D]; sta <f32_clustersize>
    
    # ______ Calculate Start of DATA
    # Add the size of the table area + 2 to start of tables to get the start of the DATA
    clc; rol [$0524]; rol [$0525]; rol [$0526]; rol [$0527]
    clc
    lda <f32_tables+0>; adc [$0524]; sta <f32_data+0>
    lda <f32_tables+1>; adc [$0525]; sta <f32_data+1>
    lda <f32_tables+2>; adc [$0526]; sta <f32_data+2>
    lda <f32_tables+3>; adc [$0527]; sta <f32_data+3>
    
    lda <f32_tables+0>; sta <$00>
    lda <f32_tables+1>; sta <$01>
    lda <f32_tables+2>; sta <$02>
    lda <f32_tables+3>; sta <$03>
    stz <$04>; lda $05; sta <$05>
    jsr [sdsector]
    
    lda <f32_data+0>; sta <$00>
    lda <f32_data+1>; sta <$01>
    lda <f32_data+2>; sta <$02>
    lda <f32_data+3>; sta <$03>
    stz <$04>; lda $05; sta <$05>
    jsr [sdsector]
  
    _initfail
    lda [M_SD]
    stz [M_DUMMY]; nop; nop; nop
    
    # LCD INIT
    
    lda %1010_1111; sta [$8020]; nop; nop; nop; lda [$8020] # Display ON
    lda %0010_1111; sta [$8020]; nop; nop; nop; lda [$8020] # Enable Power
    
    # Set mirroring
    lda %1010_0001; sta [$8020]; nop; nop; nop; lda [$8020] # MX
    lda %1100_1000; sta [$8020]; nop; nop; nop; lda [$8020] # MY
    jsr [beep]
    
    lda 235; jsr [contrast]
    jsr [clrscreen]
    
    # Loading the string data into all 8 banks
    ldx 0
_bank_write
        stx [M_BANK]
        stx [$4300]
        inc X
    bne (bank_write)
    
    lda $FF
    ldx $FE
    ldy $01
_bank_calc
        stx [M_BANK]
        cmp [$4300]; bcc (end)
        tya; sed; clc; adc 1; cld; tay
        txa
        dec X
    bne (bank_calc)
    __end
    lda $E0; jsr [setcursor]
    tya
    lsr A; lsr A; lsr A; lsr A; clc; adc $30; jsr [charout]
    tya
    and $0F; clc; adc $30; jsr [charout]
    lda bankstr.lo; sta <$00>
    lda bankstr.hi; sta <$01>
    jsr [stringout] 
    
    # Print out sd response
    lda $ED; jsr [setcursor]
    lda $00; sta <$00>
    lda $04; sta <$01>
    jsr [stringout]
    lda $04; sta <$00>
    lda $04; sta <$01>
    jsr [stringout]
    
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
    
    # FUN !!
_readroot
    
    ldx $FF; stx [M_DUMMY]
    stz <f32_sectorcount>
    lda <f32_data+0>; sta <$00>; sta <f32_cur+0>
    lda <f32_data+1>; sta <$01>; sta <f32_cur+1>
    lda <f32_data+2>; sta <$02>; sta <f32_cur+2>
    lda <f32_data+3>; sta <$03>; sta <f32_cur+3>
    stz <$04>; lda $05; sta <$05>
    jsr [sdsector]
    
    
    lda $00; sta <$06>
    lda $05; sta <$07>
    stz <$08>
    ldx $00
    ldy $00
    
    __loop
        
        lda [<$06>];
        cmp $00; bne (skip)
        jmp [finish]
        __skip
        cmp $e5; beq (invalid)
        
        ldy $0B; lda [<$06>+Y]
        cmp $0f; beq (invalid)
        cmp $08; beq (invalid)
        cmp $04; beq (invalid)
        bra (valid)
        ___invalid
        jmp [skipend]
        ___valid
        ldy $00
        
        # Print to screen
        lda <$08>; jsr [setcursor]
        
        ldy $0B
        ldx $10; lda [<$06>+Y]; and $10; beq (isfile)
        ldx $12
        ___isfile
        txa; jsr [charout]; inc X
        txa; jsr [charout]
        
        stz <$09>
        ldy 0
        ___nameloop
            lda [<$06>+Y]; sta [$0400+Y]
            cmp [bootfile+Y]; beq (match)
            inc <$09>
            ____match
            inc Y; tya; cmp 8;
        bne (nameloop)
        
        ____skip
        stz [$0408]
        lda $00; sta <$00>
        lda $04; sta <$01>
        jsr [stringout]
        lda '.'; jsr [charout]
        
        ldy 8
        ___extloop
            lda [<$06>+Y]; sta [$0400+Y]
            cmp [bootfile+Y]; beq (match)
            inc <$09>
            ____match
            inc Y; tya; cmp 8+3;
        bne (extloop)
        
        stz [$040B]
        lda $08; sta <$00>
        lda $04; sta <$01>
        jsr [stringout]
        
        lda <$09>; bzc (nomatch)
        jmp [bootload]
        ___nomatch
        
        lda <$08>; clc; adc $20; sta <$08>; cmp $E0
        beq (finish)
        
        ___skipend
        clc
        lda <$06>; adc $20; sta <$06>
        lda <$07>; adc   0; sta <$07>
        cmp $07
    beq (nextsector)
    jmp [loop]
    __nextsector
    clc
    lda <f32_sectorcount>; adc 1; cmp <f32_clustersize>; beq (finish); sta <f32_sectorcount>
    
    clc
    lda <f32_cur+0>; adc 1; sta <$00>; sta <f32_cur+0>
    lda <f32_cur+1>; adc 0; sta <$01>; sta <f32_cur+1>
    lda <f32_cur+2>; adc 0; sta <$02>; sta <f32_cur+2>
    lda <f32_cur+3>; adc 0; sta <$03>; sta <f32_cur+3>
    stz <$04>; lda $05; sta <$05>
    jsr [sdsector]
    
    lda $00; sta <$06>
    lda $05; sta <$07>
    
    jmp [loop]
    
    _finish
    
    #TODO: boot up
_fim
    # set cursor
    lda $F8; jsr [setcursor]
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
    
_bootload
    stz [M_BANK]
    ldy $1A; lda [<$06>+Y]; sta <$00>
    ldy $1B; lda [<$06>+Y]; sta <$01>
    ldy $14; lda [<$06>+Y]; sta <$02>
    ldy $15; lda [<$06>+Y]; sta <$03>
    
    
    sec
    lda <$00>; sbc $02; sta <$00>
    lda <$01>; sbc $00; sta <$01>
    lda <$02>; sbc $00; sta <$02>
    lda <$03>; sbc $00; sta <$03>
    
    ldx <f32_clustersize>
    stx <$04>
    __clusteroffset
        lsr <$04>; beq (end)
        clc
        rol <$00>
        rol <$01>
        rol <$02>
        rol <$03>
    bra (clusteroffset)
    ___end
        
    clc
    lda <$00>; adc <f32_data+0>; sta <$00>
    lda <$01>; adc <f32_data+1>; sta <$01>
    lda <$02>; adc <f32_data+2>; sta <$02>
    lda <$03>; adc <f32_data+3>; sta <$03>
    

    ldx $FF; stx [M_DUMMY]
    
    lda $00; sta <$04>
    lda $08; sta <$05>
    __copyloop
        jsr [sdsector]
        clc
        lda <$00>; adc 1; sta <$00>
        lda <$01>; adc 0; sta <$01>
        lda <$02>; adc 0; sta <$02>
        lda <$03>; adc 0; sta <$03>
        lda <$05>; inc A; sta <$05>
    cmp $80; bne (copyloop)
    
    nop; nop; nop; ldx [M_SD]
    
    jmp [$0800]

_sdcmd
    # SD INIT
    phy
    phx
    ldy 0; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    sta [M_SD]; inc Y; lda [<$00>+Y]
    
    ldy 9
    ldx $FF
    __sd_wait
        dec Y; beq (skip)
        stx [M_SD]; nop; nop; nop; lda [M_DUMMY]
    bmi (sd_wait)
    ___skip
    
    plx
    ply
    sta <$65>
rts

_sdsector
    # CMD17 - READ_SINGLE_BLOCK
    # zp 0, 1, 2 ,3  contain the sector to read
    # zp 4, 5        contain the location to copy the data
    lda $ff; sta [M_SD]; nop; nop
    lda $51
    sta [M_SD]; nop; nop; lda <$03>
    sta [M_SD]; nop; nop; lda <$02>
    sta [M_SD]; nop; nop; lda <$01>
    sta [M_SD]; nop; nop; lda <$00>
    sta [M_SD]; nop; nop; lda $01
    sta [M_SD]; nop; nop; ldx $FF
    
    ldy 0
    __waitblockstart
        lda [M_DUMMY]
        cmp $FE; beq (end)
        stx [M_SD]; nop; nop
        inc Y; beq (sdsector)
        bra (waitblockstart)
    ___end
    
    # Need to read 512 bytes.  Read two at a time, 256 times.
    ldy 0
    ldx $FF
    __readloop0
      stx [M_SD]; nop; nop; nop; lda [M_DUMMY];
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      sta [<$04>+Y]; inc Y
      bne (readloop0)
    inc <$05>
    ldy 0
    __readloop1
      stx [M_SD]; nop; nop; nop; lda [M_DUMMY]; 
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      stx [M_SD]; sta [<$04>+Y]; inc Y; lda [M_DUMMY]
      sta [<$04>+Y]; inc Y
      bne (readloop1)
    
    # Handle CRC and end of message
    stx [M_SD]; nop; nop; nop; nop
    stx [M_SD]; nop; nop; nop; nop
    lda [M_SD]; 
    stx [M_DUMMY]
rts

_sdcmd0
  .byte $40, $00, $00, $00, $00, $95
_sdcmd8
  .byte $48, $00, $00, $01, $aa, $87
_sdcmd55
  .byte $77, $00, $00, $00, $00, $01
_sdcmd41
  .byte $69, $40, $00, $00, $00, $01

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

_bootfile
.byte "RUN     65X",$20

_bankstr
.byte " banks"

.asm "lib.asm"

.pad [VECTORS]
.word ROM       # /nmi
.word ROM       # /reset
.word ROM       # brk and /irq