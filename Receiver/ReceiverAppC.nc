#include <message.h>

configuration ReceiverAppC
{
}
implementation
{
  components MainC, ReceiverC, LedsC;

  components ActiveMessageC;

  components new AMSenderC(AM_DATAMSG) as DataSender;
  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  ///* Solution 3. Adding Serial stack components.******/
  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_SERIALMSG) as SerialSender;
  components new SerialAMReceiverC(AM_SERIALMSG) as SerialReceiver; 

  ReceiverC -> MainC.Boot;

  ReceiverC.Leds -> LedsC;


  ReceiverC.AMControl -> ActiveMessageC;
  ReceiverC.DataPacket -> DataSender;
  ReceiverC.DataSend -> DataSender;
  ReceiverC.DataReceive -> DataReceiver;


  ReceiverC.SerialAMControl -> SerialActiveMessageC;
  ReceiverC.SerialPacket -> SerialSender;
  ReceiverC.SerialSend -> SerialSender;
  ReceiverC.SerialReceive -> SerialReceiver;
}

