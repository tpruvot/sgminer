#ifndef TRIBUS_H
#define TRIBUS_H

#include "miner.h"

extern int tribus_test(unsigned char *pdata, const unsigned char *ptarget,
			uint32_t nonce);
extern void tribus_regenhash(struct work *work);

#endif /* TRIBUS_H */
