FUNC_UART_SEND_RAW:
; UART Function, send the value stored in ACC, in raw binary format
; Input:	ACC: The value
; Output:	void
; Memory used:	ACC, SBUF
	MOV	SBUF, A
	JMP	$
	RET
	;It is recommanded to write this block in the parent function, instead of call this function

FUNC_UART_SEND_STRING:
; UART Function, send a string
; Input:	DPTR: String pointer
; Output:	void
; Memory used:	ACC, DPTR
	CLR	A
	MOVC	A, @A+DPTR				;Get current char
	JZ	func_uart_send_string_end		;Break loop if string end (\0).
	MOV	SBUF, A
	INC	DPTR					;Pointer++
	JMP	$					;This is a WAI instruction, see UART.
	JMP	FUNC_UART_SEND_STRING
	func_uart_send_string_end:
	RET

FUNC_UART_SEND_CHAR:
; UART Function, send the decimal value stored in ACC, in ascii
; Input:	ACC: The value
; Output:	void
; Memory used:	ACC, B, SBUF
	MOV	B, #100
	DIV	AB					;Get x00
	PUSH	B					;Reminder is 0xx
	ADD	A, #0x30				;Get ASCII, Dec 0~9 = ASCII 0x30~0x39
	MOV	SBUF, A					;Send, this will take a while. Calculate next char before WAIT(JMP$)
	
	POP	ACC					;Get 0xx
	MOV	B, #10
	DIV	AB					;Get 0x0
	PUSH	B
	ADD	A, #0x30				;Get ASCII
	PUSH	ACC
	JMP	$					;Wait x00 to be send (sending one char takes more than 1000 cycles)
	POP	SBUF					;Send 0x0
	
	POP	ACC					;get 00x
	ADD	A, #0x30
	PUSH	ACC
	JMP	$					;Wait 0x0 to be finish
	POP	SBUF					;Send 00x
	JMP	$					;Wait 00x finish
	
	RET

FUNC_UART_SEND_HEXCHAR:
; UART Function, send the hexdecimal value stored in ACC, in ascii
; Input:	ACC: The value
; Output:	void
; Memory used:	ACC, SBUF
	PUSH	ACC
	ANL	A, #0xF0				;Get high nibble
	SWAP	A
	
	ADD	A, #0xF6					;Check 0-9 of A-F, if A-F, C bit will be set
	JNB	CY, func_uart_send_hexchar_09h
	ADD	A, #0x07					;ASCII(A) - ASCII(9) = 7. This ADD will be executed if A-F
	func_uart_send_hexchar_09h:
	ADD	A, #0x3A				;Deal with the ADD 0xF6 test and 0x30 ASCII offset
	
	MOV	SBUF, A					;Send high nibble
	
	POP	ACC
	ANL	A, #0x0F				;Get low nibble
	
	ADD	A, #0xF6					;Check 0-9 of A-F and get ASCII
	JNB	CY, func_uart_send_hexchar_09l
	ADD	A, #0x07
	func_uart_send_hexchar_09l:
	ADD	A, #0x3A
	PUSH	ACC
	
	JMP	$					;Wait for last UART transfer
	POP	SBUF					;Send low nibble
	JMP	$					;Wait send finish
	
	RET

FUNC_UART_INT:
; UART interrupthandler
; Notice: this interrupt subroutine will modify return PC. JMP $ is now equivalent to WAI.
; Memory used:	ACC, B, SBUF, _RI, _TI
	
	JB	RI, func_uart_int_rx			;Check interrupt source
	
	func_uart_int_tx:
	CLR	TI
	JMP	func_uart_int_common
	
	func_uart_int_rx:
	CLR	RI
	
	func_uart_int_common:
	
	POP	B					;;Return address + 2 (JMP $ --> WAI)
	POP	ACC
	ADD	A, #0x02
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI
