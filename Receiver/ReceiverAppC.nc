#include <message.h>

configuration ReceiverAppC
{
}
implementation
{
  components MainC, ReceiverC, LedsC;

  components new TimerMilliC() as SyncTimer;

  components ActiveMessageC;
  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  components SerialActiveMessageC;
  components new SerialAMSenderC(AM_SERIALMSG) as SerialSender;

  components new AMReceiverC(AM_FIREMSG) as FireMsgReceiver;

  components new AMSenderC(AM_TIMERRESTARTMSG) as TimerMsgSender;

  ReceiverC -> MainC.Boot;

  ReceiverC.SyncTimer -> SyncTimer;

  ReceiverC.Leds -> LedsC;

  ReceiverC.AMControl -> ActiveMessageC;
  ReceiverC.DataReceive -> DataReceiver;

  ReceiverC.SerialAMControl -> SerialActiveMessageC;
  ReceiverC.SerialPacket -> SerialSender;
  ReceiverC.SerialSend -> SerialSender;

  ReceiverC.FireMsgReceive -> FireMsgReceiver;
  
  ReceiverC.TimerPacket -> TimerMsgSender;
  ReceiverC.TimerSend -> TimerMsgSender;
}

