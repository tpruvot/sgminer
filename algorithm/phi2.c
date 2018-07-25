/*-
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR AND CONTRIBUTORS ``AS IS'' AND
 * ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS
 * OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT
 * LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY
 * OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
 * SUCH DAMAGE.
 */

#include "config.h"
#include "miner.h"

#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "algorithm/lyra2.h"
#include "sph/sph_skein.h"
#include "sph/sph_jh.h"
#include "sph/sph_cubehash.h"
#include "sph/sph_fugue.h"
#include "sph/sph_echo.h"
#include "sph/gost_streebog.h"

#define AS_U64(addr)   *((uint64_t*)(addr))

void precalc_hash_cube(dev_blk_ctx *blk, uint32_t *midstate, uint32_t *pdata)
{
	uint32_t data[16];
	sph_cubehash512_context ctx_cubehash;

	flip64(data, pdata);
	sph_cubehash512_init(&ctx_cubehash);
	sph_cubehash512(&ctx_cubehash, data, 64);
	if (midstate) memcpy(midstate, &ctx_cubehash.state, 32 * sizeof(uint32_t));
}

void phi2_hash(void *state, const void *input)
{
	unsigned char hash[64];
	unsigned char hashLyra[64];

	sph_cubehash512_context ctx_cubehash;
	sph_jh512_context ctx_jh;
	sph_gost512_context ctx_gost;
	sph_echo512_context ctx_echo;
	sph_skein512_context ctx_skein;

	uint64_t* in64 = (uint64_t*)(input);
	bool has_roots = in64[11] != 0 || in64[12] != 0;

	sph_cubehash512_init(&ctx_cubehash);
	sph_cubehash512(&ctx_cubehash, input, has_roots ? 144 : 80);
	sph_cubehash512_close(&ctx_cubehash, (void*)hash);

	LYRA2(&hashLyra[ 0], 32, &hash[ 0], 32, &hash[ 0], 32, 1, 8, 8);
	LYRA2(&hashLyra[32], 32, &hash[32], 32, &hash[32], 32, 1, 8, 8);

	sph_jh512_init(&ctx_jh);
	sph_jh512(&ctx_jh, (const void*)hashLyra, 64);
	sph_jh512_close(&ctx_jh, (void*)hash);

	if (hash[0] & 1) {
		sph_gost512_init(&ctx_gost);
		sph_gost512(&ctx_gost, (const void*)hash, 64);
		sph_gost512_close(&ctx_gost, (void*)hash);
	} else {
		sph_echo512_init(&ctx_echo);
		sph_echo512(&ctx_echo, (const void*)hash, 64);
		sph_echo512_close(&ctx_echo, (void*)hash);

		sph_echo512_init(&ctx_echo);
		sph_echo512(&ctx_echo, (const void*)hash, 64);
		sph_echo512_close(&ctx_echo, (void*)hash);
	}

	sph_skein512_init(&ctx_skein);
	sph_skein512(&ctx_skein, (const void*)hash, 64);
	sph_skein512_close(&ctx_skein, (void*)hash);

	for (int i=0; i<32; i+=8)
		AS_U64(&hash[i]) ^= AS_U64(&hash[i + 32]);

	memcpy(state, hash, 32);
}

static inline void be32enc_vect(uint32_t *dst, const uint32_t *src, uint32_t len) {
	for (int i = 0; i < len; i++) dst[i] = htobe32(src[i]);
}

void phi2_regenhash(struct work *work)
{
	uint32_t data[36];
	uint32_t *ohash = (uint32_t *)(work->hash);

	be32enc_vect(data, (const uint32_t *)work->data, 36);
	phi2_hash(ohash, data);
}
