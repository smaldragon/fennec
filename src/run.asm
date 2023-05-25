.asm "vars.asm"
.org [$0800]
_main
    # beep off
    jsr [beep]
    
    ldy $00
    __longwait
        ldx $00
        ___wait
            dec X; nop; nop; nop; bzc (wait)
    dec Y; nop; nop; nop; bzc (longwait)
    
    
    bra (main)
    
.asm "lib.asm"