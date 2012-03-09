#include <message.h>

configuration SenderAppC
{
}
implementation
{
  components MainC, SenderC, LedsC;
  components new TimerMilliC() as SensorTimer;
  components new TimerMilliC() as GreenLedTimer;

  components new TempC() as Temp_Sensor;
  components new PhotoC() as Lux_Sensor;

  components ActiveMessageC;

  components new AMSenderC(AM_DATAMSG) as DataSender;
  components new AMSenderC(AM_FIREMSG) as FireMsgSender;
  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  components new AMReceiverC(AM_TIMERRESTARTMSG) as TimerMsgReceiver;

  SenderC -> MainC.Boot;

  SenderC.SensorTimer -> SensorTimer;
  SenderC.GreenLedTimer -> GreenLedTimer;

  SenderC.Leds -> LedsC;
  SenderC.Temp_Sensor -> Temp_Sensor;
  SenderC.Lux_Sensor -> Lux_Sensor;

  SenderC.AMControl -> ActiveMessageC;
  SenderC.DataPacket -> DataSender;
  SenderC.DataSend -> DataSender;
  SenderC.FireMsgSend -> FireMsgSender;
  SenderC.DataReceive -> DataReceiver;

  SenderC.TimerMsgReceive -> TimerMsgReceiver;
}

