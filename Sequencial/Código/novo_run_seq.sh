#!/bin/bash

# ==========================================
# ENCERRA EM CASO DE ERRO
# ==========================================

set -e

# ==========================================
# TEMPO TOTAL
# ==========================================

START_TOTAL=$(date +%s)

# ==========================================
# PASTAS
# ==========================================

mkdir -p bin
mkdir -p outputs
mkdir -p resultados
mkdir -p logs

# ==========================================
# ARQUIVOS
# ==========================================

OUTPUT="outputs/cpu_resultados.csv"

STATS="resultados/cpu_stats.csv"

AMBIENTE_FILE="resultados/ambiente_cpu.txt"

# ==========================================
# AMBIENTE EXPERIMENTAL
# ==========================================

echo "===================================" > $AMBIENTE_FILE
echo "AMBIENTE EXPERIMENTAL CPU" >> $AMBIENTE_FILE
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
echo "MEMORIA:" >> $AMBIENTE_FILE
free -h >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "COMPILADOR GCC:" >> $AMBIENTE_FILE
gcc --version >> $AMBIENTE_FILE 2>/dev/null || true

echo "" >> $AMBIENTE_FILE
echo "PARTICAO SLURM:" >> $AMBIENTE_FILE
scontrol show partition lunaris \
>> $AMBIENTE_FILE 2>/dev/null || true

# ==========================================
# PARÂMETROS
# ==========================================

STEPS=10

SEED=42

REPEAT=5

ENTRADAS=(1024 2048 4096 25000 50000 100000)

echo "" >> $AMBIENTE_FILE
echo "PARAMETROS:" >> $AMBIENTE_FILE
echo "ENTRADAS: ${ENTRADAS[@]}" >> $AMBIENTE_FILE
echo "REPETICOES: $REPEAT" >> $AMBIENTE_FILE
echo "STEPS: $STEPS" >> $AMBIENTE_FILE
echo "SEED: $SEED" >> $AMBIENTE_FILE

# ==========================================
# COMPILAÇÃO
# ==========================================

echo "Compilando versão sequencial..."

gcc sequencial.c generate.c -O3 -lm -o bin/programa

# ==========================================
# LIMPA ARQUIVOS ANTIGOS
# ==========================================

rm -f $OUTPUT
rm -f $STATS

# ==========================================
# CABEÇALHOS CSV
# ==========================================

echo "N,REPETICAO,RUNTIME" > $OUTPUT

echo "N,MEDIA,DESVIO_PADRAO" > $STATS

# ==========================================
# BENCHMARK
# ==========================================

for N in "${ENTRADAS[@]}"
do

    echo "Rodando N=$N..."

    tempos=()

    for i in $(seq 1 $REPEAT)
    do

        t=$(./bin/programa $N $STEPS $SEED)

        tempos+=($t)

        echo "$N,$i,$t" >> $OUTPUT

    done

    # ======================================
    # MÉDIA
    # ======================================

    soma=0

    for t in "${tempos[@]}"
    do
        soma=$(echo "$soma + $t" | bc -l)
    done

    media=$(echo "$soma / $REPEAT" | bc -l)

    # ======================================
    # DESVIO PADRÃO
    # ======================================

    soma_diff=0

    for t in "${tempos[@]}"
    do

        diff=$(echo "$t - $media" | bc -l)

        soma_diff=$(echo "$soma_diff + ($diff * $diff)" | bc -l)

    done

    std=$(echo "sqrt($soma_diff / $REPEAT)" | bc -l)

    echo "$N,$media,$std" >> $STATS

done

# ==========================================
# TEMPO TOTAL
# ==========================================

END_TOTAL=$(date +%s)

TOTAL_TIME=$((END_TOTAL - START_TOTAL))

echo "" >> $AMBIENTE_FILE
echo "TEMPO TOTAL BENCHMARK:" >> $AMBIENTE_FILE
echo "${TOTAL_TIME} segundos" >> $AMBIENTE_FILE

# ==========================================
# FINALIZAÇÃO
# ==========================================

echo ""
echo "Benchmark concluído."

echo "Tempo total: ${TOTAL_TIME} segundos"

echo "Resultados detalhados:"
echo "$OUTPUT"

echo "Estatísticas:"
echo "$STATS"

