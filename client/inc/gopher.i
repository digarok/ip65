; C64 gopher browser
; july 2009 - jonno @ jamtronix.com
; this contains the key gopher rendering routines
; to use:
; 1) include this file 
; 2) include these other files:
;  .include "../inc/common.i"
;  .include "../inc/commonprint.i"
;  .include "../inc/net.i"
;  .include "../inc/char_conv.i"
;  .include "../inc/c64keycodes.i"
; 3) define a routine called 'exit_gopher'

;  .import get_key
  .import get_key_if_available
  .import mul_8_16
  .importzp acc16
  .importzp copy_src
  .importzp copy_dest
  .import copymem

  .import tcp_connect
  .import tcp_send
  .import tcp_send_data_len
  .import tcp_callback
  .import tcp_connect_ip
  .import tcp_inbound_data_length
  .import tcp_inbound_data_ptr
  .import dns_ip
  .import dns_resolve
  .import dns_set_hostname
  .import ip65_error
  .import cls
  .import get_filtered_input
  .import filter_dns
  .import filter_text

.segment "IP65ZP" : zeropage

; pointer for moving through buffers
buffer_ptr:	.res 2			; source pointer
  
.data
get_next_byte:
  lda $ffff
  inc get_next_byte+1
  bne :+
  inc get_next_byte+2
:  
  rts


current_resource_history_entry: .byte 0

.segment "APP_SCRATCH" 

DISPLAY_LINES=22
page_counter: .res 1
MAX_PAGES = 50
page_pointer_lo: .res MAX_PAGES
page_pointer_hi: .res MAX_PAGES

resource_counter: .res 1
MAX_RESOURCES = DISPLAY_LINES

resource_pointer_lo: .res MAX_RESOURCES
resource_pointer_hi: .res MAX_RESOURCES
resource_type: .res MAX_RESOURCES

download_flag: .res 1
dl_loop_counter: .res 2
this_is_last_page: .res 1

tcp_buffer_ptr: .res 2
temp_ax: .res 2

RESOURCE_HOSTNAME_MAX_LENGTH=64
current_resource:
resource_hostname: .res RESOURCE_HOSTNAME_MAX_LENGTH
resource_port: .res 2
resource_selector: .res 128
resource_selector_length: .res 1
displayed_resource_type: .res 1
query_string: .res 32
query_string_length: .res 1

RESOURCE_HISTORY_ENTRIES=8
resource_history:
.res $100*RESOURCE_HISTORY_ENTRIES

scratch_buffer:
  .res 16000
  
.code

;display whatever is in the buffer either as plain text or gopher text

display_resource_in_buffer:
  ldax #scratch_buffer
  stax  get_next_byte+1
  
  lda #0
  sta page_counter
 
@do_one_page:  
  jsr cls

;  ldax  #page_header
;  jsr print
;  lda page_counter
;  jsr print_hex
  
;  jsr print_resource_description
  ldx page_counter
  lda get_next_byte+1
  sta page_pointer_lo,x
  lda get_next_byte+2
  sta page_pointer_hi,x
  inc page_counter
  
  
  lda displayed_resource_type
  cmp #'0'
  bne @displayed_resource_is_directory

;if this is a text file, just convert ascii->petscii and print to screen
@show_one_char:
  jsr get_next_byte
  tax ;this both sets up X as index into ascii_to_petscii_table, and sets Z flag   
  bne :+
  lda #1
  sta this_is_last_page
  jmp @get_keypress
:  
  
  lda ascii_to_petscii_table,x
  jsr print_a
  lda $d6
  cmp #DISPLAY_LINES
  bmi @show_one_char
  jmp @end_of_current_page

@displayed_resource_is_directory:

  lda #0
  sta resource_counter
  
@next_line:
  jsr get_next_byte
  cmp #0
  beq @last_line
  cmp #'.'
  bne @not_last_line
@last_line:  
  lda #1
  sta this_is_last_page
  jmp @done
@not_last_line:  
  cmp #'i'
  beq @info_line
  cmp #'0'
  beq @standard_resource
  cmp #'1'
  beq @standard_resource
  cmp #'7'
  beq @standard_resource

  ;if we got here, we know not what it is  
  jmp @skip_to_end_of_line  
@standard_resource:  
  pha
  ldx resource_counter
  sta resource_type,x
  sec  
  lda get_next_byte+1
  sbc #1  ;since "get_next_byte" did the inc, we need to backtrack 1 byte
  sta resource_pointer_lo,x
  lda get_next_byte+2
  sbc #0  ;in case there was an overflow on the low byte
  sta resource_pointer_hi,x
  inc resource_counter
  
  lda $d3 ;are we at the start of the current line?
  beq :+
  jsr print_cr
:  
  pla ;get back the resource type
;  cmp #'1'
;  beq @resource_is_a_dir
;  lda #'-'
;  jmp @print_resource_indicator
;@resource_is_a_dir: 
;  lda #'+'
;@print_resource_indicator:
;  jsr print_a
  lda #18 ;inverse mode on 
  jsr print_a
  lda resource_counter
  clc
  adc #'a'-1
  jsr print_a
  lda #146 ;inverse mode off
  jsr print_a
  lda #' '
  jsr print_a

@info_line:  
@print_until_tab:
@next_byte:
  jsr get_next_byte
  cmp #$09
  beq @skip_to_end_of_line
  tax
  lda ascii_to_petscii_table,x
  jsr print_a
  jmp @next_byte
  
@skip_to_end_of_line:
  jsr get_next_byte
  cmp #$0A
  bne @skip_to_end_of_line


  lda $d3
  cmp #0
  beq :+
  jsr print_cr
:  
  lda $d6
  cmp #DISPLAY_LINES
  bpl @end_of_current_page
  jmp @next_line

@end_of_current_page:
  lda #0
  sta this_is_last_page
@done:
@get_keypress:
  jsr ip65_process  ;keep polling the network, so we respond to arps/pings/late packets etc etc
  jsr get_key_if_available
  cmp #' '
  beq @go_next_page  
  cmp #KEYCODE_F7
  beq @go_next_page
  cmp #KEYCODE_DOWN
  beq @go_next_page
  cmp #KEYCODE_F1
  beq @go_prev_page
  cmp #KEYCODE_UP
  beq @go_prev_page
  cmp #KEYCODE_F2
  beq @show_history
  cmp #KEYCODE_LEFT
  beq @back_in_history
  cmp #KEYCODE_F3
  beq @back_in_history
  cmp #KEYCODE_F5
  beq @prompt_for_new_server

  cmp #KEYCODE_ABORT  
  beq @quit
  ;if fallen through we don't know what the keypress means, go get another one
  and #$7f  ;turn off the high bit 
  sec
  sbc #$40
  bmi @not_a_resource
  cmp resource_counter
  beq @valid_resource
  bcs @not_a_resource  
@valid_resource:  
  tax
  dex
  jsr select_resource_from_current_directory
@not_a_resource:  
  jmp @get_keypress  
@back_in_history:
  ldx current_resource_history_entry
  dex 
  beq @get_keypress ;if we were already at start of history, can't go back any further
  stx current_resource_history_entry
  txa
  jsr load_resource_from_history
  jsr load_resource_into_buffer
  jmp display_resource_in_buffer  
@show_history:
  jsr show_history
  jmp display_resource_in_buffer
@go_next_page:  
  lda this_is_last_page
  bne @get_keypress
  jmp @do_one_page
@prompt_for_new_server:
  jsr prompt_for_gopher_resource ;that routine only returns if no server was entered.
  jmp display_resource_in_buffer  

@quit:
  jmp exit_gopher
@go_prev_page:  
  ldx page_counter  
  dex  
  bne @not_first_page
  jmp @get_keypress
@not_first_page:  
  dex
  dec page_counter
  dec page_counter
  
  lda page_pointer_lo,x  
  sta get_next_byte+1
  lda page_pointer_hi,x
  sta get_next_byte+2
  jmp @do_one_page

;get a gopher resource 
;X should be the selected resource number
;the resources selected should be loaded into resource_pointer_* 
select_resource_from_current_directory:
  lda resource_pointer_lo,x
  sta buffer_ptr
  lda resource_pointer_hi,x
  sta buffer_ptr+1
  ldy #0  
  ldx #0
  
  lda (buffer_ptr),y
  sta displayed_resource_type
  
@skip_to_next_tab:  
  iny
  beq @done_skipping_over_tab 
  lda (buffer_ptr),y
  cmp #$09
  bne @skip_to_next_tab
@done_skipping_over_tab:  

;should now be pointing at the tab just before the selector
@copy_selector:
  iny 
  lda (buffer_ptr),y
  cmp #09
  beq @end_of_selector
  sta resource_selector,x
  inx
  jmp @copy_selector
@end_of_selector:  
  lda  #$00
  sta resource_selector,x
  stx resource_selector_length
  tax
;should now be pointing at the tab just before the hostname
@copy_hostname:
  iny 
  lda (buffer_ptr),y
  cmp #09
  beq @end_of_hostname
  sta resource_hostname,x
  inx
  jmp @copy_hostname

@end_of_hostname:  
  lda  #$00
  sta resource_hostname,x

;should now be pointing at the tab just before the port number
  lda #0
  sta resource_port
  sta resource_port+1
@parse_port:  
  iny  
  beq @end_of_port
  lda (buffer_ptr),y
  cmp #$1F
  bcc @end_of_port  ;any control char should be treated as end of port field
  
  ldax  resource_port
  stax  acc16
  lda #10
  jsr mul_8_16
  ldax  acc16
  stax  resource_port
  lda (buffer_ptr),y
  sec
  sbc #'0'
  clc
  adc resource_port
  sta resource_port
  bcc :+  
  inc resource_port+1
:  
  jmp @parse_port  
@end_of_port:  

  lda displayed_resource_type
  
  cmp #'7'  ;is it a 'search' resource?
  bne @done
  
  ldax #query  
  jsr print
@get_query_string:  
  ldy #32 ;max chars
  ldax #filter_text
  jsr get_filtered_input
  bcs @get_query_string
  stax  buffer_ptr
  jsr print_cr
  ldy #0
  sty query_string_length
  lda  #09
@copy_one_char:
  sta query_string,y
  inc query_string_length
  lda (buffer_ptr),y
  beq @done_query_string
  iny
  jmp @copy_one_char
@done_query_string:  
@done:

add_resource_to_history_and_display:
  ;add this to the resource history
  lda current_resource_history_entry
  cmp #RESOURCE_HISTORY_ENTRIES
  bne @dont_shuffle_down  
  ldax  #resource_history
  stax  copy_dest
  inx   ;one page higher up
  stax  copy_src
  ldx #(RESOURCE_HISTORY_ENTRIES-1)
  lda #$00
  jsr copymem
  dec current_resource_history_entry

@dont_shuffle_down:  
  ldax  #current_resource
  stax copy_src
  lda  #<resource_history
  sta  copy_dest
  clc
  lda  #>resource_history
  adc current_resource_history_entry
  sta copy_dest+1
  ldax #$100
  jsr copymem
  
  inc current_resource_history_entry  
  
  jsr load_resource_into_buffer
  bcs @error_in_loading
  jmp display_resource_in_buffer
@error_in_loading:
  ldax  #error
  jsr print
  lda ip65_error
  jsr print_hex
  jsr print_cr
  jsr get_key
  rts
    

;show the entries in the history buffer
show_history:
  
  jsr cls
  ldax #history
  jsr print
  
  lda current_resource_history_entry
@show_one_entry:
  pha
  jsr load_resource_from_history
  jsr print_resource_description
  pla
  sec
  sbc #1
  bne @show_one_entry
  jsr print_cr
  ldax #any_key_to_continue
  jsr print
  jsr get_key
  rts
  

;load the 'current_resource' into the buffer
load_resource_into_buffer:
  ldax #scratch_buffer
  stax tcp_buffer_ptr
  ldax  #resolving
  jsr print
  ldax #resource_hostname
  jsr print
  jsr print_cr
  ldax #resource_hostname
  jsr dns_set_hostname
  
  bcs :+    
  jsr dns_resolve
:  
  bcc @no_error
  jmp @error
@no_error:  
  ldx #3        ; save IP address just retrieved
: lda dns_ip,x
  sta tcp_connect_ip,x
  dex
  bpl :-
  ldax #gopher_download_callback
  stax tcp_callback
  ldax  #connecting
  jsr print

  ldax resource_port
  jsr tcp_connect
  bcs @error
  
  ;connected, now send the selector
  jsr print_cr
  ldax  #retrieving
  jsr print
  ldax #resource_selector
  jsr print
  jsr print_cr
  ldx #0
  stx download_flag
  stx dl_loop_counter
  stx dl_loop_counter+1
  lda resource_selector_length
  stax tcp_send_data_len
  ldax #resource_selector
  jsr tcp_send
  
  
  ;send the tab and query string (if supplied)
  lda displayed_resource_type  
  cmp #'7'  ;is it a 'search' resource?
  bne @send_cr_lf
  ldax query_string_length
  sta tcp_send_data_len
  ldax #query_string
  jsr tcp_send

@send_cr_lf:
  ;send the CR/LF after the connector
  ldax #2
  sta tcp_send_data_len
  ldax #cr_lf
  jsr tcp_send
  
  ;now loop until we're done
@download_loop:
  inc dl_loop_counter
  bne :+
  inc dl_loop_counter+1
  bne :+

  lda #'.'
  jsr print_a
:  
  jsr ip65_process
  lda download_flag
  beq @download_loop
  clc
  
@error:
  rts
  
gopher_download_callback:
  lda tcp_inbound_data_length
  cmp #$ff
  bne @not_end_of_file
  lda #1
  sta download_flag
  
  ;put a zero byte at the end of the file (in case it was a text file)
  ldax tcp_buffer_ptr  
  stax copy_dest
  lda #0  
  tay
  sta (copy_dest),y
  
  rts
@not_end_of_file:

;copy this chunk to our input buffer
  ldax tcp_buffer_ptr  
  stax copy_dest
  ldax tcp_inbound_data_ptr
  stax copy_src
  ldax tcp_inbound_data_length
  jsr  copymem  
;increment the pointer into the input buffer  
  clc
  lda tcp_buffer_ptr
  adc tcp_inbound_data_length
  sta tcp_buffer_ptr
  lda tcp_buffer_ptr+1
  adc tcp_inbound_data_length+1
  sta tcp_buffer_ptr+1  
  lda #'*'
  jsr print_a
  
  
  rts


;retrieve entry specified by A from resource history
;NB 'A' = 1 means the first entry
load_resource_from_history:
  clc
  adc  #(>resource_history)-1
  sta copy_src+1
  lda  #<resource_history
  sta  copy_src

  ldax  #current_resource
  stax copy_dest
  ldax #$100
  jsr copymem

  rts

print_resource_description:
;  ldax #port_no
;  jsr print
;  lda resource_port+1
;  jsr print_hex
;  lda resource_port  
;  jsr print_hex  
;  jsr print_cr
 
  ldax #server
  jsr print
  ldax #resource_hostname
  
  jsr print
  jsr print_cr
  ldax #selector
  jsr print
  ldax #resource_selector
  jsr print  
  jsr print_cr
  rts


prompt_for_gopher_resource:
  ldax #gopher_server
  jsr print
  ldy #40
  ldax #filter_dns
  jsr get_filtered_input
  bcs @no_server_entered
  stax copy_src
  ldax #resource_hostname
  stax copy_dest
  ldax #RESOURCE_HOSTNAME_MAX_LENGTH
  jsr copymem
  ldax #70
  stax resource_port
  lda  #'/'
  sta resource_selector
  lda #0
  sta resource_selector+1
  sta resource_selector_length+1
  lda #1
  sta resource_selector_length
  lda #'1'  
  sta displayed_resource_type
  jsr print_cr
  jmp add_resource_to_history_and_display
@no_server_entered:
  sec
  rts
.rodata
page_header:
.byte "PAGE NO $",0
port_no:
.byte "PORT NO ",0
history:
.byte "GOPHER HISTORY ",13,0
cr_lf: .byte $0D,$0A
error:
.byte "ERROR - CODE ",0
connecting:
.byte "CONNECTING ",0
retrieving:
.byte "RETRIEVING ",0
gopher_server:
.byte "GOPHER "
server:
.byte "SERVER :",0
selector:
.byte "SELECTOR :",0
query:
.byte "QUERY :",0

any_key_to_continue:
.byte "PRESS ANY KEY TO CONTINUE",0


