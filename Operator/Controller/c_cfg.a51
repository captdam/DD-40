;App config
	SYSCLK		EQU	10000			;*100
	BAUD		EQU	24			;*100
	UART_RELOAD	EQU	-(SYSCLK/BAUD/32)	;Crys = 12M, Baud = 2400, Mode = 1 (no parrty)
	
	RX_PACK_SIZE	EQU	10
	TX_PACK_SIZE	EQU	11
	
	DIGITAL_PRESCA	EQU	4			;Digital input scan prescaller (orginal speed = 4Hz @ best communication environment)

	
;App pins
	KEY_DRIVE	EQU	P2
	KEY_SCAN	EQU	P0
	LCD_DATA	EQU	P1
	LCD_RS		EQU	P3.2
	LCD_RW		EQU	P3.3
	LCD_E0		EQU	P3.5
	LCD_E1		EQU	P3.4
	LED_COMERROR	EQU	P3.6
	LED_IDEL	EQU	P3.7