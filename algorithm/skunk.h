#ifndef SKUNKHASH_H
#define SKUNKHASH_H

#include "miner.h"

void precalc_hash_skunk(dev_blk_ctx *blk, uint32_t *midstate, uint32_t *pdata);
void skunk_regenhash(struct work *work);

#endif
