//## Solution sheet for tutorial 3: (Senser Node Code) of the wireless sensor network
//## programing module of the pervasive systems course.

#include <message.h>

configuration BlinkAppC
{
}
implementation
{
  components MainC, BlinkC, LedsC;
  components new TimerMilliC() as SensorTimer;
  components new TimerMilliC() as GreenLedTimer;

  components new TempC() as Temp_Sensor;
  components new PhotoC() as Lux_Sensor;

  components ActiveMessageC;

  components new AMSenderC(AM_DATAMSG) as DataSender;
  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  BlinkC -> MainC.Boot;

  BlinkC.SensorTimer -> SensorTimer;
  BlinkC.GreenLedTimer -> GreenLedTimer;

  BlinkC.Leds -> LedsC;
  BlinkC.Temp_Sensor -> Temp_Sensor;
  BlinkC.Lux_Sensor -> Lux_Sensor;

  BlinkC.AMControl -> ActiveMessageC;
  BlinkC.DataPacket -> DataSender;
  BlinkC.DataSend -> DataSender;
  BlinkC.DataReceive -> DataReceiver;
}

