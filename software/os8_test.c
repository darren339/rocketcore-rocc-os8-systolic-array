#include <stdio.h>
#include <stdint.h>
#include "rocc.h"
#include "external_weights.h"

#define TILE 8
#define TILE_ELEMS 64
#define MAX_DIM 32
#define MAX_ELEMS (MAX_DIM * MAX_DIM)
#define NUM_CNN_TESTS 8
#define MAX_B_REUSE_COUNT 10

#define OS8_OPCODE        0

#define OS8_FUNCT_SET_A   0
#define OS8_FUNCT_SET_B   1
#define OS8_FUNCT_SET_C   2
#define OS8_FUNCT_START   3
#define OS8_FUNCT_ACT_CFG 7

#define OS8_FUNCT_LOAD_A        8
#define OS8_FUNCT_LOAD_B        9
#define OS8_FUNCT_COMPUTE       10
#define OS8_FUNCT_STORE_C       11
#define OS8_FUNCT_LOAD_AB       12
#define OS8_FUNCT_COMPUTE_STORE 13

typedef int8_t  data_t;
typedef int32_t acc_t;

typedef enum {
    PATTERN_RANDOM = 0,
    PATTERN_4BIT,
    PATTERN_SPARSE,
    PATTERN_EXTERNAL_WEIGHTS,
    PATTERN_IDENTITY,
    PATTERN_ALL_ONES
} pattern_t;

typedef struct {
    pattern_t a_pattern;
    pattern_t b_pattern;
    int seed;
    int relu;
    int shift;
    const char *name;
} test_cfg_t;

/*
 * Buffers for normal Type 1A test.
 */
static data_t A_big[MAX_ELEMS] __attribute__((aligned(8)));
static data_t B_big[MAX_ELEMS] __attribute__((aligned(8)));
static acc_t  C_sw_big[MAX_ELEMS] __attribute__((aligned(8)));
static acc_t  C_hw_big[MAX_ELEMS] __attribute__((aligned(8)));

/*
 * Buffers for Type 1B and Type 1C B-reuse tests.
 * The maximum reuse count is 10. For 5x reuse, only the first 5 entries are used.
 */
static data_t A_set[MAX_B_REUSE_COUNT][MAX_ELEMS] __attribute__((aligned(8)));
static acc_t  C_sw_set[MAX_B_REUSE_COUNT][MAX_ELEMS] __attribute__((aligned(8)));
static acc_t  C_hw_set[MAX_B_REUSE_COUNT][MAX_ELEMS] __attribute__((aligned(8)));

/*
 * Tile buffers used by all tests.
 */
static data_t A_buf[TILE_ELEMS] __attribute__((aligned(8)));
static data_t B_buf[TILE_ELEMS] __attribute__((aligned(8)));
static acc_t  C_hw_tile[TILE_ELEMS] __attribute__((aligned(8)));
static acc_t  C_sw_tile[TILE_ELEMS] __attribute__((aligned(8)));

static test_cfg_t cnn_tests[NUM_CNN_TESTS] = {
    { PATTERN_RANDOM,           PATTERN_RANDOM,           23, 0, 0, "8x8 random INT8 baseline" },
    { PATTERN_4BIT,             PATTERN_4BIT,             11, 0, 0, "8x8 4-bit-style activation and weight" },
    { PATTERN_RANDOM,           PATTERN_4BIT,             17, 0, 0, "8x8 INT8 activation x 4-bit-style weight" },
    { PATTERN_RANDOM,           PATTERN_SPARSE,           19, 0, 0, "8x8 sparse weight case" },
    { PATTERN_RANDOM,           PATTERN_EXTERNAL_WEIGHTS, 29, 0, 0, "8x8 external_weights.h weight case" },
    { PATTERN_RANDOM,           PATTERN_EXTERNAL_WEIGHTS, 29, 1, 0, "8x8 external weights with ReLU" },
    { PATTERN_RANDOM,           PATTERN_EXTERNAL_WEIGHTS, 29, 1, 2, "8x8 external weights with ReLU + shift 2" },
    { PATTERN_IDENTITY,         PATTERN_EXTERNAL_WEIGHTS, 31, 0, 0, "8x8 identity A copies external B" }
};

static inline uint64_t read_cycle(void)
{
    uint64_t x;
    asm volatile ("rdcycle %0" : "=r"(x));
    return x;
}

static data_t gen_random_int8(int index, int seed)
{
    int v = ((index * 17 + seed * 13 + (index >> 1)) % 17) - 8;

    if (((index + seed) % 11) == 0)
        v = -128;

    if (((index + seed) % 13) == 0)
        v = 127;

    return (data_t)v;
}

static data_t gen_4bit_style(int index, int seed)
{
    int v = ((index * 5 + seed * 3 + 7) % 15) - 8;
    return (data_t)v;
}

static data_t gen_sparse_4bit_style(int index, int seed)
{
    if (((index + seed) % 3) != 0)
        return 0;

    return gen_4bit_style(index, seed);
}

static data_t get_external_weight(int index)
{
    return external_weights_array[index % TILE_ELEMS];
}

static acc_t apply_activation(acc_t value, int relu, int shift)
{
    acc_t shifted = value >> shift;

    if (relu && shifted < 0)
        return 0;

    return shifted;
}

static void clear_tile_buffers(void)
{
    for (int i = 0; i < TILE_ELEMS; i++) {
        A_buf[i] = 0;
        B_buf[i] = 0;
        C_hw_tile[i] = 0;
        C_sw_tile[i] = 0;
    }
}

static void clear_big_buffers(void)
{
    for (int i = 0; i < MAX_ELEMS; i++) {
        A_big[i] = 0;
        B_big[i] = 0;
        C_sw_big[i] = 0;
        C_hw_big[i] = 0;
    }
}

static void clear_reuse_buffers(int reuse_count)
{
    for (int r = 0; r < reuse_count; r++) {
        for (int i = 0; i < MAX_ELEMS; i++) {
            A_set[r][i] = 0;
            C_sw_set[r][i] = 0;
            C_hw_set[r][i] = 0;
        }
    }

    for (int i = 0; i < MAX_ELEMS; i++) {
        B_big[i] = 0;
    }
}

static void print_i8_matrix(const char *title, data_t *mat)
{
    printf("%s\n", title);

    for (int r = 0; r < TILE; r++) {
        printf("[");
        for (int c = 0; c < TILE; c++) {
            printf("%4d", mat[r * TILE + c]);
            if (c != TILE - 1)
                printf(",");
        }
        printf(" ]\n");
    }
}

static void print_i32_matrix(const char *title, acc_t *mat)
{
    printf("%s\n", title);

    for (int r = 0; r < TILE; r++) {
        printf("[");
        for (int c = 0; c < TILE; c++) {
            printf("%8d", mat[r * TILE + c]);
            if (c != TILE - 1)
                printf(",");
        }
        printf(" ]\n");
    }
}

static void fill_matrix_pattern(data_t *mat, pattern_t pattern, int seed)
{
    for (int i = 0; i < TILE_ELEMS; i++) {
        switch (pattern) {
            case PATTERN_RANDOM:
                mat[i] = gen_random_int8(i, seed);
                break;

            case PATTERN_4BIT:
                mat[i] = gen_4bit_style(i, seed);
                break;

            case PATTERN_SPARSE:
                mat[i] = gen_sparse_4bit_style(i, seed);
                break;

            case PATTERN_EXTERNAL_WEIGHTS:
                mat[i] = get_external_weight(i);
                break;

            case PATTERN_IDENTITY:
                mat[i] = 0;
                break;

            case PATTERN_ALL_ONES:
                mat[i] = 1;
                break;

            default:
                mat[i] = 0;
                break;
        }
    }

    if (pattern == PATTERN_IDENTITY) {
        for (int r = 0; r < TILE; r++) {
            for (int c = 0; c < TILE; c++) {
                mat[r * TILE + c] = (r == c) ? 1 : 0;
            }
        }
    }
}

static void fill_big_inputs(int dim, int seed)
{
    for (int i = 0; i < dim * dim; i++) {
        A_big[i] = gen_random_int8(i, seed);
        B_big[i] = gen_random_int8(i, seed + 31);
    }
}

static void fill_reuse_inputs(int dim, int seed, int reuse_count)
{
    /*
     * One B matrix is generated and reused across reuse_count different A matrices.
     */
    for (int i = 0; i < dim * dim; i++) {
        B_big[i] = gen_random_int8(i, seed + 1000);
    }

    for (int r = 0; r < reuse_count; r++) {
        for (int i = 0; i < dim * dim; i++) {
            A_set[r][i] = gen_random_int8(i, seed + (r * 37));
        }
    }
}

static void matmul_sw_big(int dim)
{
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            acc_t sum = 0;

            for (int k = 0; k < dim; k++) {
                data_t a = A_big[i * dim + k];
                data_t b = B_big[k * dim + j];

                sum += (acc_t)a * (acc_t)b;
            }

            C_sw_big[i * dim + j] = sum;
        }
    }
}

static void matmul_sw_one_reuse(int reuse_id, int dim)
{
    for (int i = 0; i < dim; i++) {
        for (int j = 0; j < dim; j++) {
            acc_t sum = 0;

            for (int k = 0; k < dim; k++) {
                data_t a = A_set[reuse_id][i * dim + k];
                data_t b = B_big[k * dim + j];

                sum += (acc_t)a * (acc_t)b;
            }

            C_sw_set[reuse_id][i * dim + j] = sum;
        }
    }
}

static void matmul_sw_all_reuse(int dim, int reuse_count)
{
    for (int r = 0; r < reuse_count; r++) {
        matmul_sw_one_reuse(r, dim);
    }
}

static void matmul_sw_tile(int relu, int shift)
{
    for (int i = 0; i < TILE; i++) {
        for (int j = 0; j < TILE; j++) {
            acc_t sum = 0;

            for (int k = 0; k < TILE; k++) {
                data_t a = A_buf[i * TILE + k];
                data_t b = B_buf[k * TILE + j];

                sum += (acc_t)a * (acc_t)b;
            }

            C_sw_tile[i * TILE + j] = apply_activation(sum, relu, shift);
        }
    }
}

static void rocc_set_a(void)
{
    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)A_buf, OS8_FUNCT_SET_A);
}

static void rocc_set_b(void)
{
    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)B_buf, OS8_FUNCT_SET_B);
}

static void rocc_set_c(void)
{
    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)C_hw_tile, OS8_FUNCT_SET_C);
}

static void rocc_set_activation(int relu, int shift)
{
    uint64_t act_cfg = 0;

    act_cfg |= (relu ? 1ULL : 0ULL);
    act_cfg |= ((uint64_t)(shift & 0x1F) << 1);

    ROCC_INSTRUCTION_S(OS8_OPCODE, act_cfg, OS8_FUNCT_ACT_CFG);
}

static void rocc_set_cfg(int relu, int shift)
{
    uint64_t act_cfg = 0;

    act_cfg |= (relu ? 1ULL : 0ULL);
    act_cfg |= ((uint64_t)(shift & 0x1F) << 1);

    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)A_buf, OS8_FUNCT_SET_A);
    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)B_buf, OS8_FUNCT_SET_B);
    ROCC_INSTRUCTION_S(OS8_OPCODE, (uintptr_t)C_hw_tile, OS8_FUNCT_SET_C);
    ROCC_INSTRUCTION_S(OS8_OPCODE, act_cfg, OS8_FUNCT_ACT_CFG);
}

static uint64_t matmul_hw_tile_cycles(int relu, int shift)
{
    uint64_t status;
    uint64_t hw_start;
    uint64_t hw_end;

    for (int i = 0; i < TILE_ELEMS; i++) {
        C_hw_tile[i] = 0;
    }

    asm volatile("fence" ::: "memory");

    hw_start = read_cycle();

    rocc_set_cfg(relu, shift);
    ROCC_INSTRUCTION_D(OS8_OPCODE, status, OS8_FUNCT_START);

    asm volatile("fence" ::: "memory");

    volatile acc_t sink = C_hw_tile[0];
    (void)sink;
    (void)status;

    hw_end = read_cycle();

    return hw_end - hw_start;
}

static uint64_t rocc_load_b_tile_cycles(void)
{
    uint64_t status;
    uint64_t start;
    uint64_t end;

    asm volatile("fence" ::: "memory");

    start = read_cycle();

    rocc_set_b();
    ROCC_INSTRUCTION_D(OS8_OPCODE, status, OS8_FUNCT_LOAD_B);

    asm volatile("fence" ::: "memory");

    volatile acc_t sink = C_hw_tile[0];
    (void)sink;
    (void)status;

    end = read_cycle();

    return end - start;
}

static uint64_t rocc_load_a_compute_store_cycles(int relu, int shift)
{
    uint64_t status;
    uint64_t start;
    uint64_t end;

    for (int i = 0; i < TILE_ELEMS; i++) {
        C_hw_tile[i] = 0;
    }

    asm volatile("fence" ::: "memory");

    start = read_cycle();

    rocc_set_a();
    rocc_set_c();
    rocc_set_activation(relu, shift);

    ROCC_INSTRUCTION_D(OS8_OPCODE, status, OS8_FUNCT_LOAD_A);
    ROCC_INSTRUCTION_D(OS8_OPCODE, status, OS8_FUNCT_COMPUTE_STORE);

    asm volatile("fence" ::: "memory");

    volatile acc_t sink = C_hw_tile[0];
    (void)sink;
    (void)status;

    end = read_cycle();

    return end - start;
}

static int compare_big_results(int dim)
{
    for (int i = 0; i < dim * dim; i++) {
        if (C_sw_big[i] != C_hw_big[i]) {
            return 0;
        }
    }

    return 1;
}

static int compare_one_reuse_result(int reuse_id, int dim)
{
    for (int i = 0; i < dim * dim; i++) {
        if (C_sw_set[reuse_id][i] != C_hw_set[reuse_id][i]) {
            return 0;
        }
    }

    return 1;
}

static int compare_all_reuse_results(int dim, int reuse_count)
{
    for (int r = 0; r < reuse_count; r++) {
        if (!compare_one_reuse_result(r, dim)) {
            return 0;
        }
    }

    return 1;
}

static int compare_tile_results(void)
{
    for (int i = 0; i < TILE_ELEMS; i++) {
        if (C_sw_tile[i] != C_hw_tile[i]) {
            return 0;
        }
    }

    return 1;
}

static void print_speedup(uint64_t sw, uint64_t hw)
{
    if (hw == 0) {
        printf("N/A");
        return;
    }

    printf("%lu.%02lu x",
           (unsigned long)(sw / hw),
           (unsigned long)(((sw % hw) * 100) / hw));
}

static uint64_t matmul_hw_big_tiled(int dim)
{
    uint64_t total_hw_cycles = 0;

    for (int ii = 0; ii < dim; ii += TILE) {
        for (int jj = 0; jj < dim; jj += TILE) {
            for (int kk = 0; kk < dim; kk += TILE) {

                clear_tile_buffers();

                for (int i = 0; i < TILE; i++) {
                    for (int k = 0; k < TILE; k++) {
                        int global_i = ii + i;
                        int global_k = kk + k;

                        if (global_i < dim && global_k < dim)
                            A_buf[i * TILE + k] = A_big[global_i * dim + global_k];
                        else
                            A_buf[i * TILE + k] = 0;
                    }
                }

                for (int k = 0; k < TILE; k++) {
                    for (int j = 0; j < TILE; j++) {
                        int global_k = kk + k;
                        int global_j = jj + j;

                        if (global_k < dim && global_j < dim)
                            B_buf[k * TILE + j] = B_big[global_k * dim + global_j];
                        else
                            B_buf[k * TILE + j] = 0;
                    }
                }

                total_hw_cycles += matmul_hw_tile_cycles(0, 0);

                for (int i = 0; i < TILE; i++) {
                    for (int j = 0; j < TILE; j++) {
                        int global_i = ii + i;
                        int global_j = jj + j;

                        if (global_i < dim && global_j < dim) {
                            C_hw_big[global_i * dim + global_j] += C_hw_tile[i * TILE + j];
                        }
                    }
                }
            }
        }
    }

    return total_hw_cycles;
}

static uint64_t matmul_hw_big_tiled_reuse_b(int dim, int reuse_count)
{
    uint64_t total_hw_cycles = 0;

    /*
     * B-reuse tiling order:
     *
     * For each output-column tile jj and K tile kk:
     * 1. Prepare one B tile.
     * 2. Load the B tile once into the accelerator.
     * 3. Reuse the stored B tile for reuse_count different A matrices.
     */
    for (int jj = 0; jj < dim; jj += TILE) {
        for (int kk = 0; kk < dim; kk += TILE) {

            clear_tile_buffers();

            for (int k = 0; k < TILE; k++) {
                for (int j = 0; j < TILE; j++) {
                    int global_k = kk + k;
                    int global_j = jj + j;

                    if (global_k < dim && global_j < dim) {
                        B_buf[k * TILE + j] = B_big[global_k * dim + global_j];
                    } else {
                        B_buf[k * TILE + j] = 0;
                    }
                }
            }

            total_hw_cycles += rocc_load_b_tile_cycles();

            for (int r = 0; r < reuse_count; r++) {
                for (int ii = 0; ii < dim; ii += TILE) {

                    for (int i = 0; i < TILE; i++) {
                        for (int k = 0; k < TILE; k++) {
                            int global_i = ii + i;
                            int global_k = kk + k;

                            if (global_i < dim && global_k < dim) {
                                A_buf[i * TILE + k] = A_set[r][global_i * dim + global_k];
                            } else {
                                A_buf[i * TILE + k] = 0;
                            }
                        }
                    }

                    total_hw_cycles += rocc_load_a_compute_store_cycles(0, 0);

                    for (int i = 0; i < TILE; i++) {
                        for (int j = 0; j < TILE; j++) {
                            int global_i = ii + i;
                            int global_j = jj + j;

                            if (global_i < dim && global_j < dim) {
                                C_hw_set[r][global_i * dim + global_j] += C_hw_tile[i * TILE + j];
                            }
                        }
                    }
                }
            }
        }
    }

    return total_hw_cycles;
}

static void run_type_1a_size_sweep(void)
{
    uint64_t total_sw_cycles = 0;
    uint64_t total_hw_cycles = 0;
    int pass_count = 0;

    printf("\n===== TYPE 1A: MATRIX SIZE SWEEP 1x1 TO 32x32, NO B REUSE =====\n");

    for (int dim = 1; dim <= MAX_DIM; dim++) {
        uint64_t sw_start;
        uint64_t sw_end;
        uint64_t sw_cycles;
        uint64_t hw_cycles;
        int pass;

        clear_big_buffers();
        fill_big_inputs(dim, dim + 100);

        sw_start = read_cycle();
        matmul_sw_big(dim);
        sw_end = read_cycle();

        sw_cycles = sw_end - sw_start;
        hw_cycles = matmul_hw_big_tiled(dim);

        total_sw_cycles += sw_cycles;
        total_hw_cycles += hw_cycles;

        pass = compare_big_results(dim);

        if (pass)
            pass_count++;

        printf("%2dx%2d no B reuse: SW=%lu, HW=%lu, Speedup=",
               dim,
               dim,
               (unsigned long)sw_cycles,
               (unsigned long)hw_cycles);

        print_speedup(sw_cycles, hw_cycles);

        printf(", %s\n", pass ? "PASS" : "FAIL");
    }

    printf("\nTYPE 1A SUMMARY:\n");
    printf("B reuse count:          1 / no explicit reuse\n");
    printf("Total software cycles:  %lu\n", (unsigned long)total_sw_cycles);
    printf("Total hardware cycles:  %lu\n", (unsigned long)total_hw_cycles);
    printf("Overall speedup ratio:  ");
    print_speedup(total_sw_cycles, total_hw_cycles);
    printf("\n");
    printf("Correctness passed:     %d / %d\n", pass_count, MAX_DIM);
}

static void run_type_1_reuse_size_sweep(const char *type_name, int reuse_count, int seed_offset)
{
    uint64_t total_sw_cycles = 0;
    uint64_t total_hw_cycles = 0;
    int pass_count = 0;

    printf("\n===== %s: MATRIX SIZE SWEEP 1x1 TO 32x32, B REUSED %d TIMES =====\n",
           type_name,
           reuse_count);

    for (int dim = 1; dim <= MAX_DIM; dim++) {
        uint64_t sw_start;
        uint64_t sw_end;
        uint64_t sw_cycles;
        uint64_t hw_cycles;
        int pass;

        clear_reuse_buffers(reuse_count);
        fill_reuse_inputs(dim, dim + seed_offset, reuse_count);

        sw_start = read_cycle();
        matmul_sw_all_reuse(dim, reuse_count);
        sw_end = read_cycle();

        sw_cycles = sw_end - sw_start;
        hw_cycles = matmul_hw_big_tiled_reuse_b(dim, reuse_count);

        total_sw_cycles += sw_cycles;
        total_hw_cycles += hw_cycles;

        pass = compare_all_reuse_results(dim, reuse_count);

        if (pass)
            pass_count++;

        printf("%2dx%2d reused B x%d: SW=%lu, HW=%lu, Speedup=",
               dim,
               dim,
               reuse_count,
               (unsigned long)sw_cycles,
               (unsigned long)hw_cycles);

        print_speedup(sw_cycles, hw_cycles);

        printf(", %s\n", pass ? "PASS" : "FAIL");
    }

    printf("\n%s SUMMARY:\n", type_name);
    printf("B reuse count:          %d\n", reuse_count);
    printf("Total software cycles:  %lu\n", (unsigned long)total_sw_cycles);
    printf("Total hardware cycles:  %lu\n", (unsigned long)total_hw_cycles);
    printf("Overall speedup ratio:  ");
    print_speedup(total_sw_cycles, total_hw_cycles);
    printf("\n");
    printf("Correctness passed:     %d / %d\n", pass_count, MAX_DIM);
}

static void run_cnn_style_tests(void)
{
    uint64_t total_sw_cycles = 0;
    uint64_t total_hw_cycles = 0;
    int pass_count = 0;

    printf("\n===== TYPE 2: 8x8 CNN-STYLE / EXTERNAL-WEIGHT TESTS =====\n");

    for (int t = 0; t < NUM_CNN_TESTS; t++) {
        int relu  = cnn_tests[t].relu;
        int shift = cnn_tests[t].shift;

        uint64_t sw_start;
        uint64_t sw_end;
        uint64_t sw_cycles;
        uint64_t hw_cycles;
        int pass;

        clear_tile_buffers();

        fill_matrix_pattern(A_buf, cnn_tests[t].a_pattern, cnn_tests[t].seed);
        fill_matrix_pattern(B_buf, cnn_tests[t].b_pattern, cnn_tests[t].seed + 31);

        sw_start = read_cycle();
        matmul_sw_tile(relu, shift);
        sw_end = read_cycle();

        sw_cycles = sw_end - sw_start;
        hw_cycles = matmul_hw_tile_cycles(relu, shift);

        total_sw_cycles += sw_cycles;
        total_hw_cycles += hw_cycles;

        pass = compare_tile_results();

        if (pass)
            pass_count++;

        printf("\n----- TYPE 2 TEST %d: %s -----\n", t, cnn_tests[t].name);
        printf("Activation: ReLU=%d, Shift=%d\n", relu, shift);

        print_i8_matrix("Input A matrix:", A_buf);
        print_i8_matrix("Input B matrix:", B_buf);
        print_i32_matrix("Software output C_sw:", C_sw_tile);
        print_i32_matrix("Hardware output C_hw:", C_hw_tile);

        printf("Software cycles: %lu\n", (unsigned long)sw_cycles);
        printf("Hardware cycles: %lu\n", (unsigned long)hw_cycles);
        printf("Speedup ratio:   ");
        print_speedup(sw_cycles, hw_cycles);
        printf("\n");
        printf("Correctness:     %s\n", pass ? "PASS" : "FAIL");
    }

    printf("\nTYPE 2 SUMMARY:\n");
    printf("Total software cycles: %lu\n", (unsigned long)total_sw_cycles);
    printf("Total hardware cycles: %lu\n", (unsigned long)total_hw_cycles);
    printf("Overall speedup ratio: ");
    print_speedup(total_sw_cycles, total_hw_cycles);
    printf("\n");
    printf("Correctness passed:    %d / %d\n", pass_count, NUM_CNN_TESTS);
}

int main(void)
{
    printf("\n===== OS8 RoCC COMBINED PERFORMANCE TEST =====\n");

    run_type_1a_size_sweep();

    run_type_1_reuse_size_sweep("TYPE 1B", 5, 300);

    run_type_1_reuse_size_sweep("TYPE 1C", 10, 400);

    run_cnn_style_tests();

    printf("\n===== TEST COMPLETE =====\n");

    return 0;
}
