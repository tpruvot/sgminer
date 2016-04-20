/*
 * Decred Blake256-14 180 bytes hash
 *
 * implemented by tpruvot 02-2016
 */

#include <stddef.h>
#include <string.h>
#include <limits.h>
#include <stdint.h>

#include <sph/sph_blake.h>
#include "decred.h"

/*
* Encode a length len/4 vector of (uint32_t) into a length len vector of
* (unsigned char) in big-endian form.  Assumes len is a multiple of 4.
*/
static inline void
be32enc_vect(uint32_t *dst, const uint32_t *src, uint32_t len)
{
	uint32_t i;
	for (i = 0; i < len; i++)
		dst[i] = htobe32(src[i]);
}

inline void decredhash(void *state, const void *input)
{
	sph_blake256_context ctx_blake;

	sph_blake256_set_rounds(14);

	sph_blake256_init(&ctx_blake);
	sph_blake256(&ctx_blake, input, 180);
	sph_blake256_close(&ctx_blake, state);
	//applog_hex((void*)input, 16);
}

void precalc_hash_decred(dev_blk_ctx *blk, uint32_t *state, uint32_t *pdata)
{
	uint32_t data[48];
	sph_blake256_context ctx_blake;
	char *cdata = (char*)pdata;

	//memcpy(data, pdata, 180);

	sph_blake256_set_rounds(14);
	sph_blake256_init(&ctx_blake);
	sph_blake256(&ctx_blake, pdata, 128);

	blk->ctx_a = ctx_blake.H[0];
	blk->ctx_b = ctx_blake.H[1];
	blk->ctx_c = ctx_blake.H[2];
	blk->ctx_d = ctx_blake.H[3];
	blk->ctx_e = ctx_blake.H[4];
	blk->ctx_f = ctx_blake.H[5];
	blk->ctx_g = ctx_blake.H[6];
	blk->ctx_h = ctx_blake.H[7];

	be32enc_vect(&data[32], &pdata[32], 13);
	blk->cty_a = data[32];
	blk->cty_b = data[33];
	blk->cty_c = data[34];
/*	blk->cty_d = data[35] = nonce */
	blk->cty_d = data[36];
	blk->cty_e = data[37];
	blk->cty_f = data[38];
	blk->cty_g = data[39];
	blk->cty_h = data[40];
	blk->cty_i = data[41];
	blk->cty_j = data[42];
	blk->cty_k = data[43];
	blk->cty_l = data[44];
}

void decred_regenhash(struct work *work)
{
	uint32_t data[45];
	uint32_t *nonce = (uint32_t *)(work->data + 140);
	uint32_t *ohash = (uint32_t *)(work->hash);

	memcpy(data, work->data, 180);
	data[35] = swab32(data[35]);
	if (work->stratum && !data[37])
		applog(LOG_WARNING, "work has empty extradata!");
	decredhash(ohash, data);
	*nonce = data[35];
}

#if 0
bool scanhash_decred(struct thr_info *thr, const unsigned char __maybe_unused *pmidstate,
		     unsigned char *pdata, unsigned char __maybe_unused *phash1,
		     unsigned char __maybe_unused *phash, const unsigned char *ptarget,
		     uint32_t max_nonce, uint32_t *last_nonce, uint32_t n)
{
	uint32_t data[48] = { 0 };
	uint32_t *nonce = (uint32_t*) (pdata + 140);
	uint32_t Htarg = le32toh(((const uint32_t *)ptarget)[6]);
	bool ret = false;

	if (pdata[0])
		memcpy(data, pdata, 180);
	else
		be32enc_vect(data, (const uint32_t *)pdata, 45);

	while(1) {
		uint32_t ostate[8];

		*nonce = ++n;
		data[35] = (n);
		decredhash(ostate, data);

		applog(LOG_DEBUG, "data6 %08x data7 %08x", data[6], data[7]);

		if (unlikely(ostate[6] <= Htarg) && !ostate[7]) {
			((uint32_t *)pdata)[35] = htobe32(n);
			*last_nonce = n;
			ret = true;
			break;
		}

		if (unlikely((n >= max_nonce) || thr->work_restart)) {
			*last_nonce = n;
			break;
		}
	}

	return ret;
}
#endif
