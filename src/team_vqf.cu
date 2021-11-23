

#ifndef VQF_C
#define VQF_C



#include "include/team_vqf.cuh"
#include <cuda.h>
#include <cuda_runtime_api.h>
#include "include/vqf_team_block.cuh"

#include <iostream>

#include <fstream>
#include <assert.h>


__device__ void vqf::lock_block(int warpID, uint64_t lock){


	// if (warpID == 0){

	// 	while(atomicCAS(locks + lock, 0,1) != 0);	
	// }
	// __syncwarp();

	blocks[lock].lock(warpID);
}

__device__ void vqf::unlock_block(int warpID, uint64_t lock){


	// if (warpID == 0){

	// 	while(atomicCAS(locks + lock, 1,0) != 1);	

	// }

	//__syncwarp();

	blocks[lock].unlock(warpID);
}

__device__ void vqf::lock_blocks(int warpID, uint64_t lock1, uint64_t lock2){


	if (lock1 < lock2){

		lock_block(warpID, lock1);
		lock_block(warpID, lock2);
		//while(atomicCAS(locks + lock2, 0,1) == 1);

	} else {


		lock_block(warpID, lock2);
		lock_block(warpID, lock1);
		
	}

	


}

__device__ void vqf::unlock_blocks(int warpID, uint64_t lock1, uint64_t lock2){


	if (lock1 > lock2){

		unlock_block(warpID, lock1);
		unlock_block(warpID, lock2);
		
	} else {

		unlock_block(warpID, lock2);
		unlock_block(warpID, lock1);
	}
	

}

__device__ bool vqf::insert(int warpID, uint64_t hash){

   uint64_t block_index = (hash >> TAG_BITS) % num_blocks;



   //this will generate a mask and get the tag bits
   uint64_t tag = hash & ((1ULL << TAG_BITS) -1);
   uint64_t alt_block_index = (((hash ^ (tag * 0x5bd1e995)) % (num_blocks*SLOTS_PER_BLOCK)) >> TAG_BITS) % num_blocks;

   // assert(block_index < num_blocks);


   //external locks
   //blocks[block_index].extra_lock(block_index);
 	
 	//lock_block(warpID, block_index);


 	//unlock_block(warpID, block_index);

 	if (block_index == alt_block_index) return false;


 	lock_blocks(warpID, block_index, alt_block_index);

   int fill_main = blocks[block_index].get_fill();

   int fill_alt = blocks[alt_block_index].get_fill();


   bool toReturn = false;

   if (fill_main < fill_alt){


   	unlock_block(warpID, alt_block_index);



   	//if (fill_main < SLOTS_PER_BLOCK-1){
   	if (fill_main < 24){
   		blocks[block_index].insert(warpID, tag);

   		toReturn = true;

   		int new_fill = blocks[block_index].get_fill();
   		if (new_fill != fill_main+1){

   		blocks[block_index].printMetadata();
   		printf("Broken Fill: Block %llu, old %d new %d\n", block_index, fill_main, new_fill);
   		assert(blocks[block_index].get_fill() == fill_main+1);
   		}
   		

   	}

   	unlock_block(warpID, block_index);


   } else {

   	unlock_block(warpID, block_index);

   	if (fill_alt < 24){
   		
   	

	   	blocks[alt_block_index].insert(warpID, tag);

	   	toReturn = true;

	   	int new_fill = blocks[alt_block_index].get_fill();
   		if (new_fill != fill_alt+1){
   		printf("Broken Fill: Block %llu, old %d new %d\n", alt_block_index, fill_alt, new_fill);
   		assert(blocks[alt_block_index].get_fill() == fill_alt+1);
   		}

	   }

	   unlock_block(warpID, alt_block_index);

   }



 	//unlock_blocks(block_index, alt_block_index);


   return toReturn;





}


__device__ bool vqf::query(int warpID, uint64_t hash){

	uint64_t block_index = (hash >> TAG_BITS) % num_blocks;

   //this will generate a mask and get the tag bits
   uint64_t tag = hash & ((1ULL << TAG_BITS) -1);
   uint64_t alt_block_index = (((hash ^ (tag * 0x5bd1e995)) % (num_blocks*SLOTS_PER_BLOCK)) >> TAG_BITS) % num_blocks;

   if (block_index == alt_block_index){

   	lock_block(warpID, block_index);

   	bool found = blocks[block_index].query(warpID, tag);

   	unlock_block(warpID, block_index);

   	return true;


   }

   lock_blocks(warpID, block_index, alt_block_index);

   bool found = blocks[block_index].query(warpID, tag) || blocks[alt_block_index].query(warpID, tag);

   unlock_blocks(warpID, block_index, alt_block_index);

   return true;

}


__device__ bool vqf::remove(int warpID, uint64_t hash){


	uint64_t block_index = (hash >> TAG_BITS) % num_blocks;

   //this will generate a mask and get the tag bits
   uint64_t tag = hash & ((1ULL << TAG_BITS) -1);
   uint64_t alt_block_index = (((hash ^ (tag * 0x5bd1e995)) % (num_blocks*SLOTS_PER_BLOCK)) >> TAG_BITS) % num_blocks;


   lock_block(warpID, block_index);

   bool found = blocks[block_index].remove(warpID, tag);

   unlock_block(warpID, block_index);

   //copy could be deleted from this instance

   if (found){
   	return true;
   }

   lock_block(warpID, alt_block_index);

   found = blocks[alt_block_index].remove(warpID, tag);

   unlock_block(warpID, alt_block_index);

   return found;

}


// __device__ bool vqf::insert(uint64_t hash){

//    uint64_t block_index = (hash >> TAG_BITS) % num_blocks;



//    //this will generate a mask and get the tag bits
//    uint64_t tag = hash & ((1ULL << TAG_BITS) -1);
//    uint64_t alt_block_index = (((hash ^ (tag * 0x5bd1e995)) % (num_blocks*SLOTS_PER_BLOCK)) >> TAG_BITS) % num_blocks;

//    assert(block_index < num_blocks);


//    //external locks
//    //blocks[block_index].extra_lock(block_index);
   
//    while(atomicCAS(locks + block_index, 0, 1) == 1);



//    int fill_main = blocks[block_index].get_fill();


//    if (fill_main >= SLOTS_PER_BLOCK-1){

//    	while(atomicCAS(locks + block_index, 0, 1) == 0);
//    	//blocks[block_index].unlock();

//    	return false;
//    }

//    if (fill_main < .75 * SLOTS_PER_BLOCK || block_index == alt_block_index){
//    	blocks[block_index].insert(tag);

   	

//    	int new_fill = blocks[block_index].get_fill();
//    	if (new_fill != fill_main+1){
//    		printf("Broken Fill: Block %llu, old %d new %d\n", block_index, fill_main, new_fill);
//    		assert(blocks[block_index].get_fill() == fill_main+1);
//    	}


//    	while(atomicCAS(locks + block_index, 1, 0) == 0);
//    	//blocks[block_index].unlock();
//    	return true;
//    }


//    while(atomicCAS(locks + block_index, 1, 0) == 0);

//    lock_blocks(block_index, alt_block_index);


//    //need to grab other block

//    //blocks[alt_block_index].extra_lock(alt_block_index);
//    while(atomicCAS(locks + alt_block_index, 0, 1) == 1);

//    int fill_alt = blocks[alt_block_index].get_fill();

//    //any larger and we can't protect metadata
//    if (fill_alt >=  SLOTS_PER_BLOCK-1){
// //   	blocks[block_index.unlock()]

//    	unlock_blocks(block_index, alt_block_index);
//    	//blocks[alt_block_index].unlock();
//    	//blocks[block_index].unlock();
//    	return false;
//    }


//    //unlock main
//    if (fill_main > fill_alt ){

//    	while(atomicCAS(locks + block_index, 1, 0) == 0);
//    	//blocks[block_index].unlock();

//    	blocks[alt_block_index].insert(tag);
//    	assert(blocks[alt_block_index].get_fill() == fill_alt+1);

//    	int new_fill = blocks[alt_block_index].get_fill();
//    	if (new_fill != fill_alt+1){
//    		printf("Broken Fill: Block %llu, old %d new %d\n", alt_block_index, fill_alt, new_fill);
//    		assert(blocks[alt_block_index].get_fill() == fill_alt+1);
//    	}

//    	while(atomicCAS(locks + alt_block_index, 1, 0) == 0);
//    	//blocks[alt_block_index].unlock();


//    } else {

//    	while(atomicCAS(locks + alt_block_index, 1, 0) == 0);
//    	//blocks[alt_block_index].unlock();
//    	blocks[block_index].insert(tag);

//    	int new_fill = blocks[block_index].get_fill();
//    	if (new_fill != fill_main+1){
//    		printf("Broken Fill: Block %llu, old %d new %d\n", block_index, fill_main, new_fill);
//    		assert(blocks[block_index].get_fill() == fill_main+1);
//    	}

//    	while(atomicCAS(locks + block_index, 1, 0) == 0);
//    	//blocks[block_index].unlock();

//    }


  
//    return true;



//}


__global__ void vqf_block_setup(vqf * vqf){

	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;

	if (tid >= vqf->num_blocks) return;

	vqf->blocks[tid].setup();


	if (tid ==0) vqf->blocks[tid].printBlock();

}

__host__ vqf * build_vqf(uint64_t nitems){


	//this seems weird but whatever
	uint64_t num_blocks = (nitems -1)/SLOTS_PER_BLOCK + 1;


	vqf * host_vqf;

	vqf * dev_vqf;

	vqf_block * blocks;

	cudaMallocHost((void ** )& host_vqf, sizeof(vqf));

	cudaMalloc((void ** )& dev_vqf, sizeof(vqf));	

	//init host
	host_vqf->num_blocks = num_blocks;

	//allocate blocks
	cudaMalloc((void **)&blocks, num_blocks*sizeof(vqf_block));

	cudaMemset(blocks, 0, num_blocks*sizeof(vqf_block));

	host_vqf->blocks = blocks;


	//external locks
	int * locks;
	cudaMalloc((void ** )&locks, num_blocks*sizeof(int));
	cudaMemset(locks, 0, num_blocks*sizeof(int));


	host_vqf->locks = locks;



	cudaMemcpy(dev_vqf, host_vqf, sizeof(vqf), cudaMemcpyHostToDevice);

	cudaFreeHost(host_vqf);

	vqf_block_setup<<<(num_blocks - 1)/64 + 1, 64>>>(dev_vqf);
	cudaDeviceSynchronize();

	return dev_vqf;


}

#endif
