.asm "vars.asm"
.org [$0800]
.var CTC_1 $8800
.var CTC_2 $8801
.var CTC_3 $8802
.var CTC_4 $8803
.var WAV_1 $8804
.var WAV_2 $8805
.var WAV_3 $8806
.var VOL   $8807
_main
    jsr [clrscreen]; nop; nop; nop
    lda 0; jsr [setcursor]
    
    
    lda [M_SD]
    ldx $FF; stx [M_A0]; nop; nop; nop
    

    lda %1110_0000
    sta [WAV_1]
    lda %1110_0000
    sta [WAV_2]
    lda %1110_0000
    sta [WAV_3]
    
    
    lda %0001_0101  ; sta [CTC_3]
    stz [CTC_3]
    
    lda %0001_0101  ; sta [CTC_1]
    lda [notes+0]   ; sta [CTC_1]
    
    lda %0001_0101  ; sta [CTC_2]
    lda [notes+4]   ; sta [CTC_2]
    
    lda %0001_0101  ; sta [CTC_3]
    lda [notes+7]   ; sta [CTC_3]
    
    lda %0011_0101  ; sta [CTC_4]
    stz [CTC_4]
    
    ldy $10
    __print_timer
        lda [CTC_4]
        sta <$00>
        
        lsr A; lsr A; lsr A; lsr A; 
        tax; lda [nibble_chars+X]
        jsr [charout]
        
        lda <$00>; and $0F
        tax; lda [nibble_chars+X]
        jsr [charout]
        
        dec Y
    bne (print_timer)
    
_loopi
    # beep off
    jsr [beep]
    
    ldy $00
    __longwait
        ldx $00
        ___wait
            dec X; nop; nop; nop; bzc (wait)
    dec Y; nop; nop; nop; bzc (longwait)
    
    
    bra (loopi)
    
    
.asm "lib.asm"

_notes
.byte 253, 239, 225, 213, 201, 190, 179, 169, 159, 150, 142, 134
.byte 127, 120, 113, 107, 100, 095, 090, 084, 080, 075, 071, 067

_nibble_chars
.byte '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'A', 'B', 'C', 'D', 'E', 'F' 
