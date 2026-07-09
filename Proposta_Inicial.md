# Trabalho Final — CMP270: Introduction to High Performance Computing

**Título:** Paralelização do Problema N-Corpos com HIP

---

## Descrição

O discente implementa uma simulação gravitacional N-Corpos nas duas versões abaixo, analisa o desempenho e discute brevemente as escolhas de paralelização à luz dos padrões do Mattson et al.

---

## Implementações

**Versão 1 — Sequencial** (baseline)
Implementar o algoritmo direto O(N²) em C/C++. Medir o tempo para N = 1k, 2k e 4k partículas.

<!--**Versão 2 — MPI**
Distribuir as partículas entre processos (*Geometric Decomposition*). Usar `MPI_Allgather` para compartilhar posições e `MPI_Reduce` para consolidar forças. Testar com 1, 2, 4 e 8 processos.

**Versão 3 — OpenMP**
Paralelizar o laço de cálculo de forças com `#pragma omp parallel for reduction`. Testar com 1, 2, 4 e 8 threads.
-->
**Versão 2 — HIP (GPU)**
Implementar o kernel de cálculo de forças em HIP, onde cada thread GPU é responsável por uma partícula. Gerenciar as transferências de memória host↔device com `hipMemcpy`. Testar com diferentes tamanhos de bloco (`blockDim`: 64, 128, 256) e comparar com as versões CPU.

```cpp
__global__ void calcForces(float *px, float *py, float *pz,
                            float *fx, float *fy, float *fz, int N) {
    int i = blockIdx.x * blockDim.x + threadIdx.x;
    if (i >= N) return;
    // cada thread calcula a força total sobre a partícula i
    for (int j = 0; j < N; j++) { /* ... */ }
}
```

---

## Análise de Desempenho

Para cada versão, calcular e plotar:

- **Speedup:** S(p) = T(1) / T(p)
<!-- - **Eficiência:** E(p) = S(p) / p *(para MPI e OpenMP)* -->
- Para HIP: discutir o impacto do tamanho do bloco e do overhead de transferência host↔device

Discutir brevemente por que a eficiência cai com mais processos/threads (Lei de Amdahl) e em que situações a GPU supera ou não a CPU.

---

## Conexão com Mattson et al.

| Versão  | Padrão                  | Mecanismo                        |
|---------|-------------------------|----------------------------------|
<!-- | MPI     | Geometric Decomposition | `MPI_Allgather`, `MPI_Reduce`    |
| OpenMP  | Loop Parallelism        | `omp parallel for reduction`     | -->
| HIP     | Data Parallelism        | kernel, `blockDim`, `gridDim`    |

---

## Reflexão: O Problema N-Corpos é Fácil de Paralelizar?

Sim e não — depende do nível de análise.

**No sentido amplo, sim**, é considerado "embaraçosamente paralelo" (*embarrassingly parallel*) na fase de cálculo de forças: cada par (i, j) pode ser calculado de forma completamente independente, sem nenhuma comunicação intermediária. Isso torna a decomposição de dados muito natural e é por isso que ele é tão usado como exemplo didático.

**Mas há complicações reais** que tornam a paralelização menos trivial do que parece:

- **Dependência global de dados.** Ao final de cada passo de tempo, todo processo precisa conhecer as posições de *todas* as partículas para o passo seguinte. <!-- Isso exige um `MPI_Allgather` global — uma comunicação coletiva cujo custo cresce com o número de processos e pode se tornar o gargalo dominante. -->

- **Balanceamento de carga.** Na versão O(N²) com distribuição uniforme de partículas, o balanceamento é simples. Mas se o domínio for espacialmente não-uniforme (partículas agrupadas em clusters), alguns processos ficam sobrecarregados.

- **Na GPU (HIP/CUDA).** O acesso à memória global para leitura das posições de todas as N partículas por cada thread gera muita pressão no barramento. O desempenho real depende fortemente do uso de memória compartilhada (*shared memory*) dentro de cada bloco — sem isso, o kernel fica limitado pela largura de banda, não pela capacidade de cômputo.

- **Lei de Amdahl na prática.** A fase de integração das posições e a atualização do estado global são inerentemente sequenciais ou exigem sincronização, formando a fração serial que limita o speedup máximo.

Em resumo: é um problema **fácil de paralelizar na primeira versão**, mas **difícil de paralelizar bem** — o que o torna pedagogicamente muito rico, pois expõe exatamente os conceitos centrais da CMP270.

---

## Bibliografia

MATTSON, Timothy G.; SANDERS, Beverly A.; MASSINGILL, Berna L. **Patterns for Parallel Programming**. Boston: Addison-Wesley, 2005. (Software Patterns Series).

ARCENCIO, Guilherme G.; GUARDIA, Hélio Crestana. Study and analysis of parallel N-body simulations. In: ESCOLA REGIONAL DE ALTO DESEMPENHO DE SÃO PAULO (ERAD-SP), 15. , 2024, Rio Claro/SP. Anais [...]. Porto Alegre: Sociedade Brasileira de Computação, 2024 . p. 5-8. DOI: https://doi.org/10.5753/eradsp.2024.239679. 
