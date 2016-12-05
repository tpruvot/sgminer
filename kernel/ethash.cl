/**
 * Proper ethash OpenCL kernel compatible with AMD and NVIDIA
 *
 * (c) tpruvot @ October 2016
 */

#define ACCESSES   64
#define MAX_OUTPUTS 255u
#define barrier(x) mem_fence(x)


#ifdef cl_nv_pragma_unroll
#define NVIDIA
#else
#pragma OPENCL EXTENSION cl_amd_media_ops2 : enable
#define ROTL64_1(x, y)  amd_bitalign((x), (x).s10, (32U - y))
#define ROTL64_2(x, y)  amd_bitalign((x).s10, (x), (32U - y))
#define ROTL64_8(x, y)  amd_bitalign((x), (x).s10, 24U)
#define BFE(x, start, len)  amd_bfe(x, start, len)
#endif

#ifdef NVIDIA
static inline uint2 rol2(const uint2 a, const uint offset) {
	uint2 r;
	asm("shf.l.wrap.b32 %0, %1, %2, %3;" : "=r"(r.x) : "r"(a.y), "r"(a.x), "r"(offset));
	asm("shf.l.wrap.b32 %0, %1, %2, %3;" : "=r"(r.y) : "r"(a.x), "r"(a.y), "r"(offset));
	return r;
}
static inline uint2 ror2(const uint2 a, const uint offset) {
	uint2 r;
	asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(r.x) : "r"(a.x), "r"(a.y), "r"(offset));
	asm("shf.r.wrap.b32 %0, %1, %2, %3;" : "=r"(r.y) : "r"(a.y), "r"(a.x), "r"(offset));
	return r;
}
static inline uint2 rol8(const uint2 a) {
	uint2 r;
	asm("prmt.b32 %0, %1, %2, 0x6543;" : "=r"(r.x) : "r"(a.y), "r"(a.x));
	asm("prmt.b32 %0, %1, %2, 0x2107;" : "=r"(r.y) : "r"(a.y), "r"(a.x));
	return r;
}

#define ROTL64_1(x, y) rol2(x, y)
#define ROTL64_2(x, y) ror2(x, (32U - y))
#define ROTL64_8(x, y) rol8(x)

static inline uint nv_bfe(const uint a, const uint start, const uint len) {
	uint r;
	asm("bfe.u32 %0, %1, %2, %3;" : "=r"(r) : "r"(a), "r"(start), "r"(len));
	return r;
}
#define BFE(x, start, len) nv_bfe(x, start, len)
#endif /* NVIDIA */

/*
// Generic amd_bfe (bit field extract)
#define BFE(x, start, len) ((x>>start) & ((1U<<len) - 1))

// Generic amd_bitalign
inline uint2 d_bitalign(const uint2 a, const uint2 b, const uint bits) {
  uint2 res;
  res.x = (uint) (((((ulong)a.x) << 32U) | (ulong)b.x) >> (bits & 31U));
  res.y = (uint) (((((ulong)a.y) << 32U) | (ulong)b.y) >> (bits & 31U));
  return res;
}
#define ROTL64_1(x, y) d_bitalign( (x), (x).s10, (32U - y))
#define ROTL64_2(x, y) d_bitalign( (x).s10, (x), (32U - y))
#define ROTL64_8(x, y) d_bitalign( (x), (x).s10, 24U)
*/

static __constant uint2 const Keccak_f1600_RC[24] = {
	{0x00000001U, 0x00000000U},
	{0x00008082U, 0x00000000U},
	{0x0000808aU, 0x80000000U},
	{0x80008000U, 0x80000000U},
	{0x0000808bU, 0x00000000U},
	{0x80000001U, 0x00000000U},
	{0x80008081U, 0x80000000U},
	{0x00008009U, 0x80000000U},
	{0x0000008aU, 0x00000000U},
	{0x00000088U, 0x00000000U},
	{0x80008009U, 0x00000000U},
	{0x8000000aU, 0x00000000U},
	{0x8000808bU, 0x00000000U},
	{0x0000008bU, 0x80000000U},
	{0x00008089U, 0x80000000U},
	{0x00008003U, 0x80000000U},
	{0x00008002U, 0x80000000U},
	{0x00000080U, 0x80000000U},
	{0x0000800aU, 0x00000000U},
	{0x8000000aU, 0x80000000U},
	{0x80008081U, 0x80000000U},
	{0x00008080U, 0x80000000U},
	{0x80000001U, 0x00000000U},
	{0x80008008U, 0x80000000U},
};

#define KECCAKF_1600_RND(a, i, outsz) do { \
	const uint2 m0 = a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20] ^ ROTL64_1(a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22], 1U); \
	const uint2 m1 = a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21] ^ ROTL64_1(a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23], 1U); \
	const uint2 m2 = a[2] ^ a[7] ^ a[12] ^ a[17] ^ a[22] ^ ROTL64_1(a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24], 1U); \
	const uint2 m3 = a[3] ^ a[8] ^ a[13] ^ a[18] ^ a[23] ^ ROTL64_1(a[0] ^ a[5] ^ a[10] ^ a[15] ^ a[20], 1U); \
	const uint2 m4 = a[4] ^ a[9] ^ a[14] ^ a[19] ^ a[24] ^ ROTL64_1(a[1] ^ a[6] ^ a[11] ^ a[16] ^ a[21], 1U); \
	\
	const uint2 tmp = a[1]^m0;\
	\
	a[0] ^= m4; \
	a[5] ^= m4; \
	a[10] ^= m4; \
	a[15] ^= m4; \
	a[20] ^= m4; \
	\
	a[6] ^= m0; \
	a[11] ^= m0; \
	a[16] ^= m0; \
	a[21] ^= m0; \
	\
	a[2] ^= m1; \
	a[7] ^= m1; \
	a[12] ^= m1; \
	a[17] ^= m1; \
	a[22] ^= m1; \
	\
	a[3] ^= m2; \
	a[8] ^= m2; \
	a[13] ^= m2; \
	a[18] ^= m2; \
	a[23] ^= m2; \
	\
	a[4] ^= m3; \
	a[9] ^= m3; \
	a[14] ^= m3; \
	a[19] ^= m3; \
	a[24] ^= m3; \
	\
	a[ 1] = ROTL64_2(a[ 6], 12U);\
	a[ 6] = ROTL64_1(a[ 9], 20U);\
	a[ 9] = ROTL64_2(a[22], 29U);\
	a[22] = ROTL64_2(a[14],  7U);\
	a[14] = ROTL64_1(a[20], 18U);\
	a[20] = ROTL64_2(a[ 2], 30U);\
	a[ 2] = ROTL64_2(a[12], 11U);\
	a[12] = ROTL64_1(a[13], 25U);\
	a[13] = ROTL64_8(a[19],  8U);\
	a[19] = ROTL64_2(a[23], 24U);\
	a[23] = ROTL64_2(a[15],  9U);\
	a[15] = ROTL64_1(a[ 4], 27U);\
	a[ 4] = ROTL64_1(a[24], 14U);\
	a[24] = ROTL64_1(a[21],  2U);\
	a[21] = ROTL64_2(a[ 8], 23U);\
	a[ 8] = ROTL64_2(a[16], 13U);\
	a[16] = ROTL64_2(a[ 5],  4U);\
	a[ 5] = ROTL64_1(a[ 3], 28U);\
	a[ 3] = ROTL64_1(a[18], 21U);\
	a[18] = ROTL64_1(a[17], 15U);\
	a[17] = ROTL64_1(a[11], 10U);\
	a[11] = ROTL64_1(a[ 7],  6U);\
	a[ 7] = ROTL64_1(a[10],  3U);\
	a[10] = ROTL64_1(tmp, 1U);\
	\
	uint2 m5 = a[0]; uint2 m6 = a[1]; a[0] = bitselect(a[0]^a[2], a[0],a[1]); \
	a[0] ^= as_uint2(Keccak_f1600_RC[i]); \
	if (outsz > 1) { \
		a[1] = bitselect(a[1]^a[3],a[1],a[2]); a[2] = bitselect(a[2]^a[4],a[2],a[3]); a[3] = bitselect(a[3]^m5,a[3],a[4]); a[4] = bitselect(a[4]^m6,a[4],m5);\
		if (outsz > 4) { \
			m5 = a[5]; m6 = a[6]; a[5] = bitselect(a[5]^a[7],a[5],a[6]); a[6] = bitselect(a[6]^a[8],a[6],a[7]); a[7] = bitselect(a[7]^a[9],a[7],a[8]); a[8] = bitselect(a[8]^m5,a[8],a[9]); a[9] = bitselect(a[9]^m6,a[9],m5);\
			if (outsz > 8) { \
				m5 = a[10]; m6 = a[11]; a[10] = bitselect(a[10]^a[12],a[10],a[11]); a[11] = bitselect(a[11]^a[13],a[11],a[12]); a[12] = bitselect(a[12]^a[14],a[12],a[13]); a[13] = bitselect(a[13]^m5,a[13],a[14]); a[14] = bitselect(a[14]^m6,a[14],m5);\
				m5 = a[15]; m6 = a[16]; a[15] = bitselect(a[15]^a[17],a[15],a[16]); a[16] = bitselect(a[16]^a[18],a[16],a[17]); a[17] = bitselect(a[17]^a[19],a[17],a[18]); a[18] = bitselect(a[18]^m5,a[18],a[19]); a[19] = bitselect(a[19]^m6,a[19],m5);\
				m5 = a[20]; m6 = a[21]; a[20] = bitselect(a[20]^a[22],a[20],a[21]); a[21] = bitselect(a[21]^a[23],a[21],a[22]); a[22] = bitselect(a[22]^a[24],a[22],a[23]); a[23] = bitselect(a[23]^m5,a[23],a[24]); a[24] = bitselect(a[24]^m6,a[24],m5);\
			} \
		} \
	} \
} while(0)

#define KECCAK_PROCESS(st, in_size, out_size, isolate) do { \
	for (int r = 0; r < 23; r++) { \
		if (isolate) { KECCAKF_1600_RND(st, r, 25); } \
	} \
	KECCAKF_1600_RND(st, 23, out_size); \
} while(0)


#define FNV_PRIME 0x01000193U
#define fnv(x, y) ((x) * FNV_PRIME ^ (y))
#define fnv_reduce(v) fnv(fnv(fnv(v.x, v.y), v.z), v.w)

typedef union {
	uint  uints[32 / sizeof(uint)];
	ulong ulongs[32 / sizeof(ulong)];
} hash32_t;

typedef union {
	uint  words[64 / sizeof(uint)];
	uint2 uint2s[64 / sizeof(uint2)];
	uint4 uint4s[64 / sizeof(uint4)];
} hash64_t;

typedef union {
	uint  words[200 / sizeof(uint)];
	uint2 uint2s[200 / sizeof(uint2)];
	ulong ulongs[200 / sizeof(ulong)];
	uint4 uint4s[200 / sizeof(uint4)];
} hash200_t;

typedef union {
	uint   uints[128 / sizeof(uint)];
	ulong  ulongs[128 / sizeof(ulong)];
	uint2  uint2s[128 / sizeof(uint2)];
	uint4  uint4s[128 / sizeof(uint4)];
	uint8  uint8s[128 / sizeof(uint8)];
	uint16 uint16s[128 / sizeof(uint16)];
	ulong8 ulong8s[128 / sizeof(ulong8)];
} hash128_t;

typedef union {
	ulong8 ulong8s[1];
	ulong4 ulong4s[2];
	uint2  uint2s[8];
	uint4  uint4s[4];
	uint8  uint8s[2];
	uint16 uint16s[1];
	ulong  ulongs[8];
	uint   uints[16];
} compute_hash_share;

//#define DEBUG

__attribute__((reqd_work_group_size(WORKSIZE, 1, 1)))
__kernel void search(
	__global volatile uint* restrict g_output,
	__constant hash32_t const* g_header,
	__global hash128_t const* g_dag,
	uint DAG_SIZE,
	ulong start_nonce,
	ulong target,
	uint isolate
	)
{
	const uint gid = get_global_id(0);
	const uint thread_id = get_local_id(0) & 3U;
	const uint hash_id = get_local_id(0) >> 2U;

	__local compute_hash_share sharebuf[WORKSIZE / 4];
	__local compute_hash_share * const share = sharebuf + hash_id;

#ifdef DEBUG
	uint2 state[25];
	state[0] = as_uint2(1UL);
	state[1] = as_uint2(0UL);
	state[2] = as_uint2(0UL);
	state[3] = as_uint2(0UL);
	state[4] = as_uint2(0UL);
#else
	uint2 state[25];
	// sha3_512(header .. nonce)
	((ulong4 *)state)[0] = ((__constant ulong4 *)g_header)[0];
	state[4] = as_uint2(start_nonce + gid);
#endif
	state[5] = as_uint2(0x0000000000000001UL);
	state[6] = as_uint2(0UL);
	state[7] = as_uint2(0UL);
	state[8] = as_uint2(0x8000000000000000UL);

	#pragma unroll
	for (int i=9; i<25; i++)
		state[i] = as_uint2(0UL);

	KECCAK_PROCESS(state, 5U, 8U, isolate);

#ifdef DEBUG
	if (!gid) {
		uint2 *test = (uint2*) &state[10];
		if (test->x == 0x6772d492) // nvidia
			printf("BAD!! %08x\n", isolate);
		if (test->x == 0x3f32949a) // amd
			printf("GOOD! %08x\n", isolate);
	}
#endif

	#pragma unroll 1
	for (uint tid = 0; tid < 4; tid++)
	{
		// share init with other threads
		if (tid == thread_id)
			share->ulong8s[0] = ((ulong8 *)state)[0];

		barrier(CLK_LOCAL_MEM_FENCE);

		// It's done like it was because of the duplication
		// We can do the same - with uint8s.
		uint8 mix = share->uint8s[thread_id & 1U];

		uint init0 = share->uints[0];
		barrier(CLK_LOCAL_MEM_FENCE);

		#pragma unroll 1
		for (uint a = 0; a < (ACCESSES & isolate); a += 8)
		{
			#pragma unroll
			for (uint y = 0; y < 8; ++y)
			{
				if (thread_id == BFE(a, 3U, 2U)) {
					uint uf = fnv(init0 ^ (a + y), ((uint*)&mix)[y]);
					share->uints[0] = uf < DAG_SIZE ? uf : uf % DAG_SIZE;
				}

				barrier(CLK_LOCAL_MEM_FENCE);
#ifndef DEBUG
				mix = fnv(mix, g_dag[share->uints[0]].uint8s[thread_id]);
#endif
			}
		}
		share->uint2s[thread_id] = (uint2)(fnv_reduce(mix.lo), fnv_reduce(mix.hi));

		barrier(CLK_LOCAL_MEM_FENCE);

		if (tid == thread_id)
			((ulong4 *)state)[2] = share->ulong4s[0];
	}

	state[12] = as_uint2(0x0000000000000001UL);
	state[13] = as_uint2(0UL);
	state[14] = as_uint2(0UL);
	state[15] = as_uint2(0UL);
	state[16] = as_uint2(0x8000000000000000UL);
	#pragma unroll
	for (int i=17; i<25; i++)
		state[i] = as_uint2(0UL);

	KECCAK_PROCESS(state, 12, 1, isolate);

#ifdef DEBUG
	// 59978c4f 8125c919
	if (gid==63) printf("H0 %08x %08x\n", state[0].x, state[0].y);
#endif

#ifdef NVIDIA
	if (as_ulong(as_uchar8(state[0]).s76543210) < target)
	{
		uint slot = atomic_inc(&g_output[MAX_OUTPUTS]);
		//uint2 tgt = as_uint2(target);
		//printf("candidate %u => %08x %08x < %08x\n", slot, state[0].x, state[0].y, (uint) (target>>32));
		g_output[slot & MAX_OUTPUTS] = gid;
	}
#else
	if (as_ulong(as_uchar8(state[0]).s76543210) < target)
	{
		uint slot = min(MAX_OUTPUTS-1u, convert_uint(atomic_inc(&g_output[MAX_OUTPUTS])));
		g_output[slot] = gid;
	}
#endif
}


typedef union _Node
{
	uint dwords[16];
	uint2 qwords[8];
	uint4 dqwords[4];
} Node;

static void SHA3_512(uint2 *s, uint isolate)
{
	uint2 st[25];

	#pragma unroll
	for (uint i = 0; i < 8; i++)
		st[i] = s[i];

	#pragma unroll
	for (uint i = 8; i != 25; i++)
		st[i] = as_uint2(0UL);

	st[8].x = 0x00000001u;
	st[8].y = 0x80000000u;
	KECCAK_PROCESS(st, 8, 8, isolate);

	#pragma unroll
	for (uint i = 0; i < 8; i++)
		s[i] = st[i];
}

__kernel void GenerateDAG(uint start, __global const uint16 *_Cache, __global uint16 *_DAG, uint LIGHT_SIZE, uint isolate)
{
	__global const Node *Cache = (__global const Node *) _Cache;
	__global Node *DAG = (__global Node *) _DAG;
	uint NodeIdx = start + get_global_id(0);

	Node DAGNode = Cache[NodeIdx % LIGHT_SIZE];

	DAGNode.dwords[0] ^= NodeIdx;
	SHA3_512(DAGNode.qwords, isolate);

	for (uint i = 0; i < 256; ++i)
	{
		uint ParentIdx = fnv(NodeIdx ^ i, DAGNode.dwords[i & 15]) % LIGHT_SIZE;
		__global const Node *ParentNode = Cache + ParentIdx;

		#pragma unroll
		for (uint x = 0; x < 4; ++x)
		{
			DAGNode.dqwords[x] *= (uint4)(FNV_PRIME);
			DAGNode.dqwords[x] ^= ParentNode->dqwords[x];
		}
	}

	SHA3_512(DAGNode.qwords, isolate);
	DAG[NodeIdx] = DAGNode;
}
