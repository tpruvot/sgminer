#ifndef VELTOR_H
#define VELTOR_H

#include "miner.h"

extern int veltor_test(unsigned char *pdata, const unsigned char *ptarget,
			uint32_t nonce);
extern void veltor_regenhash(struct work *work);

#endif
