The ROV and the controller (operator, call it controller here) will comunicate every 1/4s.

There is a timer on the ROV, that overflow every 250ms.
When the timer on the ROV overflow, the ROV will do these:
	1. Check data in the receiver buffer (verify the data by checksum).
	2. If the data is verified, the ROV will update all the app SFR; otherwise, skip this step.
	3. The ROV will flush both receiver and transmitter buffer.
	4. The ROV will scan all the app SFR, and put the value into transmitter buffer.
	5. The ROV will first send a 0x00 byte (synch), then send all data in the buffer.

The package looks like this
	ROV --> Controller	0x00 - Data - Data - Data - ... - Data - Checksum
		(First data)
		FB_VALVE	LR_VALVE	UD_VALVE	LED		GPIO
		ENGINE_POWER	PRESSURE_REAL_L	PRESSURE_REAL_H PRESSURE_DEST_L	PRESSURE_DEST_H
		PITCH_REAL_L	PITCH_REAL_H	PITCH_DEST_L	PITCH_DEST_H	COMPASS_REAL_L
		COMPASS_REAL_H	COMPASS_DEST_L	COMPASS_DEST_H	TEMPERATURE_L	TEMPERATURE_H
		BAT_VLOTAGE_L	BAT_VLOTAGE_H
	Controller --> ROV	Data - Data - Data - ... - Data - Checksum
		(First data)
		FB_VALVE	LR_VALVE	UD_VALVE	LED		GPIO
		ENGINE_POWER	PRESSURE_DEST_L	PRESSURE_DEST_H	PITCH_DEST_L	PITCH_DEST_H
		COMPASS_DEST_L	COMPASS_DEST_H

About synch:
	There is different between the ROV's clock and Controller's clock. The error is very small, it is fine for short time operation; however, if the error is accumulated by time, these will be a big issue.
	To deal with the synch problem, the ROV and Controller will do so: (ROV acts as master clock)
	1. The ROV will send package to Controller via UART every 1/4s, and the first word in the package is always 0x00.
	2. The Controller will setup a timer that overflow x ms. x should be far less than 1/4s and far large than the time between 2 UART receiving. Furthermore, there is a flag, call it FLAG here; when timer overflow, the FLAG will be clear.
	3. Everytime when the Controller receive a word from the ROV, the Controller will reset the timer.
	4. When there is a 0x00 coming from the ROV, if FLAG is not set, synchnize the Controller and set FLAG. If FLAG is already set, do nothing.
	This means:
	0x00 is the synch request. If the Controller see that, it means the the timer on the ROV has pass 1/4s.
	There may be 0x00 data in the package. Because there is a flag set before, the Controller knows this 0x00 is a data instead of synch request.
	If the 0x00 synch request is lost, the Controller will not synch with the ROV, and the entire package will be ignor (package length wrong). As long as the next package arrive successfully, the Controller will synch with the ROV then.
		If the first data word of the package is 0x00 (a data 0x00 just after the synch 0x00), the ROV will synch to a wrong time; however, when next package arrive, the timer on the Controller will be re-synch and coorect.