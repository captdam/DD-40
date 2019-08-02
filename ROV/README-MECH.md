# ROV tech document - Mechanical structure


## Introduction

In the design, the design group is going to build a 40-centimeter-long ROV which can operate at 10-meter depth. The design group will use a high-power pump to move the ROV and use a 10-meter-long cable to connect the tail of the ROV and control board, which means it can work at around 10-meter depth.


## Design

### Design parameters

As mentioned above, the ROV should be able to operate under 10 meters deep of water. In order to satisfy the requirement, the design group use Schedule 40 PVC pipe for the body of the ROV. The pipe can hold 2MPa pressure, which is equivalent to the pressure of 200 meters deep of water. The cross section of ROV should big enough to contain the control board, which is used to control the valves.

To maneuver the ROV under water, valve-controlled nozzles are used. For example, if the ROV need to float, the bottom of the head and tail nozzles will push pressure to the bottom direction and then the nozzles will give ROV reacting force which direction is up, and then, the ROV will float. Another example is about how to pitch up. For the pitch up, it will use the top of tail nozzle and the bottom of head nozzle. When the valves get the signal from the control system, the head bottom nozzle will push pressure to the bottom and the top of tail nozzle will push the pressure to the top. Then the reacting force will let the ROV pitch up.

## Implementation

![ROV](https://raw.githubusercontent.com/captdam/DD-40/master/ROV/rov.jpg "ROV")

### Headhub

At the head of the ROV, the design group have a camera which is connected with main control center. The camera can send the image signal to the control board and we can see the underwater image by the camera. We also have a headlight and two navigation led at the head of the ROV. The headlight will illuminate the front which can help camera have better image.

Because once the design group finish builds the top of the ROV, the design group don’t need open it again. Therefore, the design group need to seal the head of ROV. the design group use resin and silicon glue to seal the top of ROV. In fact, silicon glue is sufficient for sealing; however, using resin not only seal the ROV, but also reforce the structure.

### Body

The design group use a high power pump to move the whole ROV. The pump first connect to 10 different valves. The valves is also connect to the main control board. There are 8 nozzles in our design. 4 is on the head of the ROV and 4 is on the tail of the ROV. The nozzles must exactly stay on the 90, 180,270,360 degrees, because ROV will use these nozzles to do all the operating. For example, if the nozzle has some offset, the ROV will move to the wrong direction.

To connect the nozzles and valves, the design group use straps connect all the valves and the body of the ROV, and then the design group use hose to connect the valves and nozzles. When the ROV moving, the pump will deliver pressure to the nozzles through valve. Then the nozzles will push the ROV in to right direction.

### Tail hub

The tail hub comes with control circuit board, communication cable and depth sensor. The control circuit board is located at the inside od the tail hub, the depth sensor and the communication cable is located outside of the tail hub.

For the tail sealing, the design group use a mechanical way to seal it. instead of using PVC pipe ending, cap is used, so the ROV could be open easily. The disadvantage is that the tail of ROV may have leaking problem when the ROV go some very depth because the tail sealing only use the mechical way to seal. 
### Trim

After the design group connect all the parts, there is one more things they need to do is to measure the center of buoyancy and the center of the gravity.

In the design the center of gravity should be a little lower than the center of the buoyancy and both of them should around the center of ROV. The design group have to satisfy the relationship between the buoyancy and the gravity, because when they put the ROV in to test. If the center of gravity is not around of the ROV, the head and tail will give different force when the ROV is operating, because the distance of torque is not same between head and tail and the ROV may have some unexpected moving during the test. 

Another thing is that the ROV have to not only immerse in the water, but also stay in a proper depth in the water. Once the power turn on, they can use the top of the nozzle push pressure and the ROV will dive. If the ROV has some part which is not immersion in the water. The top nozzle will push pressure in to the air and the ROV cannot dive even it have power. Therefore it is necessary to adjust the center of buoyancy and gravity.

In the design, the design group can move the position of the valves and pump to adjust the center of gravity to the desired position. Althrough it is possible to using calculation to find out the porper instalation position of valves and pump, but it is requires too much calculation. Instead, the test-retry method has the highest design effiency.



## Experiment

### Sealing
After the design group finish our design, the first thing they need to do is to test the sealing of our ROV. The design group put our main control board outside, and put our ROV in the bathtub which has 20 centimeter depth. No water is found inside the ROV's body after the recover the ROV from water.

### Actuactors

They can turn on the pump with a 12 V battery and see whether the ROV move like they thinking or not. The result is ROV can move to every direction successful with appropriate speed. For example, if we open the turn right switch, the head left nozzle and the tail right nozzle will push pressure in to the water, and the ROV turn right in a few second. Our test is successful. 

### Stage 1 test

The stage 1 test is running in the bathtub. After testing all the system individuly, the design group finish the design and assembly the ROV for final test in the bathtub. In this test, the ROV works pretty well. It can dive 20 centimeter depth and all the functions work well. The auto-pilot mode also works well in the bathtub.

### Stage 2 test

The stage 1 test is running in the water tank at the the university lab.

Then the design group test our ROV in the water tank. The water tank is 2 meters depth. The electric part is still working well. However, the difference between the water tank and the bathtub is that the connect cable is too heavy when they use the long cable. The heavy cable change the center of the gravity of our ROV and let it dive fast before they open our power. Then the design group use some foam to increase the buoyancy of our ROV.

They try several times with different amounts of foam and finally the ROV can stay in the 1 meter depth. However, due to pressure issue and inporper installation of the tail cap, the ROV facing leaking issue. In the stage 2 test, the ROV fails due to mechnical issue.

## Improvement

There are still several parts that can be improved in the ROV design.

Although the electric system part works well, they still have some problems in the mechanical system. When the design group tested their design in the bathtub, all the function was working. However, when they test in the water tank, their ROV have leaking issue due to the pressure. As a result, their sealing method is something can be improved, such as using wax to seal the cap.

Additionally, they have a lot of surface mounted valves, which brings up the wiring issue. For improvement, the design group could use a quick-connect jacket to help us disconnect and reconnect the actuators easier when they need to modify the ROV. Furthermore, the design group’s pump is not powerful enough through the test. The pump worked well by itself; however, after they connect the pump with hose and valves, the resistance of the hose reduces the output pressure of our direction control nozzles.
