#define TIMERRESTARTMSG_H

enum {
    AM_TIMERRESTARTMSG      = 189,
    TIMERRESTARTMSG_HEADER  = 0x99,
};

typedef nx_struct TimerRestartMsg {
        nx_uint8_t srcid;
} TimerRestartMsg;
