#ifndef SKEIN2_H
#define SKEIN2_H

#include "miner.h"

extern int skein2_test(unsigned char *pdata, const unsigned char *ptarget,
			uint32_t nonce);
extern void skein2_regenhash(struct work *work);

#endif
