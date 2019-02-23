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

DIGITAL_APPLY_PITCH:					;User apply value from gitital input buffer to AutoPilot pitch control
	
	RET

DIGITAL_APPLY_COMPASS:					;User apply value from gitital input buffer to AutoPilot compass control
	
	RET

DIGITAL_APPLY_PRESSURE:					;User apply value from gitital input buffer to AutoPilot pressure (depth) control
	
	RET

DIGITAL_APPLY_PWM:					;User apply value from gitital input buffer to custom PWM output control
	MOV	A, DIGI_BUFFER_E
	JZ	digital_apply_pwm_read			;If buffer_EXH has value (100 is not 0), set PWM to 100
	MOV	C_PWM, #0xA0
	RET
	digital_apply_pwm_read:
	MOV	A, DIGI_BUFFER_H			;Get 10s to higher nibble
	SWAP	A
	ADD	A, DIGI_BUFFER_L			;Add 1s to lower nibble
	MOV	C_PWM, A
	RET
	

; MAIN CODE --------------------------------------------

INI:							;Boot setup
	MOV	SP, #0x7F
	
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
	MOV	A, #0x7E
	__M_LCD_WRITEBUFFER	0,1,12
	
	MOV	SCON, #0x50				;UART mode1 (8-bit, flex baud), enable read
	SETB	ES
	
	MOV	TH1, #UART_RELOAD			;Set timer1 auto-reload value - timer1 is for UART
	MOV	TMOD, #0x21				;Set Timer1 mode to auto-reload, timer0 mode to 16-bit timer
	SETB	TR1					;Enable timer1 and timer0, enable timer0 interrupt
	SETB	TR0
	SETB	ET0
	
	MOV	TX_BUFFER_P, #LOW TX_BUFFER_BEGIN	;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	RX_BUFFER_P, #LOW RX_BUFFER_BEGIN
	MOV	LCD_BUFFER_P, #LOW LCD_BUFFER		;Reset LCD buffer pointer
	
	SETB	EA
	
MAIN:							;Main cycle: execute while receive synch signal
	CLR	LED_IDEL
	INC	R5;;;;;
	
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
	CALL	DIGITAL_APPLY_PITCH
	JMP	scan_2_end
	scan_3_compass:
	JB	KEY_SCAN.6, scan_3_pressure
	CALL	DIGITAL_APPLY_COMPASS
	JMP	scan_2_end
	scan_3_pressure:
	JB	KEY_SCAN.5, scan_3_cpwm
	CALL	DIGITAL_APPLY_PRESSURE
	JMP	scan_2_end
	scan_3_cpwm:
	JB	KEY_SCAN.4, scan_3_9
	CALL	DIGITAL_APPLY_PWM
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
	
	MOV	KEY_DRIVE, #0xFF			;Keyboard scan end
	
COMMAND_UI:						;Update command data to LCD0 buffer
;	;Test
;	MOV	C_PWM, #0x29				;C_PWM = 100%
;	MOV	PITCH_DEST, #0x29			;PITCH_DEST = 296 (64 down)
;	MOV	PITCH_DEST+1, #0x60
;	MOV	COMPASS_DEST, #0x13			;COMPASS_DEST = 135
;	MOV	COMPASS_DEST+1, #0x50
;	MOV	PRESSURE_DEST, #0x24			;PRESSURE_DEST = 24.55m
;	MOV	PRESSURE_DEST+1, #0x55
;	MOV	DIGI_BUFFER_E, #0x01			;DIGI_BUFFER = 123
;	MOV	DIGI_BUFFER_H, #0x02
;	MOV	DIGI_BUFFER_L, #0x03
	MOV	DIGI_BUFFER_L, R5;;;;;
;	;End of test
	
	MOV	A, PITCH_DEST				;PITCH_DEST 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,0
	MOV	A, PITCH_DEST				;PITCH_DEST 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PITCH_DEST+1				;PITCH_DEST 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, COMPASS_DEST				;COMPASS_DEST 100
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,5
	MOV	A, COMPASS_DEST				;COMPASS_DEST 10
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, COMPASS_DEST+1			;COMPASS_DEST 1
	__M_HIGH2ASCII
	__M_LCD_APPENDBUFFER
	
	MOV	A, PRESSURE_DEST			;PRESSURE_DEST 10
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,10
	MOV	A, PRESSURE_DEST			;PRESSURE_DEST 1
	__M_LOW2ASCII
	__M_LCD_APPENDBUFFER
	MOV	A, PRESSURE_DEST+1			;PRESSURE_DEST 0.1
	__M_HIGH2ASCII
	__M_LCD_WRITEBUFFER	0,0,13
	MOV	A, PRESSURE_DEST+1			;PRESSURE_DEST 0.01
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
	
	
	
	
	
	
WAITPACKAGE:
	SETB	LED_IDEL
	MOV	A, RX_BUFFER_P
	CJNE	A, #RX_BUFFER_END, $			;Wait until package fully received
	CLR	LED_IDEL
	
CHECKSUM:
	
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

	
	
CYCLE_END:
	SETB	LED_IDEL
	JMP	MAIN
	
	

; INTERRUPT SUBROUTINE ---------------------------------

INT_0:
	RETI

TIMER_0:						;Update LCD
	CLR	TF0
	
	PUSH	ACC
	PUSH	PSW
	PUSH	DPH
	PUSH	DPL
	
	MOV	TH0, #0xF4				;Sample from ROV every 250000us, LCD sample from sample every 125000us
	MOV	TL0, #0x48				;16*2 LCD = 32chars, using 40 --> Update LCD every 3000us (-3000 = 0xF448)
	
	MOV	A, LCD_BUFFER_P				;Check line end
	
	timer_0_checkline0end:
	CJNE	A, #LOW LCD0_LINE0+LCD_LINELENGTH, timer_0_checkline1end	;Pointer points to 0x10 (line0 end)
	MOV	LCD_BUFFER_P, #LOW LCD0_LINE1		;Pointer --> next line
	MOV	A, #0x40				;LCD command: go to line1
	CALL	LCD0_SETCURSOR
	CALL	LCD1_SETCURSOR
	JMP	TIMER_0_end
	
	timer_0_checkline1end:
	CJNE	A, #LOW	LCD0_LINE1+LCD_LINELENGTH, timer_0_sendchar	;Pointer points to 0x10 (line1 end)
	MOV	LCD_BUFFER_P, #LOW LCD0_LINE0		;Pointer --> next line (go back to line0)
	MOV	A, #0x00				;LCD command: go to line0
	CALL	LCD0_SETCURSOR
	CALL	LCD1_SETCURSOR
	JMP	TIMER_0_end
	
	timer_0_sendchar:
	MOV	DPH, #HIGH LCD0_LINE0			;Get pointer to LCD0 data
	MOV	DPL, LCD_BUFFER_P
	INC	LCD_BUFFER_P				;Pointer+
	MOVX	A, @DPTR				;Send data of LCD0 and send
	CALL	LCD0_SETDATA
	MOV	A, DPL					;Get pointer to LCD1 data
	ADD	A, #LCD1_LINE0-LCD0_LINE0
	MOV	DPL, A
	MOVX	A, @DPTR				;Send data of LCD1 and send
	CALL	LCD1_SETDATA
	
	TIMER_0_end:
	POP	DPL
	POP	DPH
	POP	PSW
	POP	ACC
	RETI

INT_1:
	RETI

TIMER_1:						;DO NOT USE! UART USED.
	CLR	TF1
	RETI

UART:							;Tx/Rx interrupt, R0 = Tx pointer, R1 = Rx pointer
	PUSH	ACC
	PUSH	PSW
	PUSH	DPH
	PUSH	DPL
	
	JBC	RI, UART_rxc				;Check interrupt reason
	JBC	TI, UART_txc
	JMP	UART_end
	
UART_txc:
	MOV	A, TX_BUFFER_P
	CJNE	A, #TX_BUFFER_END, uart_txc_send	;Is package fully send?
	JMP	UART_end
	
	uart_txc_send:
	MOV	DPH, #HIGH TX_BUFFER_BEGIN		;Get data from buffer and send to UART
	MOV	DPL, TX_BUFFER_P
	MOVX	A, @DPTR
	MOV	SBUF, A
	INC	TX_BUFFER_P				;Pointer inc
	
	MOV	A, TX_BUFFER_P				;Rollback pointer if reach boyundary
	CJNE	A, #TX_BUFFER_ENDX, UART_end
	DEC	TX_BUFFER_P
	JMP	UART_end
	
UART_rxc:
	MOV	A, SBUF					;Get data from UART
	CJNE	A, #0xFF, uart_rxc_data			;Synch signal?
	
	uart_rxc_sync:
	USING	0
	CLR	RS1
	CLR	RS0
	PUSH	AR0
	
	MOV	A, SP					;Write return PC to MAIN
	SUBB	A, #6					;Stack = >(H)R0, DPL, DPH, PSW, ACC, PC_H, PC_L(L)
	MOV	R0, A
	MOV	@R0, #LOW MAIN
	INC	R0
	MOV	@R0, #HIGH MAIN
	
	MOV	TX_BUFFER_P, #LOW TX_BUFFER_BEGIN	;Reset Tx/Rx buffer pointer (flush buffers)
	MOV	RX_BUFFER_P, #LOW RX_BUFFER_BEGIN
	
	POP	AR0
	JMP	UART_end				;Exit
	
	uart_rxc_data:
	MOV	DPH, #HIGH RX_BUFFER_BEGIN		;Get pointer
	MOV	DPL, RX_BUFFER_P
	MOVX	@DPTR, A				;Save the word in buffer
	INC	RX_BUFFER_P				;Pointer inc
	
	MOV	A, RX_BUFFER_P				;Rollback pointer if reach boyundary
	CJNE	A, #RX_BUFFER_ENDX, UART_end
	DEC	RX_BUFFER_P
	
UART_end:
	POP	DPL
	POP	DPH
	POP	PSW
	POP	ACC
	RETI

TIMER_2:
	CLR	TF2
	CLR	EXF2
	RETI

; CONSTANT DATA TABLES ---------------------------------



END;
