//#ifndef FIREMSG_H
#define FIREMSG_H

enum {
	AM_FIREMSG		= 231,
    FIREMSG_HEADER  = 0x99,
};

typedef nx_struct FireMsg {
    nx_uint8_t srcid;
} FireMsg;
