# ROV tech document - Mechanical structure


## Introduction

In the design, the design group is going to build a 40 centimeter long ROV which can operate at 40 meter depth. The design group will use a high power pump to move the ROV and use a 10 meter long cable to connect the tail of the ROV and control board, which means it can work at around 10 meter depth.


## Design

### Design parameters

The design group build this ROV because we are interested in design the underwater vehicle. In the design, the design group is going to build a 40 centimeter long ROV which can operate at 40 meter depth. In order to satisfy the requirement, the design group use 40 centimeter long plastic pipe for the body of the ROV. The pipe can hold 200kPa pressure. The cross section of top and bottom of the ROV should big enough to put the main control board in. The design group are going to use the control board to control the valves and use nozzles to operate our ROV under water.

## Implementation

### Headhub

At the head of the ROV, the design group have a camera which is connected with main control center. The camera can send the image signal to the control board and we can see the underwater image by the camera. We also have a headlight and two led at the top of the ROV. The headlight will illuminate the front which can help camera have better image. Next, the design group need to seal the head of ROV. the design group use resin and glue to seal the top of ROV, because once the design group finish build the top of the ROV, the design group don’t need open it again.

### Body

The design group use a high power pump to move the whole ROV. The pump first connect to 10 different valves. The valves is also connect to the main control board. There are 8 nozzles in our design. 4 is on the top of the ROV and 4 is on the bottom of the ROV. The nozzles must exactly stay on the 90, 180,270,360 degrees, because ROV will use these nozzles to do all the operating. For example, if the nozzle has some offset, the ROV will move to the wrong direction. To connect the nozzles and valves, the design group use straps connect all the valves and the body of the ROV, and then the design group use hose to connect the valves and nozzles. When the ROV moving, the pump will push the pressure form valves to the nozzles. Then the nozzles will push the ROV in to right direction.

### Tail hub

For the tail sealing, the design group use a mechanical way to seal it. The design group use the same size plastic cap to seal the bottom of the ROV, because when the design group need to change something, we can open the ROV easily. The design group use a 10 meter long cable to connect the tail of the ROV and control board,

### Trim

After the design group connect all the parts, there is one more things they need to do is to measure the center of buoyancy and the center of the gravity. In the design the center of gravity should be a little lower than the center of the buoyancy and both of them should around the center of our ROV. The design group have to satisfy the relationship between the buoyancy and the gravity, because when they put the ROV in to test. The ROV have to not only immerse in the water, but also stay in a proper depth in the water. Once the power turn on, they can use the top of the nozzle push pressure and the ROV will dive. If the ROV has some part which is not immersion in the water. The top nozzle will push pressure in to the air and the ROV cannot dive even it have power. Therefore it is necessary to adjust the center of buoyancy and gravity. In the design, the design group can move the position of the valves and pump to adjust the center of gravity to the right position. 



## Experiment

Electric part

The design group test the electric part by using the output LED lights. For example, if they want to turn right, the right LED should be up when they push the button on the control board. If the right LED is not up, it means the control system still has some problems. 

Sealing and pump

After the design group finish our design, the first thing they need to do is to test the sealing of our ROV. The design group put our main control board outside, and put our ROV in the bathtub which has 20 centimeter depth. They can open the pump with a 12 V battery and see whether the ROV move like they thinking or not. Then the design group takeout our ROV and check the inside. They find that all the sealing is good. There isn’t any water in the ROV inside.

Test Result

After testing all the things, the design group finish the design and use the bathtub for the final test. In the final test, the ROV works pretty well in the bathtub. It can dive 20 centimeter depth and all the functions work well. The auto-pilot mode also works well in the bathtub.

WaterTankResult

Then the design group test our ROV in the water tank. The water tank is 2 meters depth. The electric part is still working well. However, the difference between the water tank and the bathtub is that the connect cable is too heavy when they use the long cable. The heavy cable change the center of the gravity of our ROV and let it dive fast before they open our power. Then the design group use some foam to increase the buoyancy of our ROV. They try several times with different amounts of foam and finally the ROV can stay in the 1 meter depth. However, they open the power supply of the ROV and the ROV is not working. Then they open the ROV and find that the ROV has leaking problem because of the 1 meter water pressure. Fortunately, the water is running water and the control board is not burn out.

Improvement

There are still several parts that can be improved in the ROV design. Although the electric system part works well, they still have some problems in the mechanical system. When the design group tested their design in the bathtub, all the function was working. However, when they test in the water tank, their ROV have leaking issue due to the pressure. As a result, their sealing method is something can be improved, such as using wax to seal the cap. Additionally, they have a lot of surface mounted valves, which brings up the wiring issue. For improvement, the design group could use a quick-connect jacket to help us disconnect and reconnect the actuators easier when they need to modify the ROV. Furthermore, the design group’s pump is not powerful enough through the test. The pump worked well by itself; however, after they connect the pump with hose and valves, the resistance of the hose reduces the output pressure of our direction control nozzles.

Now, they established a basic auto pilot function. The ROV can maneuver automatically if the error between the auto pilot configuration and the actual status provided by the sensor is larger than the threshold level. In the future, they can use some better algorithm such as PID controller or State Space controller to improve the control performance. The design group could also use the video signal recorded by the camera to implement video processing functions, such as line following and object detection.

