#ifndef ATOMIC_VQF_H
#define ATOMIC_VQF_H



#include <cuda.h>
#include <cuda_runtime_api.h>
#include "include/atomic_block.cuh"

#include "include/metadata.cuh"


typedef struct __attribute__ ((__packed__)) thread_team_block {


	atomic_block internal_blocks[BLOCKS_PER_THREAD_BLOCK];

} thread_team_block;


//doesn't need to be explicitly packed
typedef struct __attribute__ ((__packed__)) optimized_vqf {




	uint64_t num_blocks;

	uint64_t num_teams;
	
	uint64_t ** buffers;

	uint64_t * buffer_sizes;

	thread_team_block * blocks;

	int seed;

	__device__ void lock_block(int warpID, uint64_t team, uint64_t lock);

	__device__ void unlock_block(int warpID, uint64_t team, uint64_t lock);


	__device__ void lock_blocks(int warpID, uint64_t team1, uint64_t lock1, uint64_t team2, uint64_t lock2);

	__device__ void unlock_blocks(int warpId, uint64_t team1, uint64_t lock1, uint64_t team2, uint64_t lock2);


	__host__ void bulk_insert(uint64_t * items, uint64_t nitems, uint64_t * misses);

	
	//block variants for debugging

	__device__ bool mini_filter_block(uint64_t * misses);

	__device__ void dump_remaining_buffers_block(thread_team_block * local_blocks, uint64_t blockID, int warpID, int threadID, uint64_t * misses);

    __device__ bool insert_single_buffer_block(thread_team_block * local_blocks, uint64_t blockID, int warpID, int threadID);


	__device__ bool query(int warpID, uint64_t key);

	//query but we check both spots - slower
	__device__ bool full_query(int warpID, uint64_t key);

	//__device__ bool remove(int warpID, uint64_t item);

	__host__ void attach_buffers(uint64_t * vals, uint64_t nvals);

	//__global__ void set_buffers_binary(uint64_t num_keys, uint64_t * keys);

	//__global__ void set_buffer_lens(uint64_t num_keys, uint64_t * keys);


	__device__ uint64_t hash_key(uint64_t key);

	__device__ bool buffer_insert(int warpID, uint64_t buffer);

	__device__ int buffer_query(int warpID, uint64_t buffer);

	__host__ uint64_t get_num_buffers();

	__host__ uint64_t get_num_teams();

	__device__ uint64_t get_bucket_from_hash(uint64_t hash);

	__device__ uint64_t get_alt_hash(uint64_t hash, uint64_t bucket);

	//__device__ bool shared_buffer_insert(int warpID, int shared_blockID, uint64_t buffer);

	//__device__ bool shared_buffer_insert_check(int warpID, int shared_blockID, uint64_t buffer);

	//__device__ bool multi_buffer_insert(int warpID, int shared_blockID, uint64_t start_buffer);

	__device__ void multi_buffer_insert(int warpID, int init_blockID, uint64_t start_buffer);


	//power of two choice functions 
	__host__ void insert_power_of_two(uint64_t * vals, uint64_t nitems);

	__device__ bool query_single_buffer_block(thread_team_block * local_blocks, uint64_t blockID, int warpID, int threadID, uint64_t * items, bool * hits);

	__device__ bool mini_filter_queries(uint64_t * items, bool * hits);

	__host__ void bulk_query(uint64_t * items, uint64_t nitems, bool * hits);

	__host__ void insert_async(uint64_t * items, uint64_t nitems, uint64_t num_teams, uint64_t num_blocks, cudaStream_t stream, uint64_t * misses);

	__host__ void sort_and_check();

	__device__ bool mini_filter_bulk_queries(uint64_t * items, bool * hits);

	__host__ void sorted_bulk_query(uint64_t * items, uint64_t nitems, bool * hits);



} optimized_vqf;


__host__ optimized_vqf * prep_host_vqf(uint64_t nitems);


__host__ optimized_vqf * build_vqf(uint64_t nitems);


#endif