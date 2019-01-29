; Software SPI slave updating P0, P1, P3
; MSB first
; P2 first, then P1, then P0
; Sample at SCLK rising edge (SPI mode3)

;SFR - STC89C52RC
	XICON		EQU	0xC0
	T2CON		EQU	0xC8
	T2MOD		EQU	0xC9
	RCAP2L		EQU	0xCA
	RCAP2H		EQU	0xCB
	TL2		EQU	0xCC
	TH2		EQU	0xCD
	WDT_CONTR	EQU	0xE1
	ISP_DATA	EQU	0xE2
	ISP_ADDRH	EQU	0xE3
	ISP_ADDRL	EQU	0xE4
	ISP_CMD		EQU	0xE5
	ISP_TRIG	EQU	0xE6
	ISP_CONTR	EQU	0xE7
	P4		EQU	0xE8
	
	ET2		EQU	IE.5
	TF2		EQU	T2CON.7
	EXF2		EQU	T2CON.6
	RCLK		EQU	T2CON.5
	TCLK		EQU	T2CON.4
	EXEN2		EQU	T2CON.3
	TR2		EQU	T2CON.2
	C_T2		EQU	T2CON.1
	CP_RL2		EQU	T2CON.0

;App config
	DATALENGTH	EQU	24
	DATALENGTH_MAX	EQU	24

	SCLK		EQU	P3.2
	SS		EQU	P3.3
	SDI		EQU	P3.4
	SDO		EQU	P3.5
		
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
	
;Interrupt vector map
ORG	0x0000
	JMP	INI
ORG	0x0003
	JMP	INT_0
ORG	0x000B
	JMP	TIMER_0
ORG	0x0013
	JMP	INT_1
ORG	0x001B
	JMP	TIMER_1
ORG	0x0023
	JMP	UART
ORG	0x002B
	JMP	TIMER_2

; MAIN CODE --------------------------------------------

INI:							;Boot setup
	MOV	SP, #0x7F
	
	MOV	P0, #0x00				;All output pins set to low (MOSFET turned off)
	MOV	P1, #0x00
	MOV	P2, #0x00
	MOV	P3, #0xFF				;Communication/Control IO pull high
	
	SETB	EX1					;Enable INT1 (P3.3, SS), on falling trigger
;	SETB	IT1
	SETB	PX1					;Pirority
		
	MOV	SCON, #0x40				;UART mode1 (8-bit, flex baud), disable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	
	SETB	EA

IDEL:							;Wait for command
	MOV	PCON, #0x20				;Chip powerdown
	JMP	$					;Busy wait until power down. Power-up by interrupt, PC will be moved to next line in the interrupt
;	JB	SS, $;;;;;;;;;;;;
;	CALL	INT_1
	JMP	IDEL
	
	

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	RETI

INT_1:							;Chip selected (for faster response, using busy wait without subroutine)
	
	; When receive data, XRAM (external RAM, logic external, physical internal) address 0x01-DATALENGTH will be write to 1 or 0
	; Each XRAM slot will reperents the corresponding SPI bit. For example: SPI = (MSB)10001110(LSB), then
	; XRAM[8] = 0x01, XRAM[7] = 0x00, XRAM[6] = 0x00, XRAM[5] = 0x00, XRAM[4] = 0x01, XRAM[3] = 0x01, XRAM[2] = 0x01, XRAM[1] = 0x00
	
	receive_ini:
	MOV	R0, #DATALENGTH				;Ini, bit counter
	
	receive_bit_ini:
	CLR	A
	
	receive_bit_waitrise:
	JB	SS, spi_end				;SS unselected, go to end
	JNB	SCLK, receive_bit_waitrise		;Wait for SCLK rising
	
	receive_bit_sample:
	JNB	SDI, receive_bit_low			;If receive low, do nothing; if high, write high
	MOV	A, 0x01
	receive_bit_low:
	MOVX	@R0, A					;Save current bit in XRAM
	
	receive_bit_waitfall:
	JB	SS, spi_end
	JB	SCLK, receive_bit_waitfall
	
	DJNZ	R0, receive_bit_ini			;Receive all bits
	
	MOV	R0, #DATALENGTH_MAX
	debug_scan:
	MOVX	A, @R0
	MOV	SBUF, A
;	PUSH	ACC
;	POP	SBUF
	JNB	TI, $
	CLR	TI
	DJNZ	R0, debug_scan
	
	process_ini:
	MOV	R0, #DATALENGTH_MAX			;Assume DATALENGTH is the MAX (3 bytes)
	
	process_byte2:
	MOV	R1, #8
	CLR	A
	process_bit2:
	RL	A
	MOVX	A, @R0
	ADD	A, R2
	MOV	R2, A
	DJNZ	R1, process_bit2
	MOV	P2, A
	
	process_byte1:
	MOV	R1, #8
	CLR	A
	process_bit1:
	RL	A
	MOVX	A, @R0
	ADD	A, R2
	MOV	R2, A
	DJNZ	R1, process_bit1
	MOV	P1, A
	
	process_byte0:
	MOV	R1, #8
	CLR	A
	process_bit0:
	RL	A
	MOVX	A, @R0
	ADD	A, R2
	MOV	R2, A
	DJNZ	R1, process_bit0
	MOV	P2, A
	
	spi_end:
	POP	B					;Modify return address to skip JMP$
	POP	ACC
	ADD	A, #0x02
	PUSH	ACC
	MOV	A, B
	ADDC	A, #0x00
	PUSH	ACC
	
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:
;	CLR	TI
	CLR	RI
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; INTERNAL FUNCTIONS -----------------------------------


; EXTERNAL FUNCTIONS -----------------------------------


; CONSTANT DATA TABLES ---------------------------------



END;
