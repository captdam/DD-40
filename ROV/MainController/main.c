#include <avr/io.h>
#include <avr/interrupt.h>
#include <avr/pgmspace.h>
#include <math.h>

#include "twi.h"


/************************************************************************/
/* Config                                                               */
/************************************************************************/

#define RC_CLOCK_FREQ 1000000
#define RC_CLOCK_CALIBRATE 0xA0
#define UART_BAUD 2400

#define ADC_BASEDATA_ADMUX ( (0<<REFS0) | (1<<ADLAR) ) //ADC left-adjust, using Vref (5V)
#define ADC_BASEDATA_ADCSRA ( (1<<ADEN) | (3<<ADPS0) ) //Enable ADC, , ADC clk = Sys clk / 8 = 125kHz (best range 50kHz-200kHz)
#define ADC_CH_VS 3
#define ADC_CH_DEPTH 2

#define I2C_MPU_ID 0x68
#define I2C_MPU_ADDR_WHOAMI 0x75
#define I2C_MPU_CONTENT_WHOAMI 0x70
#define I2C_MPU_ADDR_PWRMAGMT1 0x6B
#define I2C_MPU_ADDR_SIGNALPATHRESET 0x68
#define I2C_MPU_ADDR_SLV0CTR 0x25
#define I2C_MPU_ADDR_DATA 0x3B
#define I2C_MPU_AMOUNT_DATA 20 //9 axis + 1 temperature, 2 bytes each

#define I2C_AUX_ID 0x05
#define AUX_VALVE_HU 8 //Head/Tail Up/Down/Left/Right
#define AUX_VALVE_HD 0
#define AUX_VALVE_HL 9
#define AUX_VALVE_HR 1
#define AUX_VALVE_TU 6
#define AUX_VALVE_TD 3
#define AUX_VALVE_TL 5
#define AUX_VALVE_TR 4
#define AUX_VALVE_FW 7 //Forware, Backward
#define AUX_VALVE_BW 11 //NC

#define AP_PITCH_DEADZONE 5 //degree
#define AP_PITCH_MAG 8 //If difference > deadzone + (256/mag), PWM = 100%
#define AP_DEPTH_DEADZONE 20 //cm
#define AP_DEPTH_MAG 8


/************************************************************************/
/* Application SFRs                                                     */
/************************************************************************/

//Analysis purpose
volatile uint8_t systemLoad = 0x00;
volatile uint8_t auxPrescaler = 0;

//Communication sub-system transport layer
volatile uint8_t bufferTx[16], bufferRx[16] ,bufferTxIndex, bufferRxIndex;

//User command
volatile uint8_t command[15] = { //Default user command
	0b00000000, //FB_VALVE: No valve on
	0b00000000, //DIR_VALVE: no valve on
	0b00010000, //FUNC: A/P disabled, navi light on, main light off
	0x00, //REV4
	0xA0, //ENGINE POWER, 100%
	0x00, //C_PWM
	0x00, 0x00, //DEPTH_DEST, 0
	0x00, 0x00, //PITCH_DEST, 0
	0x00, 0x00, //COMPASS_DEST, 0
	0x00, 0x00, 0x00 //REV 0, 1 , 2
};



/************************************************************************/
/* ROM consts, lookup tables                                            */
/************************************************************************/
const uint16_t vsLookup[256] PROGMEM = { //Battery voltage in BCD
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

const uint16_t depthLookup[256] PROGMEM = { //Depth in BCD
	//Depth(m) = (ADC_READ / 5.06 - 0.493) / 3.2487 * 10
	0x0000,0x0000,0x0000,0x0000, 0x0000,0x0000,0x0000,0x0000, 0x0000,0x0000,0x0000,0x0000, 0x0000,0x0000,0x0000,0x0000,
	0x0000,0x0000,0x0000,0x0000, 0x0000,0x0000,0x0000,0x0000, 0x0000,0x0001,0x0007,0x0013, 0x0019,0x0025,0x0031,0x0038,
	0x0044,0x0050,0x0056,0x0062, 0x0068,0x0074,0x0080,0x0086, 0x0093,0x0099,0x0105,0x0111, 0x0117,0x0123,0x0130,0x0135,
	0x0141,0x0148,0x0154,0x0160, 0x0166,0x0172,0x0178,0x0184, 0x0190,0x0196,0x0203,0x0209, 0x0215,0x0221,0x0227,0x0233,
	
	0x0239,0x0245,0x0251,0x0258, 0x0264,0x0270,0x0276,0x0282, 0x0288,0x0294,0x0300,0x0306, 0x0313,0x0319,0x0325,0x0331,
	0x0337,0x0343,0x0349,0x0355, 0x0361,0x0368,0x0374,0x0380, 0x0386,0x0392,0x0398,0x0404, 0x0410,0x0416,0x0423,0x0429,
	0x0435,0x0441,0x0447,0x0453, 0x0459,0x0465,0x0471,0x0478, 0x0484,0x0490,0x0496,0x0502, 0x0508,0x0514,0x0520,0x0526,
	0x0532,0x0539,0x0545,0x0551, 0x0557,0x0564,0x0569,0x0575, 0x0581,0x0588,0x0594,0x0600, 0x0606,0x0612,0x0618,0x0624,
	
	0x0630,0x0636,0x0642,0x0649, 0x0655,0x0661,0x0667,0x0673, 0x0679,0x0685,0x0913,0x0975, 0x0704,0x0710,0x0716,0x0722,
	0x0728,0x0734,0x0740,0x0746, 0x0752,0x0759,0x0765,0x0771, 0x0777,0x0783,0x0789,0x0795, 0x0801,0x0807,0x0814,0x0820,
	0x0826,0x0834,0x0838,0x0844, 0x0850,0x0856,0x0862,0x0869, 0x0875,0x0881,0x0886,0x0893, 0x0899,0x0905,0x0911,0x0917,
	0x0924,0x0930,0x0936,0x0942, 0x0948,0x0954,0x0960,0x0966, 0x0972,0x0979,0x0984,0x0991, 0x0997,0x1003,0x1010,0x1015,
	
	0x1021,0x1027,0x1033,0x1040, 0x1046,0x1052,0x1058,0x1064, 0x1070,0x1076,0x1082,0x1088, 0x1095,0x1101,0x1107,0x1113,
	0x1119,0x1125,0x1131,0x1137, 0x1143,0x1150,0x1156,0x1162, 0x1168,0x1174,0x1180,0x1186, 0x1192,0x1198,0x1204,0x1211,
	0x1217,0x1223,0x1229,0x1235, 0x1241,0x1247,0x1253,0x1260, 0x1266,0x1272,0x1278,0x1284, 0x1290,0x1296,0x1302,0x1308,
	0x1315,0x1321,0x1327,0x1333, 0x1339,0x1345,0x1351,0x1357, 0x1363,0x1370,0x1376,0x1382, 0x1388,0x1394,0x1400,0x1406
	
};

const uint16_t pwmLookup[101] PROGMEM = {
	0x0000,
	0x028f, 0x051e, 0x07ae, 0x0a3d, 0x0ccc, 0x0f5c, 0x11eb, 0x147a, 0x170a, 0x1999,
	0x1c28, 0x1eb8, 0x2147, 0x23d6, 0x2666, 0x28f5, 0x2b84, 0x2e14, 0x30a3, 0x3333,
	0x35c2, 0x3851, 0x3ae1, 0x3d70, 0x3fff, 0x428f, 0x451e, 0x47ad, 0x4a3d, 0x4ccc,
	0x4f5b, 0x51eb, 0x547a, 0x5709, 0x5999, 0x5c28, 0x5eb7, 0x6147, 0x63d6, 0x6666,
	0x68f5, 0x6b84, 0x6e14, 0x70a3, 0x7332, 0x75c2, 0x7851, 0x7ae0, 0x7d70, 0x7fff,
	0x828e, 0x851e, 0x87ad, 0x8a3c, 0x8ccc, 0x8f5b, 0x91ea, 0x947a, 0x9709, 0x9999,
	0x9c28, 0x9eb7, 0xa147, 0xa3d6, 0xa665, 0xa8f5, 0xab84, 0xae13, 0xb0a3, 0xb332,
	0xb5c1, 0xb851, 0xbae0, 0xbd6f, 0xbfff, 0xc28e, 0xc51d, 0xc7ad, 0xca3c, 0xcccc,
	0xcf5b, 0xd1ea, 0xd47a, 0xd709, 0xd998, 0xdc28, 0xdeb7, 0xe146, 0xe3d6, 0xe665,
	0xe8f4, 0xeb84, 0xee13, 0xf0a2, 0xf332, 0xf5c1, 0xf850, 0xfae0, 0xfd6f, 0xffff
};

/************************************************************************/
/* Code segment                                                         */
/************************************************************************/

// ADC -------------------------------------------------------------------

//Polling ADC
uint8_t getADC(uint8_t channel) {
	ADMUX = ADC_BASEDATA_ADMUX | (channel<<MUX0); //Select ADC channel
	ADCSRA = ADC_BASEDATA_ADCSRA | (1<<ADSC); //Start ADC
	while ( ADCSRA & (1<<ADSC) ); //Wait (by polling) until ADC finished
	return ADCH; //Get ADC result (MSB 8 bits)
}

// UART ------------------------------------------------------------------

//Send a data, wait if buffer not empty
void sendSerialSync(uint8_t data) {
	while ( !(UCSR0A & (1<<UDRE0)) ); //Wait until last word send
	UDR0 = data;
}

//Request data, wait until data arrives
uint8_t requestSerialSync() {
	while ( !(UCSR0A & (1<<RXC0)) ); //Wait until data received
	return UDR0;
}

// Data format -----------------------------------------------------------

//BCD to binary
uint8_t d2b(uint8_t decimal) {
	return (((decimal & 0xF0) >> 4 ) * 10 ) + (decimal & 0x0F); //Normalizes 10s * 10 + 1s
}

//Binary to BCD
uint8_t b2d(uint8_t binary) {
	return ( (binary / 10) << 4 ) | binary % 10; //10s in higher nipple, 1s in lower nipple
}


// MAIN ROUTINES ---------------------------------------------------------

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
	DDRD = 0xFF;
	DDRC = 0x00;
	DDRB = 0xFF;
	
	//Init ADC
	ADMUX = ADC_BASEDATA_ADMUX;
	ADCSRA = ADC_BASEDATA_ADCSRA;
	DIDR0 = 0b00001111; //ADC channel 0 to 3 is for ADC only, disable the digital input buffer could reduce power consumption
	
	//Init I2C
	TWBR = 5; //SCL frequency = CPU frequency / (16 + 2 * TWBR) = 38.46kHz
	
	//Reset MPU module
	startI2C(); //Reset MPU
	setI2C(I2C_MPU_ID,I2C_MODE_WRITE);
	writeI2C(I2C_MPU_ADDR_PWRMAGMT1);
	writeI2C(0x81);
	stopI2C();
	
	//Reset MPU signal path
	startI2C();
	setI2C(I2C_MPU_ID,I2C_MODE_WRITE);
	writeI2C(I2C_MPU_ADDR_SIGNALPATHRESET);
	writeI2C(0x07);
	stopI2C();
	
	//Init MPU AUX sensor control (AK8963)
	startI2C(); 
	setI2C(I2C_MPU_ID,I2C_MODE_WRITE);
	writeI2C(I2C_MPU_ADDR_SLV0CTR);
	writeI2C(0x00|0x0C); //Read-only, slave I2C address is 0x0C
	writeI2C(0x03); //Read from address 0x03
	writeI2C(0x86); //Enable, no swap of group, register mode, no group, read 6 bytes
	stopI2C();
	
	//Init timer0: the ROV exchange data with operator-side console every 250ms
	TCCR0A = 0b00000010; //CTC mode with OCR0A
	TCCR0B = 0b00000101; //Clk source = System clock / 1024
	OCR0A = 0xF4; //250000 / 1024 = 244.14 = 0xF4  <-- The clk doesn't need to be very accurate
	TIMSK0 = 0b00000010; //Enable Timer0 Compare match A interrupt ISR
	
	//Init timer1: PWM generator
	TCCR1A = (2<<COM1A0) | (2<<COM1B0) | (2<<WGM10); //Fast PWM, set at 0x00, clear on compare match
	TCCR1B = (3<<WGM12) | (2<<CS10); //Mode 14 (Top at ICR1), Clk scaler = 8 (PWM = 1.25kHz)
	ICR1 = 100;
	
	//Init system done, task begin
	sei();
	for(;;) {}
	
	return 0;
}

//Main process <-- The main process of the ROV application, executed every 250ms
//All tasks in this ISR is guarantee to be done in 250ms
ISR (TIMER0_COMPA_vect) {
	
	auxPrescaler++;
	if (auxPrescaler < 3) //Operator-side issue? Slow down the exchange process.
		return;
	auxPrescaler = 0;
	
	//Some commonly used variables
	uint8_t checksum;
	
	/************************************************************************/
	/* STEP 1 - Polling packet from operator, if available and verified     */
	/************************************************************************/
	
	//Polling packet from operator-side console
	if (bufferRxIndex == 16) {
		checksum = 0; //Calculate checksum
		for (uint8_t i = 0; i < 16; i++)
			checksum += bufferRx[i];
		
		if (!checksum) { //Update only if ckecksum OK
			for (uint8_t i = 0; i < 15; i++)
				command[i] = bufferRx[i];
		}
	}
	
	//Reset UART buffer
	bufferTxIndex = 0;
	bufferRxIndex = 0;
	sei(); //Should allow UART interrupts
	
	/************************************************************************/
	/* STEP 2 - Get ROV status from sensors                                 */
	/************************************************************************/
	
	//From I2C - MPU9250
	uint16_t mpu[10]; //accelX, accelY, accelZ, temp, gyroX, gyroY, gyroZ, magX, magY, magZ
	uint8_t tempH, tempL;
	
	startI2C();
	setI2C(I2C_MPU_ID,I2C_MODE_WRITE);
	writeI2C(I2C_MPU_ADDR_DATA);
	startI2C();
	setI2C(I2C_MPU_ID,I2C_MODE_READ);
	
	for (uint8_t i = 0; i < 7; i++) {
		readI2C(&tempH,I2C_RETURN_ACK);
		readI2C(&tempL,I2C_RETURN_ACK);
		mpu[i] = (tempH << 8) | tempL;
	}
	
	for (uint8_t i = 7; i < 9; i++) {
		readI2C(&tempL,I2C_RETURN_ACK);
		readI2C(&tempH,I2C_RETURN_ACK);
		mpu[i] = (tempH << 8) | tempL;
	}
	
	readI2C(&tempL,I2C_RETURN_ACK);
	readI2C(&tempH,I2C_RETURN_NAK);
	mpu[9] = (tempH << 8) | tempL;
	stopI2C();
	
	//Calculate pitch
	double pitch = -atan( (double)((int16_t)mpu[1]) / (double)((int16_t)mpu[2]) ) / M_PI * 180.0; //tan-1(z-axis/y-axis) to degree, range -90 to 90
	uint16_t pitchInt;
	if (pitch < 0.0)
		pitchInt = (uint16_t)(pitch+360.0); //270-360 or 0 - 90
	else
		pitchInt = (uint16_t)pitch;
	uint16_t pitchBCD = ( b2d(pitchInt / 10) << 8 ) | ( b2d( pitchInt % 10 ) << 4 );
	
	//Calculate temperature
	int16_t temperature = (int16_t)( (double)mpu[3] / 33.387 + 210.0 ); //*10. temperature = 123 means 12.3C
	uint16_t tempreatureBCD;
	if (temperature < 0.0) {
		temperature = -temperature;
		tempreatureBCD = ( (0xD0 | (temperature/100)) << 8 ) | b2d( temperature % 100 ); //0xD for "-"
	}
	else {
		tempreatureBCD = ( (0xB0 | (temperature/100)) << 8 ) | b2d( temperature % 100 ); //0xB for "+"
	}
	
	//Calculate compass
	uint16_t compassInt = 0x0000;
	uint16_t compassBCD = 0x0000;
	
	//From ADC sensor
	uint16_t vsBCD = pgm_read_word(&(vsLookup[getADC(ADC_CH_VS)]));
	uint16_t depthBCD = pgm_read_word(&(depthLookup[getADC(ADC_CH_DEPTH)]));
	
	/************************************************************************/
	/* STEP 3 - Send ROV status to operator-side console                    */
	/************************************************************************/
	
	//Send the first word (SYNC), following words will be send by TxC interrupt
	//Note: Sending this signal takes 1/240s, the packet should be packed in this time
	//The variable systemLoad tells the time used by last main process
	//This data will not be used by operator-side console, but could help to analysis the system load
	UDR0 = systemLoad;
	
	bufferTx[0] = (uint8_t)(depthBCD & 0xFF);
	bufferTx[1] = (uint8_t)(depthBCD >> 8);
	bufferTx[2] = (uint8_t)(pitchBCD & 0xFF);
	bufferTx[3] = (uint8_t)(pitchBCD >> 8);
	bufferTx[4] = (uint8_t)(compassBCD & 0xFF);
	bufferTx[5] = (uint8_t)(compassBCD >> 8);
	bufferTx[6] = (uint8_t)(tempreatureBCD & 0xFF);
	bufferTx[7] = (uint8_t)(tempreatureBCD >> 8);
	bufferTx[8] = (uint8_t)(vsBCD & 0xFF);
	bufferTx[9] = (uint8_t)(vsBCD >> 8);
	/* Word 10 to 14 not used */
	
	//Send packet to operator
	checksum = 0;
	for (uint8_t i = 0; i < 15; i++)
		checksum -= bufferTx[i];
	bufferTx[15] = checksum; //The last word of the packet is checksum
	
	/************************************************************************/
	/* STEP 4 - While sending packet, analysis user command                 */
	/************************************************************************/
	
	uint8_t valve[12]; //Valve PWM, 0/255 duty cycle by default
	for (uint8_t i = 0; i < 12; i++)
		valve[i] = 0x00;
	
	if ( command[0]&0b00000110 ) //Forward and X-forward
		valve[AUX_VALVE_FW] = 0xFF;
	
	if ( command[0]&0b00000001 ) //Backward
		valve[AUX_VALVE_BW] = 0xFF;
	
	uint8_t commandLR = command[1] & 0b11001100;
	uint8_t commandUD = command[1] & 0b00110011;
	
	switch (commandLR) {
		case 0b00000100: //Turn right
			valve[AUX_VALVE_HR] = 0xFF;
			valve[AUX_VALVE_TL] = 0xFF;
			break;
		case 0b00001000: //Turn left
			valve[AUX_VALVE_HL] = 0xFF;
			valve[AUX_VALVE_TR] = 0xFF;
			break;
		case 0b01000000: //Shift right
			valve[AUX_VALVE_HR] = 0xFF;
			valve[AUX_VALVE_TR] = 0xFF;
			break;
		case 0b10000000: //Shift left
			valve[AUX_VALVE_HL] = 0xFF;
			valve[AUX_VALVE_TL] = 0xFF;
			break;
		case 0b01000100: //Shift right + turn right
			valve[AUX_VALVE_HR] = 0xFF;
			break;
		case 0b10001000: //Shift left + turn left
			valve[AUX_VALVE_HL] = 0xFF;
			break;
		case 0b01001000: //Shift right + turn left
			valve[AUX_VALVE_TR] = 0xFF;
			break;
		case 0b10000100: //Shift left + turn right
			valve[AUX_VALVE_TL] = 0xFF;
			break;
	}
	
	switch (commandUD) {
		case 0b00000001: //Pitch down
			valve[AUX_VALVE_HD] = 0xFF;
			valve[AUX_VALVE_TU] = 0xFF;
			break;
		case 0b00000010: //Pitch up
			valve[AUX_VALVE_HU] = 0xFF;
			valve[AUX_VALVE_TD] = 0xFF;
			break;
		case 0b00010000: //Shift down
			valve[AUX_VALVE_HD] = 0xFF;
			valve[AUX_VALVE_TD] = 0xFF;
			break;
		case 0b00100000: //Shift up
			valve[AUX_VALVE_HU] = 0xFF;
			valve[AUX_VALVE_TU] = 0xFF;
			break;
		case 0b00010001: //Shift down + pitch down
			valve[AUX_VALVE_HD] = 0xFF;
			break;
		case 0b00100010: //Shift up + pitch up
			valve[AUX_VALVE_HU] = 0xFF;
			break;
		case 0b00010010: //Shift down + pitch up
			valve[AUX_VALVE_TD] = 0xFF;
			break;
		case 0b00100001: //Shift up + pitch down
			valve[AUX_VALVE_TU] = 0xFF;
			break;
	}
	
	
	/************************************************************************/
	/* STEP 5 - A/P: Modify user command if AP enabled                      */
	/************************************************************************/
	
	if ( command[2] & 0b01000000 ) { //A/P Direction
		/* Not implemented */
	}
	
	if ( command[2] & 0b00100000 ) { //A/P Pitch
		//Current pitch = (double) pitch, range -90 to 90
		uint16_t pitchCommand = d2b(command[9]) * 10 + (command[8]>>4);
		double pitchDest = (double)pitchCommand;
		if (pitchDest > 180.0)
			pitchDest -= 360.0;
		
		if (pitchDest > pitch) { //Should pitch up
			double diff = pitchDest - pitch;
			if (diff > AP_PITCH_DEADZONE) {
				if (diff > AP_PITCH_DEADZONE + 256 / AP_PITCH_MAG) {
					valve[AUX_VALVE_HU] = 0xFF;
					valve[AUX_VALVE_HD] = 0x00;
					valve[AUX_VALVE_TU] = 0x00;
					valve[AUX_VALVE_TD] = 0xFF;
				}
				else {
					uint8_t valvePWM = ( (uint8_t)diff - AP_PITCH_DEADZONE ) * AP_PITCH_MAG;
					valve[AUX_VALVE_HU] = valvePWM;
					valve[AUX_VALVE_HD] = 0x00;
					valve[AUX_VALVE_TU] = 0x00;
					valve[AUX_VALVE_TD] = valvePWM;
				}
			}
		}
		
		else { //Should pitch down
			double diff = pitch - pitchDest;
			if (diff > AP_PITCH_DEADZONE) {
				if (diff > AP_PITCH_DEADZONE + 256 / AP_PITCH_MAG) {
					valve[AUX_VALVE_HU] = 0x00;
					valve[AUX_VALVE_HD] = 0xFF;
					valve[AUX_VALVE_TU] = 0xFF;
					valve[AUX_VALVE_TD] = 0x00;
				}
				else {
					uint8_t valvePWM = ( (uint8_t)diff - AP_PITCH_DEADZONE ) * AP_PITCH_MAG;
					valve[AUX_VALVE_HU] = 0x00;
					valve[AUX_VALVE_HD] = valvePWM;
					valve[AUX_VALVE_TU] = valvePWM;
					valve[AUX_VALVE_TD] = 0x00;
				}
			}
		}
	}
	
	if ( command[2] & 0b10000000 ) { //A/P Depth. A/P Pitch will be overwritten by A/P Depth
		uint16_t depthReal = d2b(depthBCD>>8) * 100 + d2b((uint8_t)depthBCD);
		uint16_t depthDest = d2b(command[7]) * 100 + d2b(command[6]);
		
		if (depthDest > depthReal) { //Should go deeper
			double diff = depthDest - depthReal;
			if (diff > AP_DEPTH_DEADZONE) {
				if (diff > AP_DEPTH_DEADZONE + 256 / AP_DEPTH_MAG) {
					valve[AUX_VALVE_HU] = 0x00;
					valve[AUX_VALVE_HD] = 0xFF;
					valve[AUX_VALVE_TU] = 0x00;
					valve[AUX_VALVE_TD] = 0xFF;
				}
				else {
					uint8_t valvePWM = ( (uint8_t)diff - AP_DEPTH_DEADZONE ) * AP_DEPTH_MAG;
					valve[AUX_VALVE_HU] = 0x00;
					valve[AUX_VALVE_HD] = valvePWM;
					valve[AUX_VALVE_TU] = 0x00;
					valve[AUX_VALVE_TD] = valvePWM;
				}
			}
		}
		
		else {
			double diff = depthReal - depthDest;
			if (diff > AP_DEPTH_DEADZONE) {
				if (diff > AP_DEPTH_DEADZONE + 256 / AP_DEPTH_MAG) {
					valve[AUX_VALVE_HU] = 0xFF;
					valve[AUX_VALVE_HD] = 0x00;
					valve[AUX_VALVE_TU] = 0xFF;
					valve[AUX_VALVE_TD] = 0x00;
				}
				else {
					uint8_t valvePWM = ( (uint8_t)diff - AP_DEPTH_DEADZONE ) * AP_DEPTH_MAG;
					valve[AUX_VALVE_HU] = valvePWM;
					valve[AUX_VALVE_HD] = 0x00;
					valve[AUX_VALVE_TU] = valvePWM;
					valve[AUX_VALVE_TD] = 0x00;
				}
			}
		}
	}
	
	/************************************************************************/
	/* STEP 6 - Send command to motors and valves                           */
	/************************************************************************/
	
	//AUX controller
	startI2C();
	setI2C(I2C_AUX_ID,I2C_MODE_WRITE);
	checksum = 0;
	for (uint8_t i = 0; i < 12; i++) {
		checksum -= valve[i];
		writeI2C(valve[i]);
	}
	writeI2C(checksum);
	stopI2C();
	
	//LED
	if ( command[2] & 0b00001000 )
		PORTD |= 1 << 3; //Turn on PD3
	else
		PORTD &= 0xFF ^ (1<<3); //Turn off PD3
	
	if ( command[2] & 0b00010000 )
		PORTD |= 1 << 4; //Turn on PD3
	else
		PORTD &= 0xFF ^ (1<<4); //Turn off PD3
		
	
	//Pump and C_PWM (PWM generator of timer1)
	OCR1A = d2b(command[4]); //Engine on PB1 (pin15)
	OCR1B = d2b(command[5]); //C_PWM on PB2 (pin16)
	
	
	/************************************************************************/
	/* STEP EXTRA - System load analysis                                    */
	/************************************************************************/
	systemLoad = TCNT0; //System load = Current timer content / top * 100% = 100% * ((float)TCNT0 / (float)OCR0A)
}

ISR (USART_TX_vect) {
	if (bufferTxIndex < 16) //Send if index in buffer size range
	UDR0 = bufferTx[bufferTxIndex++];
}

ISR (USART_RX_vect) {
	if (bufferRxIndex < 16) //Prevent buffer overflow
	bufferRx[bufferRxIndex++] = UDR0;
}


/************************************************************************/
/* Known issues                                                         */
/************************************************************************/
// - When supply with low voltage, the reading of ADC (supply voltage monitor) has a very inaccurate result.
