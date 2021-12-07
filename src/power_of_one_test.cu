/*
 * ============================================================================
 *
 *        Authors:  
 *                  Hunter McCoy <hjmccoy@lbl.gov
 *
 * ============================================================================
 */

#include <cuda.h>
#include <stdio.h>
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>
#include <time.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/mman.h>
#include <unistd.h>
#include <random>
#include <assert.h>
#include <chrono>
#include <iostream>

#include <fstream>
#include <string>
#include <algorithm>
#include <bitset>


#include "include/single_vqf.cuh"

#include <openssl/rand.h>


#define BLOCK_SIZE 512

__global__ void test_insert_kernel(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;


	uint64_t teamID = tid / 32;
	int warpID = tid % 32;

	//if (tid > 0) return;
	if (teamID >= nvals) return;

	//vals[teamID] = teamID;

	if (!my_vqf->insert(warpID, vals[teamID])){



		if (warpID == 0){

			atomicAdd( (unsigned long long int *) misses, 1);

			inserts[teamID] = 1;

		}
		
	} //else {


	// 	// if (!my_vqf->query(warpID, vals[teamID])){
	// 	// 	assert(my_vqf->query(warpID, vals[teamID]));
	// 	// }
		
	// }



	//printf("tid %llu done\n", tid);

	// //does a single thread have this issue?
	// for (uint64_t i =0; i< nvals; i++){

	// 	assert(vals[i] != 0);

	// 	my_vqf->insert(vals[i]);

	// }
	
}


__global__ void bulk_insert_kernel(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){


	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;

	uint64_t teamID = tid/32;

	int warpID = tid % 32;

	if (teamID >= my_vqf->num_blocks) return;

	my_vqf->buffer_insert(warpID, teamID);

	if (warpID == 0)
	atomicAdd( (unsigned long long int *) misses, my_vqf->buffer_sizes[teamID]);

}


__global__ void test_query_kernel(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;


	uint64_t teamID = tid / 32;
	int warpID = tid % 32;

	//if (tid > 0) return;
	if (teamID >= nvals) return;


	if (!inserts[teamID]){



	if(!my_vqf->query(warpID, vals[teamID])){

		my_vqf->query(warpID, vals[teamID]);

		if (warpID == 0)
		atomicAdd( (unsigned long long int *) misses, 1);
	}

	}


	//printf("tid %llu done\n", tid);

	// //does a single thread have this issue?
	// for (uint64_t i =0; i< nvals; i++){

	// 	assert(vals[i] != 0);

	// 	my_vqf->insert(vals[i]);

	// }
	
}


__global__ void test_remove_kernel(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;


	uint64_t teamID = tid / 32;
	int warpID = tid % 32;

	//if (tid > 0) return;
	if (teamID >= nvals) return;


	if (!inserts[teamID]){



	if(!my_vqf->remove(warpID, vals[teamID])){
		if (warpID == 0)
		atomicAdd( (unsigned long long int *) misses, 1);
	}


	}



	//printf("tid %llu done\n", tid);

	// //does a single thread have this issue?
	// for (uint64_t i =0; i< nvals; i++){

	// 	assert(vals[i] != 0);

	// 	my_vqf->insert(vals[i]);

	// }
	
}


__global__ void wipe_vals(uint64_t * vals, uint64_t nvals){

	uint64_t tid = threadIdx.x + blockDim.x*blockIdx.x;

	if (tid >=nvals) return;

	vals[tid] = tid;
}



__host__ void insert_timing(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	auto start = std::chrono::high_resolution_clock::now();


	test_insert_kernel<<<(32*nvals -1) / BLOCK_SIZE + 1, BLOCK_SIZE>>>(my_vqf, vals, inserts, nvals, misses);


	cudaDeviceSynchronize();
	//and insert

	auto end = std::chrono::high_resolution_clock::now();


  	std::chrono::duration<double> diff = end-start;


  	std::cout << "Inserted " << nvals << " in " << diff.count() << " seconds\n";

  	printf("Inserts per second: %f\n", nvals/diff.count());

  	printf("Misses %llu\n", misses[0]);

  	cudaDeviceSynchronize();

  	misses[0] = 0;

  	cudaDeviceSynchronize();
}


__host__ void bulk_insert_timing(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	auto start = std::chrono::high_resolution_clock::now();

	my_vqf->attach_buffers(vals, nvals);

	uint64_t num_buffers = my_vqf->get_num_buffers();

	cudaDeviceSynchronize();

	auto mid = std::chrono::high_resolution_clock::now();



	bulk_insert_kernel<<<(32*num_buffers -1) / BLOCK_SIZE + 1, BLOCK_SIZE>>>(my_vqf, vals, inserts, nvals, misses);


	cudaDeviceSynchronize();
	//and insert

	auto end = std::chrono::high_resolution_clock::now();


  	std::chrono::duration<double> diff = end-start;


  	std::chrono::duration<double> sort_diff = mid - start;

  	std::chrono::duration<double> insert_diff = end - mid;




  	std::cout << "Bulk Inserted " << nvals << " in " << diff.count() << " seconds\n";

  	std::cout << "Sorted " << nvals << " in " << sort_diff.count() << " seconds\n";

  	std::cout << "Items Inserted " << nvals << " in " << insert_diff.count() << " seconds\n";

  	printf("Inserts per second: %f\n", nvals/diff.count());


  	printf("Misses %llu\n", misses[0]);

  	cudaDeviceSynchronize();

  	misses[0] = 0;

  	cudaDeviceSynchronize();
}

__host__ void query_timing(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	auto start = std::chrono::high_resolution_clock::now();


	test_query_kernel<<<(32*nvals -1) / BLOCK_SIZE + 1, BLOCK_SIZE>>>(my_vqf, vals, inserts, nvals, misses);


	cudaDeviceSynchronize();
	//and insert

	auto end = std::chrono::high_resolution_clock::now();


  	std::chrono::duration<double> diff = end-start;


  	std::cout << "Queried " << nvals << " in " << diff.count() << " seconds\n";

  	printf("Queries per second: %f\n", nvals/diff.count());

  	printf("Misses %llu\n", misses[0]);

  	cudaDeviceSynchronize();

  	misses[0] = 0;

  	cudaDeviceSynchronize();
}


__host__ void remove_timing(vqf* my_vqf, uint64_t * vals, bool * inserts, uint64_t nvals, uint64_t * misses){

	auto start = std::chrono::high_resolution_clock::now();


	test_remove_kernel<<<(32*nvals -1) / BLOCK_SIZE + 1, BLOCK_SIZE>>>(my_vqf, vals, inserts, nvals, misses);


	cudaDeviceSynchronize();
	//and insert

	auto end = std::chrono::high_resolution_clock::now();


  	std::chrono::duration<double> diff = end-start;


  	std::cout << "removed " << nvals << " in " << diff.count() << " seconds\n";

  	printf("removes per second: %f\n", nvals/diff.count());

  	printf("Misses %llu\n", misses[0]);

  	cudaDeviceSynchronize();

  	misses[0] = 0;

  	cudaDeviceSynchronize();
}

int main(int argc, char** argv) {
	

	uint64_t nbits = atoi(argv[1]);


	uint64_t nitems = (1ULL << nbits) * .8;

	uint64_t * vals;
	uint64_t * dev_vals;

	uint64_t * other_vals;
	uint64_t * dev_other_vals;

	vals = (uint64_t*) malloc(nitems*sizeof(vals[0]));

	RAND_bytes((unsigned char *)vals, sizeof(*vals) * nitems);


	// other_vals = (uint64_t*) malloc(nitems*sizeof(other_vals[0]));

	// RAND_bytes((unsigned char *)other_vals, sizeof(*other_vals) * nitems);




	cudaMalloc((void ** )& dev_vals, nitems*sizeof(vals[0]));

	cudaMemcpy(dev_vals, vals, nitems * sizeof(vals[0]), cudaMemcpyHostToDevice);


	bool * inserts;


	cudaMalloc((void ** )& inserts, nitems*sizeof(bool));

	cudaMemset(inserts, 0, nitems*sizeof(bool));



	// cudaMalloc((void ** )& dev_other_vals, nitems*sizeof(other_vals[0]));

	// cudaMemcpy(dev_other_vals, other_vals, nitems * sizeof(other_vals[0]), cudaMemcpyHostToDevice);


	//allocate misses counter
	uint64_t * misses;
	cudaMallocManaged((void **)& misses, sizeof(uint64_t));

	misses[0] = 0;


	vqf * my_vqf =  build_vqf(1 << nbits);


	printf("Setup done\n");

	//wipe_vals<<<nitems/32+1, 32>>>(dev_vals, nitems);


	cudaDeviceSynchronize();

	


	cudaDeviceSynchronize();

	
	bulk_insert_timing(my_vqf, dev_vals, inserts, nitems,  misses);

	cudaMemcpy(dev_vals, vals, nitems * sizeof(vals[0]), cudaMemcpyHostToDevice);

	cudaDeviceSynchronize();

	query_timing(my_vqf, dev_vals, inserts, nitems,  misses);


	cudaMemcpy(dev_vals, vals, nitems * sizeof(vals[0]), cudaMemcpyHostToDevice);

	cudaDeviceSynchronize();


	remove_timing(my_vqf, dev_vals, inserts, nitems,  misses);

	cudaDeviceSynchronize();
	//and insert

	auto end = std::chrono::high_resolution_clock::now();


	free(vals);

	cudaFree(dev_vals);

	cudaFree(misses);

	

	return 0;

}