; Operator console

; CONFIG FILES -----------------------------------
$INCLUDE	(c_sfr.a51)
$INCLUDE	(c_cfg.a51)
$INCLUDE	(c_ram.a51)
	
; NOTICE:	MAIN ROUTINE			USING REGISTER BANK 0 ONLY!
;		LCD INTERRUPT SUBROUTINE	USING REGISTER BANK 2 ONLY!
;		UART INTERRUPT SUBROUTINE	USING REGISTER BANK 3 ONLY!
; NOTICE: LCD MODULE IS WRITE-ONLY!


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

USING	0
DIGITAL_INPUT:						;User enter a digital to AutoPilot console
	MOV	DIGI_BUFFER_E, DIGI_BUFFER_H		;Data shift left, Data Low = input
	MOV	DIGI_BUFFER_H, DIGI_BUFFER_L
	MOV	DIGI_BUFFER_L, R7			;Input is guaranted to be from 0x00-0x09
	RET
	
; MAIN CODE --------------------------------------------

USING	0
INI:							;Boot setup
	MOV	SP, #0x7F
	
	CLR	LCD_RW					;Set LCD to Write mode
	
	__M_LCD_PREPARE					;LCD ini
	
	MOV	A, #'P'					;LCD constant display character
	__M_LCD_WRITEBUFFER	0,0,3
	MOV	A, #' '
	__M_LCD_APPENDBUFFER				;LCD0:	0123456789ABCDEF
	MOV	A, #'N'					;	xxxP xxxN xx.xxm
	__M_LCD_WRITEBUFFER	0,0,8			;	PWMxxx%     >xxx
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	MOV	A, #'.'
	__M_LCD_WRITEBUFFER	0,0,12
	MOV	A, #'m'
	__M_LCD_WRITEBUFFER	0,0,15
	
	MOV	A, #'P'
	__M_LCD_WRITEBUFFER	0,1,0
	MOV	A, #'W'
	__M_LCD_APPENDBUFFER
	MOV	A, #'M'
	__M_LCD_APPENDBUFFER
	MOV	A, #'%'
	__M_LCD_WRITEBUFFER	0,1,6
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	MOV	A, #0x7E ;0x7e is --> mark
	__M_LCD_WRITEBUFFER	0,1,12
	
	MOV	A, #'.'					;LCD1:	0123456789ABCDEF
	__M_LCD_WRITEBUFFER	1,0,2			;	xx.xV +xx.xxC xx
	MOV	A, #'V'					;	xxxP xxxN xx.xxm
	__M_LCD_WRITEBUFFER	1,0,4
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	MOV	A, #'.'
	__M_LCD_WRITEBUFFER	1,0,9
	MOV	A, #'C'
	__M_LCD_WRITEBUFFER	1,0,11
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	
	MOV	A, #'P'
	__M_LCD_WRITEBUFFER	1,1,3
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	MOV	A, #'N'
	__M_LCD_WRITEBUFFER	1,1,8
	MOV	A, #' '
	__M_LCD_APPENDBUFFER
	MOV	A, #'.'
	__M_LCD_WRITEBUFFER	1,1,12
	MOV	A, #'m'
	__M_LCD_WRITEBUFFER	1,1,15
	
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART, timer2 is for LCD
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 mode to 16-bit timer
	SETB	TR1					;Enable timer1 and timer0, enable timer0 interrupt
	SETB	TR0
	SETB	ET0
	
	MOV	R20, #LCD_BUFFER			;Reset LCD buffer pointer, both LCO shares same pointer
	MOV	R30, #TX_BUFFER_BEGIN			;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	R31, #RX_BUFFER_BEGIN
	
	MOV	SCAN_DIVIDER, #0x00			;Slow down keyboard (digital input) scan speed, switch scan = 4Hz, keyboard scan = 1Hz (human speed)
	
	SETB	EA

USING	0
WAIT:
	JMP	$
	
USING	0
MAIN:							;Main cycle: execute while receive synch signal
	CLR	LED_IDEL
	CLR	LED_COMERROR
	
USING	0
SCAN:							;Scan keyboard
	MOV	KEY_SCAN, #11111111B
	
	MOV	KEY_DRIVE, #01111111B			;Scan row 7: LightL - LightC - LightR - Navi - X - XForward - Forward - Backward
	NOP
	MOV	FB_VALVE, KEY_SCAN
	CPL	A					;All keys are active low
	MOV	FB_VALVE, A				;Get X - XForward - Forward - Backward
	ANL	FB_VALVE, #00000111B
	ANL	LED, #11110000B				;Get LightL - LightC - LightR - Navi
	SWAP	A
	MOV	LED, A
	
	MOV	KEY_DRIVE, #10111111B			;Scan row 6: Compass - PCompass - TurnLeft - TurnRight - X - X - ShiftLeft - ShiftRight
	NOP						;Notice: Some bits will be scand and saved (for example: X, or TurnLeft when AP Compass actived), 
	MOV	LR_VALVE, KEY_SCAN			;	but those bits will not be processed by the ROV (DNC bits), hence it id OK to send dirty byte.
	CPL	A
	MOV	LR_VALVE, A
	
	MOV	KEY_DRIVE, #11011111B			;Scan row 5: Pitch - PPitch - PitchUp - PitchDown - Press - PPress - Up - Down
	NOP
	MOV	A, KEY_SCAN				;MOV A, INPUT; CPL A; MOV RAM, A;	5 bytes + 3 cycles
	CPL	A					;MOV RAM, INPUT; XRL RAM #0xFF;		6 bytes + 4 cycles
	MOV	UD_VALVE, A
	
	MOV	KEY_DRIVE, #11101111B			;Scan row 4: Custom output
	NOP
	MOV	A, KEY_SCAN
	CPL	A
	MOV	C_OUT, A
	
	MOV	A, SCAN_DIVIDER				;Clock divider for digital input
	ADD	A, #(0x100 / DIGITAL_PRESCA)
	MOV	SCAN_DIVIDER, A
	JC	SCAN_keyboard
	JMP	SCAN_end
	
	SCAN_keyboard:
	MOV	KEY_DRIVE, #11110111B			;Scan row 3: Digital input high/apply
	NOP
	
	scan_3_pitch:					;User apply value from gitital input buffer to AutoPilot pitch control, check required
	JB	KEY_SCAN.7, scan_3_compass
	MOV	A, DIGI_BUFFER_L			;Apply PITCH_DEST low, assume it is correct
	SWAP	A
	MOV	PITCH_DEST, A
	MOV	A, DIGI_BUFFER_E			;Apply PITCH_DEST high as well
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	PITCH_DEST+1, A
	MOV	B, A					;Save PITCH_DEST high (100s and 10s)
	ADD	A, #-0x09				;Is the value >= 90? (90=090 --> the 100s and 10s are greater than 09)
	JNC	SCAN_end				;8+(-9):NC; 9+(-9):C; 10+(-9): C;
	MOV	A, B					;And the value <= 270 as well?
	SUBB	A, #0x27				;26-(27):C; 27-(27):NC; 28-(27):NC
	JNC	SCAN_end
	;Note:	91, 92: invalid: disable 90.
	;	271, 272: valid: enable 270. <-- simpler code is better than complex code, "Good design demands good compromises"
	MOV	PITCH_DEST+1, #0x00			;90 <= PITCH_DEST < 270, invalid input! Correct to 00x
	MOV	PITCH_DEST, #0x00
	JMP	SCAN_end				;Only one key at a time, ignor other keys (DNC)
	
	scan_3_compass:					;User apply value from gitital input buffer to AutoPilot compass control, check required
	JB	KEY_SCAN.6, scan_3_pressure
	MOV	A, DIGI_BUFFER_L			;Apply COMPASS_DEST low, assume it is correct
	SWAP	A
	MOV	COMPASS_DEST, A
	MOV	A, DIGI_BUFFER_E			;Apply COMPASS_DEST high as well
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	COMPASS_DEST+1, A
	ADD	A, #-0x36				;Is the number >= 360
	JNC	SCAN_end				;35+(-36):NC; 36+(-36):C
	MOV	COMPASS_DEST+1, #0x00			;COMPASS >= 360, invalid input! Correct to 00x
	MOV	COMPASS_DEST, #0x00
	JMP	SCAN_end
	
	scan_3_pressure:				;User apply value from gitital input buffer to AutoPilot pressure (depth) control, any depth is OK
	JB	KEY_SCAN.5, scan_3_cpwm
	MOV	A, DIGI_BUFFER_E			;Apply PRESSURE_DEST high (xx.00m)
	SWAP	A
	ORL	A, DIGI_BUFFER_H
	MOV	COMPASS_DEST+1, A
	MOV	A, DIGI_BUFFER_L			;Apply PRESSURE_DEST high (00.xxm), leave 0.01s to be 0 (resolution 0.1m)
	SWAP	A
	MOV	COMPASS_DEST, A
	JMP	SCAN_end	
	
	scan_3_cpwm:					;User apply value from gitital input buffer to custom PWM output control
	JB	KEY_SCAN.4, scan_3_0
	MOV	A, DIGI_BUFFER_E
	JZ	scan_3_cpwm_read			;If buffer_EXH has value (100s is not 0), set PWM to 100
	MOV	C_PWM, #0xA0
	JMP	SCAN_end
	scan_3_cpwm_read:
	MOV	A, DIGI_BUFFER_H			;Get 10s to higher nibble
	SWAP	A
	ADD	A, DIGI_BUFFER_L			;Add 1s to lower nibble
	MOV	C_PWM, A
	JMP	SCAN_end
	
	scan_3_0:					;If this key is 0, it will make the scaning of row2 faster and code will be smaller (so I can use DJNZ)
	JB	KEY_SCAN.1, scan_3_8
	MOV	R7, #0					
	CALL	DIGITAL_INPUT
	JMP	SCAN_end
	scan_3_8:
	JB	KEY_SCAN.0, scan_3_end
	MOV	R7, #9
	CALL	DIGITAL_INPUT
	JMP	SCAN_end
	scan_3_end:
	
	MOV	KEY_DRIVE, #11111011B			;Scan row 2: Digital input low
	MOV	R7, #8
	MOV	A, KEY_SCAN
	scan_2_loop:					;Scan all 8 keys on row 2
	RRC	A					;Rotate to right, first bit is key_8
	JNC	scan_2_keyreleased			;key press = 0, key released = 1
	CALL	DIGITAL_INPUT
	JMP	SCAN_end				
	scan_2_keyreleased:
	DJNZ	R7, scan_2_loop				;R7 reaches 0 (8 to 1 has been scaned)
	
	SCAN_end:
	MOV	KEY_DRIVE, #11111111B			;Keyboard scan end
	MOV	ENGINE_POWER, #0xA0			;Engine power is always 100%
	
	;	;Test
	MOV	C_PWM, #0x35				;C_PWM = 035%
	MOV	PITCH_DEST+1, #0x29			;PITCH_DEST = 296 (64 down)
	MOV	PITCH_DEST, #0x60
	MOV	COMPASS_DEST+1, #0x13			;COMPASS_DEST = 135
	MOV	COMPASS_DEST, #0x50
	MOV	PRESSURE_DEST+1, #0x24			;PRESSURE_DEST = 24.55m
	MOV	PRESSURE_DEST, #0x55
	MOV	DIGI_BUFFER_E, #0x01			;DIGI_BUFFER = 123
	MOV	DIGI_BUFFER_H, #0x02
	MOV	DIGI_BUFFER_L, #0x03
	;End of test
	
USING	0
PACK:							;App SFR --> Tx buffer
	
	MOV	A, FB_VALVE				;Send first word (not nessary to save it in buffer)
	ORL	A, LED
	MOV	SBUF, A
	MOV	R2, A					;Checksum
	
	MOV	R30, #TX_BUFFER_BEGIN+1			;Buffer pointer set to second word (buffer --> UART)
	MOV	R0, #TX_BUFFER_BEGIN+1			;(App SFR --> buffer) XRAM address < 0x0100, hence R0 is OK
	
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM	MACRO
		MOVX	@R0, A
		ADD	A, R2
		MOV	R2, A
		INC	R0
	ENDM
	
	MOV	R1, #LR_VALVE				;Bit data. In order, using R addressing and INC R to fetch data
	MOV	A, @R1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	INC	R1
	MOV	A, @R1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	INC	R1
	MOV	A, @R1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, ENGINE_POWER				;Numeric data. Not in order, have to use direct addressing
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, PRESSURE_DEST
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	MOV	A, PRESSURE_DEST+1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, PITCH_DEST
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	MOV	A, PITCH_DEST+1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, COMPASS_DEST
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	MOV	A, COMPASS_DEST+1
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, C_PWM
	__M_PACK_WRITEBUFFER_AND_GETCHECKSUM
	
	MOV	A, R2					;Checksum
	MOVX	@R0, A
	
USING	0
COMMAND_UI:						;Update command data to LCD0 buffer
	MOV	A, PITCH_DEST+1				;PITCH_DEST 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,0
	MOV	A, PITCH_DEST+1				;PITCH_DEST 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PITCH_DEST				;PITCH_DEST 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_DEST+1			;COMPASS_DEST 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,5
	MOV	A, COMPASS_DEST+1			;COMPASS_DEST 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, COMPASS_DEST				;COMPASS_DEST 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_DEST+1			;PRESSURE_DEST 10
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,10
	MOV	A, PRESSURE_DEST+1			;PRESSURE_DEST 1
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PRESSURE_DEST			;PRESSURE_DEST 0.1
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,13
	MOV	A, PRESSURE_DEST			;PRESSURE_DEST 0.01
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, C_PWM				;C_PWM = 100? 0xA0 (BCD100)
	CJNE	A, #0xA0, command_ui_pwm
	MOV	A, #'1'					;C_PWM = 100
	__M_LCD_WRITEBUFFER	0,1,3
	MOV	A, #'0'
	__M_LCD_APPENDBUFFER
	__M_LCD_APPENDBUFFER
	
	command_ui_pwm:
	MOV	A, #'0'					;C_PWM 100
	__M_LCD_WRITEBUFFER	0,1,3
	MOV	A, C_PWM				;C_PWM 10
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, C_PWM				;C_PWM 1
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	command_ui_pwm_end:
	
	MOV	A, DIGI_BUFFER_E			;Digital input EXH (100)
	__M_LOW2ASCII
	__M_LCD_WRITEBUFFER	0,1,13
	MOV	A, DIGI_BUFFER_H			;Digital input High (10)
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, DIGI_BUFFER_L			;Digital input Low (1)
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	
USING	0
WAITPACKAGE:
	SETB	LED_IDEL
	MOV	A, #RX_BUFFER_END
	CJNE	A, R31, $				;Wait until package fully received (Notice: R31(Rx buffer pointer) is a real-time value)
	CLR	LED_IDEL
	
USING	0
CHECKSUM:
	MOV	R2, #0					;Clear R2, prepare to calculate checksum
	
	MOV	R0, #RX_BUFFER_BEGIN			;Go through all data in the rx buffer
	checksum_loop:
	MOVX	A, @R0					;Accumulately adding to get checksum
	ADD	A, R2					;R2 <-- Accumulate result
	MOV	R2, A
	INC	R0					;Pointer inc
	CJNE	R0, #LOW RX_BUFFER_END-1, checksum_loop
	
	MOVX	A, @R0
	XCH	A, R2					;A <-- Data, R2 <-- checksum
	SUBB	A, R2					;Data + checksum - checksum - checksum should be 0
	
	SETB	LED_COMERROR
	SETB	LED_IDEL
	JNZ	$					;Checksum error, stall here
	CLR	LED_COMERROR
	CLR	LED_IDEL

USING	0
UNPACK:							;Rx buffer --> App SFR
	MOV	R0, #RX_BUFFER_BEGIN
	
	__M_UNPACKPACK	MACRO	APPSFR
		MOVX	A, @R0
		MOV	APPSFR, A
		INC	R0
		MOVX	A, @R0
		MOV	APPSFR+1, A
		INC	R0
	ENDM

	__M_UNPACKPACK PRESSURE_REAL
	__M_UNPACKPACK PITCH_REAL
	__M_UNPACKPACK COMPASS_REAL
	__M_UNPACKPACK TEMPERATURE
	__M_UNPACKPACK BAT_VOLTAGE

USING	0
DATAUI:							;Update ROV data to LCD1 buffer
	MOV	A, BAT_VOLTAGE+1			;BAT_VOLTAGE 10
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,0,0
	MOV	A, BAT_VOLTAGE+1			;BAT_VOLTAGE 1
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, BAT_VOLTAGE				;BAT_VOLTAGE 0.1
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,0,3
	
	MOV	A, TEMPERATURE+1			;TEMPERATURE sign (ASCII)
	ANL	A, #0xF0
	SWAP	A
	ORL	A, #0x20
	__M_LCD_WRITEBUFFER	1,0,6
	MOV	A, TEMPERATURE+1			;TEMPERATURE 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, TEMPERATURE				;TEMPERATURE 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, TEMPERATURE				;TEMPERATURE 0.1
	__M_LOW2ASCII
	__M_LCD_WRITEBUFFER	1,0,10
	
	MOV	A, BAT_VOLTAGE				;C_IN 1
	ANL	A, #00000010B
	RR	A
	ORL	A, #0xFE				;If high, print 0xFF (black block); otherwise, print 0xFE (space)
	__M_LCD_WRITEBUFFER	1,0,14
	MOV	A, BAT_VOLTAGE				;C_IN 0
	ANL	A, #00000001B
	ORL	A, #0xFE
	__M_LCD_APPENDBUFFER
	
	MOV	A, PITCH_REAL+1				;PITCH_REAL 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,1,0
	MOV	A, PITCH_REAL+1				;PITCH_REAL 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PITCH_REAL				;PITCH_REAL 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_REAL+1			;COMPASS_REAL 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,1,5
	MOV	A, COMPASS_REAL+1			;COMPASS_REAL 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, COMPASS_REAL				;COMPASS_REAL 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_REAL+1			;PRESSURE_REAL 10
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,1,10
	MOV	A, PRESSURE_REAL+1			;PRESSURE_REAL 1
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PRESSURE_REAL			;PRESSURE_REAL 0.1
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	1,1,13
	MOV	A, PRESSURE_REAL			;PRESSURE_REAL 0.01
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	
USING	0
CYCLE_END:
	SETB	LED_IDEL
	JMP	WAIT
	

; INTERRUPT SUBROUTINE ---------------------------------
USING	0
INT_0:
	RETI

USING	2
TIMER_0:						;Update LCD, R0 = LCD pointer
	CLR	TF0
	
	PUSH	ACC
	PUSH	PSW
	SETB	RS1
	CLR	RS0
	
	MOV	TH0, #0xF4				;Sample from ROV every 250000us, LCD sample from sample every 125000us
	MOV	TL0, #0x48				;(16+1)*2 LCD = 34chars --> Update LCD every 3000us (-3000 = 0xF448)
	
	timer_0_checkline0end:
	CJNE	R0, #LCD0_LINE0+LCD_LINELENGTH, timer_0_checkline1end	;Pointer points to 0x10 (line0 end)
	MOV	R0, #LCD0_LINE1				;Pointer --> next line
	CLR	LCD_RS
	SETB	LCD_E0
	SETB	LCD_E1
	MOV	LCD_DATA, #0x80|0x40			;LCD command: go to line1
	CLR	LCD_E0
	CLR	LCD_E1
	JMP	TIMER_0_end
	
	timer_0_checkline1end:
	CJNE	R0, #LCD0_LINE1+LCD_LINELENGTH, timer_0_sendchar	;Pointer points to 0x30 (line1 end)
	MOV	R0, #LCD0_LINE0				;Pointer --> next line (go back to line0)
	CLR	LCD_RS
	SETB	LCD_E0
	SETB	LCD_E1
	MOV	LCD_DATA, #0x80|0x00			;LCD command: go to line0
	CLR	LCD_E0
	CLR	LCD_E1
	JMP	TIMER_0_end
	
	timer_0_sendchar:
	SETB	LCD_RS
	
	MOVX	A, @R0					;Get data of LCD0
	SETB	LCD_E0
	MOV	LCD_DATA, A
	CLR	LCD_E0
	
	MOV	A, #LCD1_LINE0-LCD0_LINE0		;Get date of LCD1
	ADD	A, R0
	MOV	R1, A
	MOVX	A, @R1
	SETB	LCD_E1
	MOV	LCD_DATA, A
	CLR	LCD_E1
	INC	R0					;Pointer+
	
	TIMER_0_end:
	POP	PSW
	POP	ACC
	RETI

USING	0
INT_1:
	RETI

USING	0
TIMER_1:						;DO NOT USE! TIMER1 IS USED BY UART AS BAUD RATE GENERATOR.
	CLR	TF1
	RETI

USING	3
UART:							;Tx/Rx interrupt, R0 = Tx pointer, R1 = Rx pointer
	PUSH	ACC
	PUSH	PSW
	SETB	RS1
	SETB	RS0
	
	JBC	RI, UART_rxc				;Check interrupt reason
	JBC	TI, UART_txc
	JMP	UART_end
	
UART_txc:
	CJNE	R0, #TX_BUFFER_END, uart_txc_send	;Is package fully send?
	JMP	UART_end
	
	uart_txc_send:
	MOVX	A, @R0					;Get data from buffer and send to UART
	MOV	SBUF, A
	INC	R0					;Pointer inc
	
	;Notice: Tx can only be active by main procee once after SYNCH signal fired, and the SYNCH signal will first reset the write pointer;
	;	hence, it is impossible to have the Tx buffer overflow
	
	JMP	UART_end
	
UART_rxc:
	MOV	A, SBUF					;Get data from UART
	CJNE	A, #0xFF, uart_rxc_data			;Synch signal?
	
	uart_rxc_sync:
	MOV	A, SP					;Write return PC to MAIN
	SUBB	A, #3					;Stack = (H) >PSW<, ACC, PC_H, PC_L (L)
	MOV	R0, A
	MOV	@R0, #LOW MAIN
	INC	R0
	MOV	@R0, #HIGH MAIN
	
	MOV	R0, #TX_BUFFER_BEGIN			;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	R1, #RX_BUFFER_BEGIN
	
	JMP	UART_end				;Exit
	
	uart_rxc_data:
	MOVX	@R1, A					;Save the word in buffer
	INC	R1					;Pointer inc
	
	MOV	A, R1					;Rollback pointer if overflow
	JNZ	UART_end
	DEC	R1
	
UART_end:
	POP	PSW
	POP	ACC
	RETI

USING	0
TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; CONSTANT DATA TABLES ---------------------------------



END;
