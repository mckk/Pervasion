#include <message.h>

configuration ReceiverAppC
{
}
implementation
{
  enum {
    MSG_QUEUE_SIZE     = 4,
  };


  components MainC, ReceiverC, LedsC;

  //Timer for sync messsages
  components new TimerMilliC() as SyncTimer;

  //AM controller
  components ActiveMessageC;

  components new AMReceiverC(AM_DATAMSG) as DataReceiver;

  components new AMReceiverC(AM_FIREMSG) as FireMsgReceiver;

  components new AMReceiverC(AM_TIMERRESTARTMSG) as TimerMsgReceiver;
  components new AMSenderC(AM_TIMERRESTARTMSG) as TimerMsgSender;

  //Serial controller
  components SerialActiveMessageC;

  components new SerialAMSenderC(AM_SERIALMSG) as SerialSender;

  // Queues
  components new QueueC(FireMsg, MSG_QUEUE_SIZE) as FireQueue;
  components new QueueC(DataMsg, MSG_QUEUE_SIZE) as DataQueue;

  ReceiverC -> MainC.Boot;
  ReceiverC.Leds -> LedsC;
  ReceiverC.SyncTimer -> SyncTimer;
  
  ReceiverC.AMControl      -> ActiveMessageC;
  ReceiverC.DataReceive    -> DataReceiver;
  ReceiverC.FireMsgReceive -> FireMsgReceiver;
  ReceiverC.TimerPacket    -> TimerMsgSender;
  ReceiverC.TimerSend      -> TimerMsgSender;
  ReceiverC.TimerReceive   -> TimerMsgReceiver;

  ReceiverC.SerialAMControl -> SerialActiveMessageC;
  ReceiverC.SerialPacket    -> SerialSender;
  ReceiverC.SerialSend      -> SerialSender;

  ReceiverC.FireQueue       -> FireQueue;
  ReceiverC.DataQueue       -> DataQueue;
}

