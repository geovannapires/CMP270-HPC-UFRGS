#include <hip/hip_runtime.h> //biblioteca do HIP

#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
#include <algorithm>

#ifndef BLOCKSIZE
#define BLOCKSIZE 256
#endif

#define ETA 0.05f
#define EPSILON 0.001f

void generateBodies(float4 *particles, float3 *velocities, unsigned int N, unsigned int seed)
{
    srand(seed);

    for (unsigned int i = 0; i < N; i++)
    {
        particles[i].x = ((float)rand()) / ((float)RAND_MAX);
        particles[i].y = ((float)rand()) / ((float)RAND_MAX);
        particles[i].z = ((float)rand()) / ((float)RAND_MAX);

        velocities[i].x = ((float)rand()) / ((float)RAND_MAX);
        velocities[i].y = ((float)rand()) / ((float)RAND_MAX);
        velocities[i].z = ((float)rand()) / ((float)RAND_MAX);

        particles[i].w = (((float)rand()) / ((float)RAND_MAX)) + 0.001f;
    }
}

__device__
    float3
    interaction(float3 particleAcceleration, float4 iParticle, float4 jParticle, int self, float epsilonSquared)
{

   
    float rx = iParticle.x - jParticle.x;
    float ry = iParticle.y - jParticle.y;
    float rz = iParticle.z - jParticle.z;

    float rSquared =
        rx * rx +
        ry * ry +
        rz * rz +
        epsilonSquared;

 
    float inv_r = rsqrtf(rSquared);
    float inv_r3 = inv_r * inv_r * inv_r;

    float coef = (1.0f - (float)self) * jParticle.w * inv_r3;

    particleAcceleration.x -= coef * rx;
    particleAcceleration.y -= coef * ry;
    particleAcceleration.z -= coef * rz;

    return particleAcceleration;
}


__global__ void computeAccelerations(float4 *p, float3 *calculatedAcc, unsigned int N, float *accels, float epsilon)
{
   
    __shared__ float4 tile[BLOCKSIZE];

        
        int i = blockIdx.x * blockDim.x + threadIdx.x;

   
    if (i >= N)
        return;
    
    float4 pi = p[i];

    float3 ai = {0.f, 0.f, 0.f};

    float epsilonSquared = epsilon * epsilon;

    int numTiles = (N + BLOCKSIZE - 1) / BLOCKSIZE;

    for (int t = 0; t < numTiles; t++)
    {

        int idx = t * BLOCKSIZE + threadIdx.x;

        if (idx < N)
            tile[threadIdx.x] = p[idx];

        __syncthreads();

        int tileSize = min(BLOCKSIZE, (int)(N - t * BLOCKSIZE));

#pragma unroll 32
        for (int j = 0; j < tileSize; j++)
        {

            int global_j = t * BLOCKSIZE + j;

            ai = interaction(ai, pi, tile[j], global_j == i, epsilonSquared);
        }

        __syncthreads();
    }

    calculatedAcc[i] = ai;

    accels[i] =
        ai.x * ai.x +
        ai.y * ai.y +
        ai.z * ai.z;
}

__global__ void firstStepParticles(float4 *p, float3 *oldP, float3 *v, float3 *a, float *accels, float *dtOldP, unsigned int N, float eta, float epsilon)
{

    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i >= N)
        return;

    float dt =
        sqrtf(eta * epsilon / accels[0]);

    oldP[i].x = p[i].x;
    oldP[i].y = p[i].y;
    oldP[i].z = p[i].z;
    p[i].x = oldP[i].x + v[i].x * dt + 0.5f * a[i].x * dt * dt;
    p[i].y = oldP[i].y + v[i].y * dt + 0.5f * a[i].y * dt * dt;
    p[i].z = oldP[i].z + v[i].z * dt + 0.5f * a[i].z * dt * dt;

    if (i == 0)
        *dtOldP = dt;
}

__global__ void stepParticles(float4 *p, float3 *oldP, float3 *a, float *accels, unsigned int N, float eta, float epsilon, float *dtOldP)
{

    int i = blockIdx.x * blockDim.x + threadIdx.x;

    if (i >= N)
        return;

    float dt =
        sqrtf(eta * epsilon / accels[0]);

    float dtOld = *dtOldP;

    float newX = p[i].x + (p[i].x - oldP[i].x) * (dt / dtOld) + a[i].x * dt * (dt + dtOld) / 2.0f;
    float newY = p[i].y + (p[i].y - oldP[i].y) * (dt / dtOld) + a[i].y * dt * (dt + dtOld) / 2.0f;
    float newZ = p[i].z + (p[i].z - oldP[i].z) * (dt / dtOld) + a[i].z * dt * (dt + dtOld) / 2.0f;

    oldP[i].x = p[i].x;
    oldP[i].y = p[i].y;
    oldP[i].z = p[i].z;

    p[i].x = newX;
    p[i].y = newY;
    p[i].z = newZ;

    if (i == 0)
        *dtOldP = dt;
}

__global__ void parallelMax(float *accels, unsigned int N, int stepSize)
{
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    int nThreads = N >> 1;

    if (i < nThreads)
    {
        int firstIndex = i * stepSize * 2;
        int secondIndex = firstIndex + stepSize;
        float first = accels[firstIndex];
        float second = accels[secondIndex];
        float biggest = first > second ? first : second;

        if (N % 2 != 0 && i == nThreads - 1)  
        {
            float third = accels[secondIndex + stepSize];
            biggest = third > biggest ? third : biggest;
        }

        accels[firstIndex] = biggest;
    }
}

int main(int argc, char **argv)
{

    if (argc != 4)
    {
        fprintf(stderr,
                "Use: %s <particles> <steps> <seed>\n",
                argv[0]);
        exit(1);
    }

    int arg1 = atoi(argv[1]);
    int arg2 = atoi(argv[2]);
    int arg3 = atoi(argv[3]);
    if (arg1 <= 0 || arg2 <= 0 || arg3 <= 0)
    {
        fprintf(stderr, "Use: %s <num. of particles> <num. of steps> <seed>\n", argv[0]);
        exit(1);
    }

    unsigned int N = (unsigned int)arg1;
    unsigned int NSteps = (unsigned int)arg2;
    unsigned int seed = (unsigned int)arg3;
    float eta, epsilon;
    float4 *p = (float4 *)malloc(N * sizeof(float4));
    float3 *v = (float3 *)malloc(N * sizeof(float3));
    generateBodies(p, v, N, seed);

    eta = ETA;
    epsilon = EPSILON;

    struct timespec start, finish;
    double elapsed;

    clock_gettime(CLOCK_MONOTONIC, &start);

    float4 *dp;
    float3 *dPOld, *dV, *dA;
    float *dAccels, *dDtOld;

    hipMalloc(&dp, N * sizeof(float4));
    hipMalloc(&dPOld, N * sizeof(float3));
    hipMalloc(&dV, N * sizeof(float3));
    hipMalloc(&dA, N * sizeof(float3));
    hipMalloc(&dAccels, N * sizeof(float));
    hipMalloc(&dDtOld, sizeof(float));
    hipMemcpy(dp, p, N * sizeof(float4), hipMemcpyHostToDevice);
    hipMemcpy(dV, v, N * sizeof(float3), hipMemcpyHostToDevice);

    int gridSize = (N + BLOCKSIZE - 1) / BLOCKSIZE;

    computeAccelerations<<<gridSize, BLOCKSIZE>>>(
        dp, dA, N, dAccels, epsilon
    );

    int numAccels = N;
    int stepSize = 1;
    int accelGridSize;
    while (numAccels > 1) {
        accelGridSize = ((numAccels >> 1) + BLOCKSIZE - 1) / BLOCKSIZE;
        parallelMax<<<accelGridSize, BLOCKSIZE>>>(
            dAccels, numAccels, stepSize
        );
        numAccels >>= 1;
        stepSize <<= 1;
    }

    firstStepParticles<<<gridSize, BLOCKSIZE>>>(
        dp, dPOld, dV, dA, dAccels, dDtOld, N, eta, epsilon
    );

    for (int step = 1; step < NSteps; step++) {
        computeAccelerations<<<gridSize, BLOCKSIZE>>>(
            dp, dA, N, dAccels, epsilon
        );

        numAccels = N;
        stepSize = 1;
        while (numAccels > 1) {
            accelGridSize = ((numAccels >> 1) + BLOCKSIZE - 1) / BLOCKSIZE;
            parallelMax<<<accelGridSize, BLOCKSIZE>>>(
                dAccels, numAccels, stepSize
            );
            numAccels >>= 1;
            stepSize <<= 1;
        }

        stepParticles<<<gridSize, BLOCKSIZE>>>(
            dp, dPOld, dA, dAccels, N, eta, epsilon, dDtOld
        );
    }

    hipDeviceSynchronize();

    hipMemcpy(p, dp, N*sizeof(float4), hipMemcpyDeviceToHost);

    clock_gettime(CLOCK_MONOTONIC, &finish);

    elapsed = finish.tv_sec - start.tv_sec;
    elapsed += (finish.tv_nsec - start.tv_nsec) * 1e-9;

    printf("%lf\n", elapsed);

#ifdef DEBUG
    for (int i = 0; i < N; i++)
        printf("%.6f,%.6f,%.6f\n", p[i].x, p[i].y, p[i].z);
#endif

    hipFree(dp);
    hipFree(dPOld);
    hipFree(dV);
    hipFree(dA);
    hipFree(dAccels);
    hipFree(dDtOld);

    free(p);
    free(v);

    return 0;

}