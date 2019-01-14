FUNC_SPI:
; SPI Function (Start - Send cmd - Exchange data - end)
; MSB send first
; Input:	A: Send data;
; Return:	A: Get data;
; Memory used:	R0, R1, R2, ACC
	
	
	func_spi_ini:
	SETB	SCLK				;Function ini
;	CLR	SS				;Enable transmission (SS)
	
	
	func_spi_byte:
	MOV	R0, #8
	MOV	R1, A
	MOV	R2, #0x00
	
	func_spi_loop:
	CLR	SCLK				;CLK falling_edge
	
	CLR	MOSI				;By default, send low
	MOV	A, R1
	RL	A
	MOV	R1, A				;Get next bit (MSB first)
	RR	A
	ANL	A, #0x80			;Check current MSB
	JZ	func_spi_loop_send_low		;Current bit is low (default), no need to set MOSI
	SETB	MOSI
	func_spi_loop_send_low:
	
	SETB	SCLK				;CLK rising_edge
	
	MOV	A, R2				;Shift receiver buffer
	RL	A
	MOV	R2, A
	JNB	MISO, func_spi_loop_get_low	;Check current input. If low, no need to set buffer
	INC	R2				;By default, this bit is 0. To set, inc 1.
	func_spi_loop_get_low:

	DJNZ	R0, func_spi_loop

	func_spi_end:
;	SETB	SS				;Disable SS
	MOV	A, R2				;Save receiver buffer
	RET
