; Software SPI slave updating P0, P1, P3
; MSB first
; P2 first, then P1, then P0
; Sample at SCLK rising edge (SPI mode0)

; Pin layout:
; P0, P1, P3: digital output
; P3.0, P3.1: debug use (UART @ 2400)
; P3.2: SCLK
; P3.3: /SS
; P3.4: SDI (MOSI)
; P3.5: SDO (MISO), not used
; P3.6: Idel indicator (active high)
; P3.7: Not used

; Debug interface:
; Baud = 2400 @ 12MHz

#define DEBUG 0

;SFR - STC89C52RC
	XICON		DATA	0xC0
	T2CON		DATA	0xC8
	T2MOD		DATA	0xC9
	RCAP2L		DATA	0xCA
	RCAP2H		DATA	0xCB
	TL2		DATA	0xCC
	TH2		DATA	0xCD
	WDT_CONTR	DATA	0xE1
	ISP_DATA	DATA	0xE2
	ISP_ADDRH	DATA	0xE3
	ISP_ADDRL	DATA	0xE4
	ISP_CMD		DATA	0xE5
	ISP_TRIG	DATA	0xE6
	ISP_CONTR	DATA	0xE7
	P4		DATA	0xE8
	
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
	ISIDEL		EQU	P3.6
		
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
	
;App RAM
	BUFFER_HEAD	DATA	0x48			;Not used
	BUFFER_P27	DATA	0x47
		;
		;
		;
	BUFFER_P20	DATA	0x40
	BUFFER_P10	DATA	0x38
	BUFFER_P00	DATA	0x30
	
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
	
	SETB	EX1					;Enable INT1 (P3.3, SS), on falling trigger, high pirority
	SETB	IT1
	SETB	PX1
		
	MOV	SCON, #0x40				;UART mode1 (8-bit, flex baud), disable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 to 16-bit normal
	SETB	TR1					;Enable timer1 running
	SETB	ET0					;Enable timer0 interrupt
	
	SETB	EA

IDEL:							;Wait for command
	CLR	ISIDEL					;Set flag
	MOV	PCON, #0x20				;Chip powerdown
	JB	ISIDEL, $				;Busy wait until power down. Power-up by interrupt, flag will be clear in the interrupt
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
	MOV	R0, #BUFFER_HEAD			;Ini buffer pointer
	
	receive_bit_ini:
	DEC	R0
	
	receive_bit_waitrise:
	JB	SS, spi_end				;SS unselected, go to end
	JNB	SCLK, receive_bit_waitrise		;Wait for SCLK rising
	
	receive_bit_sample:
	JNB	SDI, receive_bit_low			;If receive low, write 0; if high, write 1
	MOV	@R0, #0x01
	JMP	receive_bit_waitfall
	receive_bit_low:
	MOV	@R0, #0x00
	
	receive_bit_waitfall:
	JB	SS, spi_end
	JB	SCLK, receive_bit_waitfall
	
	CJNE	R0, #BUFFER_P00, receive_bit_ini	;Receive all bits
	
	#if (DEBUG != 0)
	MOV	R0, #BUFFER_HEAD			;This will show all the intermedia data saved in the SPI buffer
	debug_scan:
	DEC	R0
	MOV	SBUF, @R0
	JNB	TI, $
	CLR	TI
	CJNE	R0, #BUFFER_P00, debug_scan
	#endif
	
	process_ini:
	MOV	R0, #DATALENGTH_MAX			;Assume DATALENGTH is the MAX (3 bytes)
	
	CLR	A					;Clear ACC (output buffer)
	process_byte2:
	DEC	R0					;Get next bit in SPI buffer
	RL	A					;Next next bit in output buffer
	ADD	A, @R0					;Move current bit from SPI buffer to output buffer (+1 = set, +0 = keep low)
	CJNE	R0, #BUFFER_P20, process_byte2		;Finish this byte, move output buffer to IO
	MOV	P2, A
	
	CLR	A
	process_byte1:
	DEC	R0
	RL	A
	ADD	A, @R0
	CJNE	R0, #BUFFER_P10, process_byte1
	MOV	P1, A
	
	CLR	A
	process_byte0:
	DEC	R0
	RL	A
	ADD	A, @R0
	CJNE	R0, #BUFFER_P00, process_byte0
	MOV	P0, A
	
	spi_end:
	SETB	ISIDEL					;Clear carry (this is a flag, see main routine)
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:
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
