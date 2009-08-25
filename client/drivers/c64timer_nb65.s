; timer routines
;
; the timer should be a 16-bit counter that's incremented by about
; 1000 units per second. it doesn't have to be particularly accurate.
; this C64 implementation requires the routine timer_vbl_handler be called 60 times per second
; this is for use in the NB65 ROM, where we also install an IRQ handler
; for normal userland programs where it is known what else is going on with the timer ,
; use "c64timer.s" routines instead

	.include "../inc/common.i"


	.export timer_init
	.export timer_read
  .export timer_vbl_handler
  
	
  .bss
  current_time_value: .res 2
  
	.code

;reset timer to 0
;inputs: none
;outputs: none
timer_init:
  ldax  #0
  stax current_time_value
	rts

;read the current timer value 
; inputs: none
; outputs: AX = current timer value (roughly equal to number of milliseconds since the last call to 'timer_init')
timer_read:
  ldax  current_time_value
  rts

; tick over the current timer value - should be called 60 times per second
; inputs: none
; outputs: none (all registers preserved, by carry flag can be modified)
timer_vbl_handler:
  pha
  lda $02A6   ;PAL/NTSC flag (0 = NTSC, 1 = PAL), 
  beq @was_ntsc  
  lda #$14  ;PAL = 50 HZ =~ 20 ms per 'tick'
  bne :+
@was_ntsc:  
  lda #$11  ;NTSC = 60 HZ =~ 17 ms per 'tick' 
: 
  adc current_time_value
  sta current_time_value
  bcc :+
  inc current_time_value+1
:
  pla
  rts