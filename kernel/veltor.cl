/* Veltor kernel implementation.
 *
 * ==========================(LICENSE BEGIN)============================
 *
 * Copyright (c) 2016 tpruvot
 *
 * Permission is hereby granted, free of charge, to any person obtaining
 * a copy of this software and associated documentation files (the
 * "Software"), to deal in the Software without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Software, and to
 * permit persons to whom the Software is furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 *
 * ===========================(LICENSE END)=============================
 *
 * @author tpruvot 2016
 */

#if __ENDIAN_LITTLE__
  #define SPH_LITTLE_ENDIAN 1
#else
  #define SPH_BIG_ENDIAN 1
#endif

#define SPH_UPTR sph_u64
typedef unsigned int sph_u32;
typedef int sph_s32;

#ifndef __OPENCL_VERSION__
  typedef unsigned long long sph_u64;
#else
  typedef unsigned long sph_u64;
#endif

#define SPH_64 1
#define SPH_64_TRUE 1

#define SPH_C32(x) ((sph_u32)(x ## U))
#define SPH_T32(x) (as_uint(x))
#define SPH_ROTL32(x, n) rotate(as_uint(x), as_uint(n))
#define SPH_ROTR32(x, n) SPH_ROTL32(x, (32 - (n)))

#define SPH_C64(x) ((sph_u64)(x ## UL))
#define SPH_T64(x) (as_ulong(x))
#define SPH_ROTL64(x, n) rotate(as_ulong(x), (n) & 0xFFFFFFFFFFFFFFFFUL)
#define SPH_ROTR64(x, n) SPH_ROTL64(x, (64 - (n)))

#include "skein.cl"
#include "shavite.cl"
#include "shabal.cl"
#include "streebog.cl"

#define SWAP4(x) as_uint(as_uchar4(x).wzyx)
#define SWAP8(x) as_ulong(as_uchar8(x).s76543210)

#if SPH_BIG_ENDIAN
  #define DEC64LE(x) SWAP8(*(const __global sph_u64 *) (x));
#else
  #define DEC64LE(x) (*(const __global sph_u64 *) (x));
#endif

#define SHL(x, n) ((x) << (n))
#define SHR(x, n) ((x) >> (n))

typedef union {
  unsigned char h1[64];
  uint h4[16];
  ulong h8[8];
} hash_t;

#define SWAP8_OUTPUT(x)  SWAP8(x)

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(__global unsigned char* block, __global hash_t* hashes)
{
  uint gid = get_global_id(0);
  __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);

  // input skein 80

  sph_u64 M0, M1, M2, M3, M4, M5, M6, M7;
  sph_u64 M8, M9;

  M0 = DEC64LE(block + 0);
  M1 = DEC64LE(block + 8);
  M2 = DEC64LE(block + 16);
  M3 = DEC64LE(block + 24);
  M4 = DEC64LE(block + 32);
  M5 = DEC64LE(block + 40);
  M6 = DEC64LE(block + 48);
  M7 = DEC64LE(block + 56);
  M8 = DEC64LE(block + 64);
  M9 = DEC64LE(block + 72);
  ((uint*)&M9)[1] = SWAP4(gid);

  //if (!gid) printf("M0 %02x..%02x\n", (uint) ((uchar*)&M0)[0], (uint) ((uchar*)&M0)[7]);

  sph_u64 h0 = SPH_C64(0x4903ADFF749C51CE);
  sph_u64 h1 = SPH_C64(0x0D95DE399746DF03);
  sph_u64 h2 = SPH_C64(0x8FD1934127C79BCE);
  sph_u64 h3 = SPH_C64(0x9A255629FF352CB1);
  sph_u64 h4 = SPH_C64(0x5DB62599DF6CA7B0);
  sph_u64 h5 = SPH_C64(0xEABE394CA9D5C3F4);
  sph_u64 h6 = SPH_C64(0x991112C71A75B523);
  sph_u64 h7 = SPH_C64(0xAE18A40B660FCC33);

  // h8 = h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7 ^ SPH_C64(0x1BD11BDAA9FC1A22);
  sph_u64 h8 = SPH_C64(0xcab2076d98173ec4);

  sph_u64 t0 = 64;
  sph_u64 t1 = SPH_C64(0x7000000000000000);
  sph_u64 t2 = SPH_C64(0x7000000000000040); // t0 ^ t1;

  sph_u64 p0 = M0;
  sph_u64 p1 = M1;
  sph_u64 p2 = M2;
  sph_u64 p3 = M3;
  sph_u64 p4 = M4;
  sph_u64 p5 = M5;
  sph_u64 p6 = M6;
  sph_u64 p7 = M7;

  TFBIG_4e(0);
  TFBIG_4o(1);
  TFBIG_4e(2);
  TFBIG_4o(3);
  TFBIG_4e(4);
  TFBIG_4o(5);
  TFBIG_4e(6);
  TFBIG_4o(7);
  TFBIG_4e(8);
  TFBIG_4o(9);
  TFBIG_4e(10);
  TFBIG_4o(11);
  TFBIG_4e(12);
  TFBIG_4o(13);
  TFBIG_4e(14);
  TFBIG_4o(15);
  TFBIG_4e(16);
  TFBIG_4o(17);
  TFBIG_ADDKEY(p0, p1, p2, p3, p4, p5, p6, p7, h, t, 18);

  h0 = M0 ^ p0;
  h1 = M1 ^ p1;
  h2 = M2 ^ p2;
  h3 = M3 ^ p3;
  h4 = M4 ^ p4;
  h5 = M5 ^ p5;
  h6 = M6 ^ p6;
  h7 = M7 ^ p7;

  // second part with nonce
  p0 = M8;
  p1 = M9;
  p2 = p3 = p4 = p5 = p6 = p7 = 0;
  t0 = 80;
  t1 = SPH_C64(0xB000000000000000);
  t2 = SPH_C64(0xB000000000000050); // t0 ^ t1;
  h8 = h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7 ^ SPH_C64(0x1BD11BDAA9FC1A22);

  TFBIG_4e(0);
  TFBIG_4o(1);
  TFBIG_4e(2);
  TFBIG_4o(3);
  TFBIG_4e(4);
  TFBIG_4o(5);
  TFBIG_4e(6);
  TFBIG_4o(7);
  TFBIG_4e(8);
  TFBIG_4o(9);
  TFBIG_4e(10);
  TFBIG_4o(11);
  TFBIG_4e(12);
  TFBIG_4o(13);
  TFBIG_4e(14);
  TFBIG_4o(15);
  TFBIG_4e(16);
  TFBIG_4o(17);
  TFBIG_ADDKEY(p0, p1, p2, p3, p4, p5, p6, p7, h, t, 18);
  h0 = p0 ^ M8;
  h1 = p1 ^ M9;
  h2 = p2;
  h3 = p3;
  h4 = p4;
  h5 = p5;
  h6 = p6;
  h7 = p7;

  // close
  t0 = 8;
  t1 = SPH_C64(0xFF00000000000000);
  t2 = SPH_C64(0xFF00000000000008); // t0 ^ t1;
  h8 = h0 ^ h1 ^ h2 ^ h3 ^ h4 ^ h5 ^ h6 ^ h7 ^ SPH_C64(0x1BD11BDAA9FC1A22);

  p0 = p1 = p2 = p3 = p4 = p5 = p6 = p7 = 0;

  TFBIG_4e(0);
  TFBIG_4o(1);
  TFBIG_4e(2);
  TFBIG_4o(3);
  TFBIG_4e(4);
  TFBIG_4o(5);
  TFBIG_4e(6);
  TFBIG_4o(7);
  TFBIG_4e(8);
  TFBIG_4o(9);
  TFBIG_4e(10);
  TFBIG_4o(11);
  TFBIG_4e(12);
  TFBIG_4o(13);
  TFBIG_4e(14);
  TFBIG_4o(15);
  TFBIG_4e(16);
  TFBIG_4o(17);
  TFBIG_ADDKEY(p0, p1, p2, p3, p4, p5, p6, p7, h, t, 18);

  hash->h8[0] = p0;
  hash->h8[1] = p1;
  hash->h8[2] = p2;
  hash->h8[3] = p3;
  hash->h8[4] = p4;
  hash->h8[5] = p5;
  hash->h8[6] = p6;
  hash->h8[7] = p7;

  //if (!gid) printf("SK80 %02x..%02x\n", (uint) ((uchar*)&p0)[0], (uint) ((uchar*)&p7)[7]);

  barrier(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search1(__global hash_t* hashes)
{
  uint gid = get_global_id(0);
  __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);

  __local sph_u32 AES0[256], AES1[256], AES2[256], AES3[256];

  int init = get_local_id(0);
  int step = get_local_size(0);

  for(int i = init; i < 256; i += step) {
    AES0[i] = AES0_C[i];
    AES1[i] = AES1_C[i];
    AES2[i] = AES2_C[i];
    AES3[i] = AES3_C[i];
  }

  barrier(CLK_LOCAL_MEM_FENCE);

  // shavite
  // IV
  sph_u32 h0 = SPH_C32(0x72FCCDD8), h1 = SPH_C32(0x79CA4727), h2 = SPH_C32(0x128A077B), h3 = SPH_C32(0x40D55AEC);
  sph_u32 h4 = SPH_C32(0xD1901A06), h5 = SPH_C32(0x430AE307), h6 = SPH_C32(0xB29F5CD1), h7 = SPH_C32(0xDF07FBFC);
  sph_u32 h8 = SPH_C32(0x8E45D73D), h9 = SPH_C32(0x681AB538), hA = SPH_C32(0xBDE86578), hB = SPH_C32(0xDD577E47);
  sph_u32 hC = SPH_C32(0xE275EADE), hD = SPH_C32(0x502D9FCD), hE = SPH_C32(0xB9357178), hF = SPH_C32(0x022A4B9A);

  // state
  sph_u32 rk00, rk01, rk02, rk03, rk04, rk05, rk06, rk07;
  sph_u32 rk08, rk09, rk0A, rk0B, rk0C, rk0D, rk0E, rk0F;
  sph_u32 rk10, rk11, rk12, rk13, rk14, rk15, rk16, rk17;
  sph_u32 rk18, rk19, rk1A, rk1B, rk1C, rk1D, rk1E, rk1F;

  sph_u32 sc_count0 = (64 << 3), sc_count1 = 0, sc_count2 = 0, sc_count3 = 0;

  rk00 = hash->h4[0];
  rk01 = hash->h4[1];
  rk02 = hash->h4[2];
  rk03 = hash->h4[3];
  rk04 = hash->h4[4];
  rk05 = hash->h4[5];
  rk06 = hash->h4[6];
  rk07 = hash->h4[7];
  rk08 = hash->h4[8];
  rk09 = hash->h4[9];
  rk0A = hash->h4[10];
  rk0B = hash->h4[11];
  rk0C = hash->h4[12];
  rk0D = hash->h4[13];
  rk0E = hash->h4[14];
  rk0F = hash->h4[15];
  rk10 = 0x80;
  rk11 = rk12 = rk13 = rk14 = rk15 = rk16 = rk17 = rk18 = rk19 = rk1A = 0;
  rk1B = 0x2000000;
  rk1C = rk1D = rk1E = 0;
  rk1F = 0x2000000;

  c512(buf);

  hash->h4[0] = h0;
  hash->h4[1] = h1;
  hash->h4[2] = h2;
  hash->h4[3] = h3;
  hash->h4[4] = h4;
  hash->h4[5] = h5;
  hash->h4[6] = h6;
  hash->h4[7] = h7;
  hash->h4[8] = h8;
  hash->h4[9] = h9;
  hash->h4[10] = hA;
  hash->h4[11] = hB;
  hash->h4[12] = hC;
  hash->h4[13] = hD;
  hash->h4[14] = hE;
  hash->h4[15] = hF;

  //if (!gid) printf("SV %02x..%02x\n", (uint) hash->h1[0], (uint) hash->h1[31]);

  barrier(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search2(__global hash_t* hashes)
{
  uint gid = get_global_id(0);
  uint offset = get_global_offset(0);
  __global hash_t *hash = &(hashes[gid-offset]);

  // shabal
  sph_u32 A00 = A_init_512[0], A01 = A_init_512[1], A02 = A_init_512[ 2], A03 = A_init_512[ 3];
  sph_u32 A04 = A_init_512[4], A05 = A_init_512[5], A06 = A_init_512[ 6], A07 = A_init_512[ 7];
  sph_u32 A08 = A_init_512[8], A09 = A_init_512[9], A0A = A_init_512[10], A0B = A_init_512[11];

  sph_u32 B0 = B_init_512[ 0], B1 = B_init_512[ 1], B2 = B_init_512[ 2], B3 = B_init_512[ 3];
  sph_u32 B4 = B_init_512[ 4], B5 = B_init_512[ 5], B6 = B_init_512[ 6], B7 = B_init_512[ 7];
  sph_u32 B8 = B_init_512[ 8], B9 = B_init_512[ 9], BA = B_init_512[10], BB = B_init_512[11];
  sph_u32 BC = B_init_512[12], BD = B_init_512[13], BE = B_init_512[14], BF = B_init_512[15];

  sph_u32 C0 = C_init_512[ 0], C1 = C_init_512[ 1], C2 = C_init_512[ 2], C3 = C_init_512[ 3];
  sph_u32 C4 = C_init_512[ 4], C5 = C_init_512[ 5], C6 = C_init_512[ 6], C7 = C_init_512[ 7];
  sph_u32 C8 = C_init_512[ 8], C9 = C_init_512[ 9], CA = C_init_512[10], CB = C_init_512[11];
  sph_u32 CC = C_init_512[12], CD = C_init_512[13], CE = C_init_512[14], CF = C_init_512[15];

  sph_u32 M0, M1, M2, M3, M4, M5, M6, M7, M8, M9, MA, MB, MC, MD, ME, MF;
  sph_u32 Wlow = 1, Whigh = 0;

  M0 = hash->h4[0];
  M1 = hash->h4[1];
  M2 = hash->h4[2];
  M3 = hash->h4[3];
  M4 = hash->h4[4];
  M5 = hash->h4[5];
  M6 = hash->h4[6];
  M7 = hash->h4[7];
  M8 = hash->h4[8];
  M9 = hash->h4[9];
  MA = hash->h4[10];
  MB = hash->h4[11];
  MC = hash->h4[12];
  MD = hash->h4[13];
  ME = hash->h4[14];
  MF = hash->h4[15];

  INPUT_BLOCK_ADD;
  XOR_W;
  APPLY_P;
  INPUT_BLOCK_SUB;
  SWAP_BC;
  INCR_W;

  M0 = 0x80;
  M1 = M2 = M3 = M4 = M5 = M6 = M7 = M8 = M9 = MA = MB = MC = MD = ME = MF = 0;

  INPUT_BLOCK_ADD;
  XOR_W;
  APPLY_P;

  for (unsigned i = 0; i < 3; i ++) {
    SWAP_BC;
    XOR_W;
    APPLY_P;
  }

  hash->h4[0] = B0;
  hash->h4[1] = B1;
  hash->h4[2] = B2;
  hash->h4[3] = B3;
  hash->h4[4] = B4;
  hash->h4[5] = B5;
  hash->h4[6] = B6;
  hash->h4[7] = B7;
  hash->h4[8] = B8;
  hash->h4[9] = B9;
  hash->h4[10] = BA;
  hash->h4[11] = BB;
  hash->h4[12] = BC;
  hash->h4[13] = BD;
  hash->h4[14] = BE;
  hash->h4[15] = BF;

  //if (!gid) printf("SB %02x..%02x\n", (uint) hash->h1[0], (uint) hash->h1[31]);

  barrier(CLK_GLOBAL_MEM_FENCE);
}

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search3(__global hash_t* hashes, __global uint* output, const ulong target)
{
  uint gid = get_global_id(0);
  __global hash_t *hash = &(hashes[gid-get_global_offset(0)]);

  // Streebog

  __local sph_u64 lT[8][256];

  for(int i=0; i<8; i++) {
    for(int j=0; j<256; j++) lT[i][j] = T[i][j];
  }

  __local unsigned char lCC[12][64];
  __local void*    vCC[12];
  __local sph_u64* sCC[12];

  for(int i=0; i<12; i++) {
    for(int j=0; j<64; j++) lCC[i][j] = CC[i][j];
  }

  for(int i=0; i<12; i++) {
    vCC[i] = lCC[i];
  }
  for(int i=0; i<12; i++) {
    sCC[i] = vCC[i];
  }

  sph_u64 message[8];
  message[0] = (hash->h8[0]);
  message[1] = (hash->h8[1]);
  message[2] = (hash->h8[2]);
  message[3] = (hash->h8[3]);
  message[4] = (hash->h8[4]);
  message[5] = (hash->h8[5]);
  message[6] = (hash->h8[6]);
  message[7] = (hash->h8[7]);

  sph_u64 out[8];
  sph_u64 len = 512;
  GOST_HASH_512(message, len, out);

#if 0
  hash->h8[0] = SWAP8_OUTPUT(out[0]);
  hash->h8[1] = SWAP8_OUTPUT(out[1]);
  hash->h8[2] = SWAP8_OUTPUT(out[2]);
  hash->h8[3] = SWAP8_OUTPUT(out[3]);
  hash->h8[4] = SWAP8_OUTPUT(out[4]);
  hash->h8[5] = SWAP8_OUTPUT(out[5]);
  hash->h8[6] = SWAP8_OUTPUT(out[6]);
  hash->h8[7] = SWAP8_OUTPUT(out[7]);
  if (!gid) printf("ST %02x..%02x\n", (uint) hash->h1[0], (uint) hash->h1[31]);
#endif

  //if (!gid) printf("ST %02x..%02x\n", (uint) ((uchar*)out)[0], (uint) ((uchar*)out)[31]);

  if (out[3] <= target)
    output[atomic_inc(output+0xFF)] = gid;
}
