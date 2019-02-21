; Operator console

; CONFIG FILES -----------------------------------
$INCLUDE	(c_sfr.a51)
$INCLUDE	(c_cfg.a51)
$INCLUDE	(c_ram.a51)
	
	
; INTERRUPT VECTOR MAP -----------------------------------
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


; EXTERNAL FUNCTIONS -----------------------------------

$INCLUDE	(f_delay.a51)
$INCLUDE	(f_lcd.a51)

; INTERNAL FUNCTIONS -----------------------------------

DIGITAL_INPUT:						;User enter a digital to AutoPilot console
	MOV	DIGI_BUFFER_E, DIGI_BUFFER_H		;Data shift left, Data Low = input
	MOV	DIGI_BUFFER_H, DIGI_BUFFER_L
	MOV	DIGI_BUFFER_L, A
	RET

DIGITAL_APPLY:						;User apply a value to AutoPilot console
	
	RET
	

; MAIN CODE --------------------------------------------

INI:							;Boot setup
	USING	0					;USING REGISTER BANK 0 ALWAYS!!!
	MOV	SP, #0x7F
	
	__M_LCD_PREPARE
	
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x20				;Set Timer1 mode to auto-reload
	SETB	TR1					;Enable timer1
	
	SETB	EA
	
MAIN:							;Main cycle: execute while receive synch signal
	CLR	LED_IDEL
	
SCAN:							;Scan keyboard
	MOV	KEY_SCAN, #0xFF
	
	MOV	KEY_DRIVE, #0x7F			;Scan row 7: LightL - LightC - LightR - Navi - X - XForward - Forward - Backward
	NOP
	MOV	A, KEY_SCAN
	CPL	A					;All keys are active low
	MOV	FB_VALVE, A				;Get X - XForward - Forward - Backward
	ANL	FB_VALVE, #0x07
	SWAP	A
	MOV	LED, A					;Get LightL - LightC - LightR - Navi
	ANL	LED, #0x0F
	
	MOV	KEY_DRIVE, #0xBF			;Scan row 6: Compass - PCompass - TurnLeft - TurnRight - X - X - ShiftLeft - ShiftRight
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	ANL	A, #0xF3
	JNB	ACC.7, scan_6_end			;If AP Compass, remove turn command
	CLR	ACC.5
	CLR	ACC.4
	scan_6_end:
	MOV	LR_VALVE, A
	
	MOV	KEY_DRIVE, #0xDF			;Scan row 5: Pitch - PPitch - PitchUp - PitchDown - Press - PPress - Up - Down
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	JNB	ACC.7, scan_5_pitchend			;If AP Pitch, remove pitch command
	CLR	ACC.5
	CLR	ACC.4
	scan_5_pitchend:
	JNB	ACC.3, scan_5_pressend			;If AP Pressure, remove pressure command
	CLR	ACC.1
	CLR	ACC.0
	scan_5_pressend:
	MOV	UD_VALVE, A
	
	MOV	KEY_DRIVE, #0xEF			;Scan row 4: Custom output
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	MOV	C_OUT, A
	
	MOV	KEY_DRIVE, #0xF7			;Scan row 3: Digital input high/apply
	NOP
	scan_3_pitch:
	JB	KEY_SCAN.7, scan_3_compass
	MOV	A, #PITCH_DEST
	CALL	DIGITAL_APPLY
	JMP	scan_2_end
	scan_3_compass:
	JB	KEY_SCAN.6, scan_3_pressure
	MOV	A, #COMPASS_DEST
	CALL	DIGITAL_APPLY
	JMP	scan_2_end
	scan_3_pressure:
	JB	KEY_SCAN.5, scan_3_cpwm
	MOV	A, #PRESSURE_DEST
	CALL	DIGITAL_APPLY
	JMP	scan_2_end
	scan_3_cpwm:
	JB	KEY_SCAN.4, scan_3_9
	MOV	A, #C_PWM
	CALL	DIGITAL_APPLY
	JMP	scan_2_end
	scan_3_9:
	JB	KEY_SCAN.1, scan_3_8
	MOV	A, #9
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_3_8:
	JB	KEY_SCAN.0, scan_3_end
	MOV	A, #8
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_3_end:
	
	MOV	KEY_DRIVE, #0xFB			;Scan row 2: Digital input low
	NOP
	scan_2_7:
	JB	KEY_SCAN.1, scan_2_6
	MOV	A, #7
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_6:
	JB	KEY_SCAN.1, scan_2_5
	MOV	A, #6
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_5:
	JB	KEY_SCAN.1, scan_2_4
	MOV	A, #5
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_4:
	JB	KEY_SCAN.1, scan_2_3
	MOV	A, #4
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_3:
	JB	KEY_SCAN.1, scan_2_2
	MOV	A, #3
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_2:
	JB	KEY_SCAN.1, scan_2_1
	MOV	A, #2
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_1:
	JB	KEY_SCAN.1, scan_2_0
	MOV	A, #1
	CALL	DIGITAL_INPUT
	JMP	scan_2_end
	scan_2_0:
	JB	KEY_SCAN.0, scan_2_end
	MOV	A, #0
	CALL	DIGITAL_INPUT
	scan_2_end:
	
COMMAND_UI:						;Update command data to LCD0

	;Test
	MOV	C_PWM, #0x29				;C_PWM = 100%
	MOV	PITCH_DEST, #0x29			;PITCH_DEST = 296 (64 down)
	MOV	PITCH_DEST+1, #0x60
	MOV	COMPASS_DEST, #0x13			;COMPASS_DEST = 135
	MOV	COMPASS_DEST+1, #0x50
	MOV	PRESSURE_DEST, #0x24			;PRESSURE_DEST = 24.55m
	MOV	PRESSURE_DEST+1, #0x55
	MOV	DIGI_BUFFER_E, #0x01			;DIGI_BUFFER = 123
	MOV	DIGI_BUFFER_H, #0x02
	MOV	DIGI_BUFFER_L, #0x03
	;End of test


	__M_LCD0_SETCURSOR	0,0
	
	MOV	A, PITCH_DEST				;PITCH_DEST 100
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, PITCH_DEST				;PITCH_DEST 10
	ANL	A, #0x0F
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, PITCH_DEST+1				;PITCH_DEST 1
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	__M_LCD0_SETDATA	#'P'			;PITCH_DEST P
	__M_LCD0_SETDATA	#' '			;Space
	
	MOV	A, COMPASS_DEST				;COMPASS_DEST 100
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, COMPASS_DEST				;COMPASS_DEST 10
	ANL	A, #0x0F
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, COMPASS_DEST+1			;COMPASS_DEST 1
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	__M_LCD0_SETDATA	#'N'			;PITCH_DEST P
	__M_LCD0_SETDATA	#' '
	
	MOV	A, PRESSURE_DEST			;COMPASS_DEST 10
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, PRESSURE_DEST			;COMPASS_DEST 1
	ANL	A, #0x0F
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	__M_LCD0_SETDATA	#'.'			;PITCH_DEST P
	
	MOV	A, PRESSURE_DEST+1			;COMPASS_DEST 0.1
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, PRESSURE_DEST+1			;COMPASS_DEST 0.01
	ANL	A, #0x0F
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	__M_LCD0_SETDATA	#'m'			;PITCH_DEST P
	
	__M_LCD0_SETCURSOR	1,0
	
	MOV	A, C_PWM				;C_PWM = 100? 0xA0 (BCD100)
	CJNE	A, #0xA0, command_ui_pwm
	__M_LCD0_SETDATA	#'1'
	__M_LCD0_SETDATA	#'0'
	__M_LCD0_SETDATA	#'0'
	JMP	command_ui_pwm_end
	
	command_ui_pwm:
	__M_LCD0_SETDATA	#'0'			;C_PWM 100
	
	MOV	A, C_PWM				;C_PWM 10 (Notice: reload C_PWM because A has been overwrite by __M_LCD0_SETDAT)
	ANL	A, #0xF0
	SWAP	A
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, C_PWM				;C_PWM 1
	ANL	A, #0x0F
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	command_ui_pwm_end:
	
	__M_LCD0_SETDATA	#'%'			;C_PWM %PWM
	__M_LCD0_SETDATA	#'P'
	__M_LCD0_SETDATA	#'W'
	__M_LCD0_SETDATA	#'M'
	
	__M_LCD0_SETCURSOR	1,12			;Digital input ->
	__M_LCD0_SETDATA	#0x7E
	
	MOV	A, DIGI_BUFFER_E			;Digital input EXH (100)
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, DIGI_BUFFER_H			;Digital input High (10)
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	MOV	A, DIGI_BUFFER_L			;Digital input Low (1)
	ADD	A, #0x30
	CALL	LCD0_SETDATA
	
	
	
	
	
	
	

CHECKSUM:
	JNB	F0, $					;Wait for package fully received
	CLR	F0
	CLR	LED_IDEL
	
	CLR	A					;Clear A, R2, prepare to calculate checksum
	MOV	R2, A
	
	MOV	R1, #RX_BUFFER_BEGIN			;Go through all data in the rx buffer
	checksum_loop:
	MOVX	A, @R1					;Accumulately add to get checksum
	ADD	A, R2					;R2 <-- Accumulate result
	MOV	R2, A
	INC	R1					;Pointer inc
	CJNE	R1, #RX_BUFFER_END, checksum_loop
	
	DEC	R1
	MOVX	A, @R1
	XCH	A, R2					;A <-- Data + checksum, R2 <-- checksum
	SUBB	A, R2					;Data + checksum - checksum - checksum should be 0
	SUBB	A, R2
	SETB	LED_COMERROR
	JNZ	$					;Checksum error, stall here
	CLR	LED_COMERROR

DATAUI:
	
JMP	$

	
	
CYCLE_END:
	SETB	LED_IDEL
	JMP	MAIN
	
	

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:
	CLR	TF0
	RETI

INT_1:
	RETI

TIMER_1:
	CLR	TF1
	RETI

UART:							;Tx/Rx interrupt, R0 = Tx pointer, R1 = Rx pointer
	PUSH	ACC
	PUSH	PSW
	JBC	RI, UART_rxc				;Check interrupt reason
	CLR	TI
	
UART_txc:
	CJNE	R0, #TX_BUFFER_END, uart_txc_send	;Is package fully send?
	JMP	UART_end
	
	uart_txc_send:
	MOVX	A, @R0					;Get data from buffer and send to UART
	MOV	SBUF, A
	INC	R0					;Pointer inc
	JMP	UART_end
	
UART_rxc:
	MOV	A, SBUF					;Get data from UART
	
	uart_rxc_sync:
	MOV	A, SP					;Write return PC to MAIN
	SUBB	A, #3					;Stack = -PSW, ACC, PC_H, PC_L
	MOV	R0, A
	MOV	@R0, #LOW(MAIN)
	INC	R0
	MOV	@R0, #HIGH(MAIN)
	
	MOV	R0, #TX_BUFFER_BEGIN			;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	R1, #RX_BUFFER_BEGIN
	
	JMP	UART_end				;Exit
	
	uart_rxc_data:
	MOVX	@R1, A					;Save the word in buffer
	INC	R1					;Pointer inc
	
	CJNE	R1, #RX_BUFFER_END, uart_end		;Is package fully received?
	SETB	F0
	
UART_end:
	POP	PSW
	POP	ACC
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; CONSTANT DATA TABLES ---------------------------------



END;
