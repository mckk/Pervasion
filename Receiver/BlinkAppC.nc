#include <message.h>

configuration BlinkAppC
{
}
implementation
{
  components MainC, BlinkC, LedsC;

  components ActiveMessageC;

  components new AMSenderC(AM_DATAMSG) as DataSender;
  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  ///* Solution 3. Adding Serial stack components.******/
  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_SERIALMSG) as SerialSender;
  components new SerialAMReceiverC(AM_SERIALMSG) as SerialReceiver; 

  BlinkC -> MainC.Boot;

  BlinkC.Leds -> LedsC;


  BlinkC.AMControl -> ActiveMessageC;
  BlinkC.DataPacket -> DataSender;
  BlinkC.DataSend -> DataSender;
  BlinkC.DataReceive -> DataReceiver;


  BlinkC.SerialAMControl -> SerialActiveMessageC;
  BlinkC.SerialPacket -> SerialSender;
  BlinkC.SerialSend -> SerialSender;
  BlinkC.SerialReceive -> SerialReceiver;
}

