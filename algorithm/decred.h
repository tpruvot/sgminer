#ifndef DECRED_H
#define DECRED_H

#include "miner.h"

#ifdef __cplusplus
extern "C"{
#endif

void precalc_hash_decred(dev_blk_ctx *blk, uint32_t *state, uint32_t *data);

void decred_regenhash(struct work *work);
int  decred_test(unsigned char *pdata, const unsigned char *ptarget, uint32_t nonce);

#ifdef __cplusplus
}
#endif

#endif /* DECRED_H */