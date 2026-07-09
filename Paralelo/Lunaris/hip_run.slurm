#!/bin/bash
#SBATCH --job-name=hip_benchmark
#SBATCH --partition=lunaris
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --gres=gpu:1
#SBATCH --time=02:00:00
#SBATCH --output=logs/%x_%j.out
#SBATCH --error=logs/%x_%j.err

# ==========================================
# ENCERRA SCRIPT EM CASO DE ERRO
# ==========================================

set -e

# ==========================================
# TEMPO TOTAL DO BENCHMARK
# ==========================================

START_TOTAL=$(date +%s)

# ==========================================
# PASTAS
# ==========================================

mkdir -p bin
mkdir -p outputs
mkdir -p logs
mkdir -p resultados

# ==========================================
# AMBIENTE EXPERIMENTAL
# ==========================================

AMBIENTE_FILE="resultados/ambiente_gpu.txt"

echo "===================================" > $AMBIENTE_FILE
echo "AMBIENTE EXPERIMENTAL GPU" >> $AMBIENTE_FILE
echo "===================================" >> $AMBIENTE_FILE

echo "" >> $AMBIENTE_FILE
echo "DATA:" >> $AMBIENTE_FILE
date >> $AMBIENTE_FILE

echo "" >> $AMBIENTE_FILE
echo "NO:" >> $AMBIENTE_FILE
hostname >> $AMBIENTE_FILE

echo "" >> $AMBIENTE_FILE
echo "CPU:" >> $AMBIENTE_FILE
lscpu >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "HIPCC:" >> $AMBIENTE_FILE
hipcc --version >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "HIPCONFIG:" >> $AMBIENTE_FILE
hipconfig >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "GPU:" >> $AMBIENTE_FILE
rocminfo >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "ROCM-SMI:" >> $AMBIENTE_FILE
rocm-smi >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "PARTICAO SLURM:" >> $AMBIENTE_FILE
scontrol show partition lunaris >> $AMBIENTE_FILE 2>/dev/null || true

# ==========================================
# PARÂMETROS
# ==========================================

ENTRADAS=(1024 2048 4096 25000 50000 100000)

REPETICOES=5

STEPS=10

SEED=42

echo "" >> $AMBIENTE_FILE
echo "PARAMETROS:" >> $AMBIENTE_FILE
echo "ENTRADAS: ${ENTRADAS[@]}" >> $AMBIENTE_FILE
echo "REPETICOES: $REPETICOES" >> $AMBIENTE_FILE
echo "STEPS: $STEPS" >> $AMBIENTE_FILE
echo "SEED: $SEED" >> $AMBIENTE_FILE

# ==========================================
# COMPILAÇÕES
# ==========================================

echo "Compilando versões HIP..."

hipcc hip_nbody.cpp -O3 -DBLOCKSIZE=64  -o bin/hip_64
hipcc hip_nbody.cpp -O3 -DBLOCKSIZE=128 -o bin/hip_128
hipcc hip_nbody.cpp -O3 -DBLOCKSIZE=256 -o bin/hip_256

# ==========================================
# LIMPA ARQUIVOS ANTIGOS
# ==========================================

rm -f outputs/runtime_bs64.csv
rm -f outputs/runtime_bs128.csv
rm -f outputs/runtime_bs256.csv

rm -f resultados/hip_resultados.csv

# ==========================================
# CABEÇALHOS CSV
# ==========================================

echo "N,BLOCKSIZE,REPETICAO,RUNTIME" \
> outputs/runtime_bs64.csv

echo "N,BLOCKSIZE,REPETICAO,RUNTIME" \
> outputs/runtime_bs128.csv

echo "N,BLOCKSIZE,REPETICAO,RUNTIME" \
> outputs/runtime_bs256.csv

# ==========================================
# BENCHMARK BLOCKSIZE 64
# ==========================================

echo "Executando BLOCKSIZE 64..."

for N in "${ENTRADAS[@]}"
do
    for ((i=1; i<=REPETICOES; i++))
    do

        TEMPO=$(./bin/hip_64 $N $STEPS $SEED)

        echo "$N,64,$i,$TEMPO" \
        >> outputs/runtime_bs64.csv

    done
done

# ==========================================
# BENCHMARK BLOCKSIZE 128
# ==========================================

echo "Executando BLOCKSIZE 128..."

for N in "${ENTRADAS[@]}"
do
    for ((i=1; i<=REPETICOES; i++))
    do

        TEMPO=$(./bin/hip_128 $N $STEPS $SEED)

        echo "$N,128,$i,$TEMPO" \
        >> outputs/runtime_bs128.csv

    done
done

# ==========================================
# BENCHMARK BLOCKSIZE 256
# ==========================================

echo "Executando BLOCKSIZE 256..."

for N in "${ENTRADAS[@]}"
do
    for ((i=1; i<=REPETICOES; i++))
    do

        TEMPO=$(./bin/hip_256 $N $STEPS $SEED)

        echo "$N,256,$i,$TEMPO" \
        >> outputs/runtime_bs256.csv

    done
done

# ==========================================
# JUNTA RESULTADOS
# ==========================================

cat outputs/runtime_bs64.csv  > resultados/hip_resultados.csv

tail -n +2 outputs/runtime_bs128.csv \
>> resultados/hip_resultados.csv

tail -n +2 outputs/runtime_bs256.csv \
>> resultados/hip_resultados.csv

# ==========================================
# TEMPO TOTAL DO BENCHMARK
# ==========================================

END_TOTAL=$(date +%s)

TOTAL_TIME=$((END_TOTAL - START_TOTAL))

echo "" >> $AMBIENTE_FILE
echo "TEMPO TOTAL BENCHMARK:" >> $AMBIENTE_FILE
echo "${TOTAL_TIME} segundos" >> $AMBIENTE_FILE

echo ""
echo "Benchmark concluído."
echo "Tempo total: ${TOTAL_TIME} segundos"
