#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>


/************************************************************************/
/* Config                                                               */
/************************************************************************/

#define RC_CLOCK_FREQ 1000000
#define RC_CLOCK_CALIBRATE 0xA0
#define UART_BAUD 2400
#define UART_BUFFERSIZE 16

#define ADC_BASEDATA_ADMUX ( (0<<REFS0) | (1<<ADLAR) ) //ADC left-adjust, using Vref (5V)
#define ADC_BASEDATA_ADCSRA ( (1<<ADEN) | (3<<ADPS0) ) //Enable ADC, , ADC clk = Sys clk / 8 = 125kHz (best range 50kHz-200kHz)
#define ADC_CH_VS 3
#define ADC_CH_DEPTH 2


/************************************************************************/
/* Application SFRs                                                     */
/************************************************************************/

//Communication sub-system transport layer
volatile uint8_t bufferTx[UART_BUFFERSIZE], bufferRx[UART_BUFFERSIZE] ,bufferTxIndex, bufferRxIndex;

//Sensor data
volatile uint16_t depthBCD, vsBCD, compassBCD, pitchBCD, temperatureBCD;
volatile uint8_t compass, pitch, temperature, cin;



/************************************************************************/
/* Code segment                                                         */
/************************************************************************/

//Polling ADC
uint8_t getVsBCD(uint8_t channel) {
	ADMUX = ADC_BASEDATA_ADMUX | (channel<<MUX0); //Select ADC channel
	ADCSRA = ADC_BASEDATA_ADCSRA | (1<<ADSC); //Start ADC
	while ( ADCSRA & (1<<ADSC) ); //Wait (by polling) until ADC finished
	return ADCH; //Get ADC result (MSB 8 bits)
}

//Init hardwares
int main(void) {
	//Init system clock
	CLKPR = 0x80;
	CLKPR = 0x03; //Clk divider = 8
	OSCCAL = RC_CLOCK_CALIBRATE;
	
	//Init UART
	UBRR0 = RC_CLOCK_FREQ/16/UART_BAUD-1;
	UCSR0B = (1<<RXCIE0) | (1<<TXCIE0) | (1<<RXEN0) | (1<<TXEN0); //Enable Tx, Rx, Tx interrupt and Rx interrupt
	UCSR0C = (1<<USBS0) | (3<<UCSZ00); //Async USART (UART), no parity, 2 stop bits, 8 bits data
	bufferTxIndex = 0;
	bufferRxIndex = 0;
	
	//Init I/O
	DDRD = 0x00;
	DDRB = 0xFF;
	
	//Init ADC
	ADMUX = ADC_BASEDATA_ADMUX;
	ADCSRA = ADC_BASEDATA_ADCSRA;
	DIDR0 = 0b00001111; //ADC channel 0 to 3 is for ADC only, disable the digital input buffer could reduce power consumption
	
	//Init I2C
	
	
	//Init timer0: the ROV exchange data with operator-side console every 250ms
	TCCR0A = 0b00000010; //CTC mode with OCR0A
	TCCR0B = 0b00000101; //Clk source = System clock / 1024
	OCR0A = 0xF4; //250000 / 1024 = 244.14 = 0xF4  <-- The clk doesn't need to be very accurate
	TIMSK0 = 0b00000010; //Enable Timer0 Compare match A interrupt ISR
	
	sei();
	
	for(;;) {
		
	}
}

//Main process <-- The main process of the ROV application, executed every 250ms
//All tasks in this ISR is guarantee to be done in 250ms
ISR (TIMER0_COMPA_vect) {
	
	/************************************************************************/
	/* STEP 1 - Polling packet from operator, if available and verified     */
	/************************************************************************/
	
	//Polling packet from operator-side console
	if (bufferRxIndex == UART_BUFFERSIZE) {
		uint8_t checksum = 0; //Calculate checksum
		for (uint8_t i = 0; i < UART_BUFFERSIZE; i++)
			checksum += bufferRx[i];
		
		if (!checksum) { //Update only if ckecksum OK
			
		}
	}
	
	//Reset UART buffer
	bufferTxIndex = 0;
	bufferRxIndex = 0;
	sei();
	
	/************************************************************************/
	/* STEP 2 - Get ROV status from sensors                                 */
	/************************************************************************/
	
	//From ADC sensor
	vsBCD = pgm_read_word(&(vsLookup[getVsBCD(ADC_CH_VS)]));
	depthBCD = pgm_read_word(&(depthLookup[getVsBCD(ADC_CH_DEPTH)]));
	
	//From I2C - MPU9250
	
	/************************************************************************/
	/* STEP 3 - Send ROV status to operatir-side console                    */
	/************************************************************************/
	
	//Send the first word (SYNC), following word will be send by TxC interrupt
	UDR0 = 0x00; //Note: Sending this signal takes 1/240s, the packet should be packed in this time
	
	bufferTx[0] = (uint8_t)(depthBCD & 0xFF);
	bufferTx[1] = (uint8_t)(depthBCD >> 8);
	bufferTx[2] = 0x00;
	bufferTx[3] = 0x00;
	bufferTx[4] = 0x00;
	bufferTx[5] = 0x00;
	bufferTx[6] = 0x00;
	bufferTx[7] = 0x00;
	bufferTx[8] = (uint8_t)(vsBCD & 0xFF);
	bufferTx[9] = (uint8_t)(vsBCD >> 8);
	bufferTx[10] = 0x00;
	//Word 11 to 14 not used
	
	//Send packet to operator
	uint8_t checksum = 0; //Get ckecksum
	for (uint8_t i = 0; i < UART_BUFFERSIZE-1; i++)
		checksum += bufferTx[i];
	bufferTx[UART_BUFFERSIZE-1] = 0 - checksum; //The last word of the packet is checksum
	
	/************************************************************************/
	/* STEP 4 - While sending packet, analysis user command                 */
	/************************************************************************/
	
	
	
	/************************************************************************/
	/* STEP 5 - A/P: Modify user command if AP enabled                      */
	/************************************************************************/
	
	
	
	
	/************************************************************************/
	/* STEP 6 - Send command to motors and valves                           */
	/************************************************************************/
	
	
	
	
}

ISR (USART_TX_vect) {
	if (bufferTxIndex < UART_BUFFERSIZE) //Send if index in buffer size range
		UDR0 = bufferTx[bufferTxIndex++];
}

ISR (USART_RX_vect) {
	if (bufferRxIndex < UART_BUFFERSIZE) //Prevent buffer overflow
		bufferRx[bufferRxIndex++] = UDR0;
}


/************************************************************************/
/* ROM consts, lookup tables                                            */
/************************************************************************/

const uint16_t vsLookup[256] PROGMEM = { //Battery voltage in BCD [TODO]
	//Vin = ADC_READ / 255 * 5.04 * (9.7k + 33k) / 9.7k
	0x0000,0x0010,0x0020,0x0030, 0x0030,0x0040,0x0050,0x0060, 0x0070,0x0080,0x0090,0x0100, 0x0100,0x0110,0x0120,0x0130,
	0x0140,0x0150,0x0160,0x0170, 0x0170,0x0180,0x0190,0x0200, 0x0210,0x0220,0x0230,0x0230, 0x0240,0x0250,0x0260,0x0270,
	0x0280,0x0290,0x0300,0x0300, 0x0310,0x0320,0x0330,0x0340, 0x0350,0x0360,0x0370,0x0370, 0x0380,0x0390,0x0400,0x0410,
	0x0420,0x0430,0x0440,0x0440, 0x0450,0x0460,0x0470,0x0480, 0x0490,0x0500,0x0500,0x0510, 0x0520,0x0530,0x0540,0x0550,
	
	0x0560,0x0570,0x0570,0x0580, 0x0590,0x0600,0x0610,0x0620, 0x0630,0x0640,0x0640,0x0650, 0x0660,0x0670,0x0680,0x0690,
	0x0700,0x0700,0x0710,0x0720, 0x0730,0x0740,0x0750,0x0760, 0x0770,0x0770,0x0780,0x0790, 0x0800,0x0810,0x0820,0x0830,
	0x0840,0x0840,0x0850,0x0860, 0x0870,0x0880,0x0890,0x0900, 0x0900,0x0910,0x0920,0x0930, 0x0940,0x0950,0x0960,0x0970,
	0x0970,0x0980,0x0990,0x1000, 0x1010,0x1020,0x1030,0x1040, 0x1040,0x1050,0x1060,0x1070, 0x1080,0x1090,0x1100,0x1100,
	
	0x1110,0x1120,0x1130,0x1140, 0x1150,0x1160,0x1170,0x1170, 0x1180,0x1190,0x1200,0x1210, 0x1220,0x1230,0x1240,0x1240,
	0x1250,0x1260,0x1270,0x1280, 0x1290,0x1300,0x1310,0x1310, 0x1320,0x1330,0x1340,0x1350, 0x1360,0x1370,0x1370,0x1380,
	0x1390,0x1400,0x1410,0x1420, 0x1430,0x1440,0x1440,0x1450, 0x1460,0x1470,0x1480,0x1490, 0x1500,0x1510,0x1510,0x1520,
	0x1530,0x1540,0x1550,0x1560, 0x1570,0x1570,0x1580,0x1590, 0x1600,0x1610,0x1620,0x1630, 0x1640,0x1640,0x1650,0x1660,
	
	0x1670,0x1680,0x1690,0x1700, 0x1710,0x1710,0x1720,0x1730, 0x1740,0x1750,0x1760,0x1770, 0x1770,0x1780,0x1790,0x1800,
	0x1810,0x1820,0x1830,0x1830, 0x1840,0x1850,0x1860,0x1870, 0x1880,0x1890,0x1900,0x1910, 0x1910,0x1920,0x1930,0x1940,
	0x1950,0x1960,0x1970,0x1980, 0x1980,0x1990,0x2000,0x2010, 0x2020,0x2030,0x2040,0x2040, 0x2050,0x2060,0x2070,0x2080,
	0x2090,0x2100,0x2110,0x2110, 0x2120,0x2130,0x2140,0x2150, 0x2160,0x2170,0x2180,0x2180, 0x2190,0x2200,0x2210,0x2220
};

const uint16_t depthLookup[256] PROGMEM = { //Depth in BCD [TODO]
	//Depth(cm) = (ADC_READ / 5.06 - 0.493) / 3.2487 * 10
	
};
