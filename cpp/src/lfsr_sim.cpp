#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cstdint>
#include <cctype>
#include <algorithm>
#include <unistd.h>
#include <stdexcept>
#include <chrono>
#include <omp.h>
#include <cmath> // Add this header for log2 and floor

using namespace std;

#pragma region "Core Data Structures: BitVec, Matrix, Transform"

// An efficient bit vector struct using uint64_t to store bits.
struct BitVec {
    vector<uint64_t> words;
    int num_bits;

    BitVec() : num_bits(0) {}
    explicit BitVec(int size) : num_bits(size), words((size + 63) / 64, 0) {}

    uint8_t get(int index) const {
        if (index < 0 || index >= num_bits) return 0;
        return (words[index / 64] >> (index % 64)) & 1;
    }

    void set(int index) {
        if (index < 0 || index >= num_bits) return;
        words[index / 64] |= uint64_t(1) << (index % 64);
    }

    void xor_inplace(const BitVec& other) {
        if (this->words.size() != other.words.size()) return; // Safety check
        for (size_t i = 0; i < words.size(); ++i) {
            words[i] ^= other.words[i];
        }
    }
};

// Represents a square matrix of bits for transformations.
struct Matrix {
    vector<BitVec> rows;
    int dimension;

    Matrix() : dimension(0) {}
    explicit Matrix(int dim) : dimension(dim), rows(dim, BitVec(dim)) {}

    static Matrix identity(int dim) {
        Matrix I(dim);
        for (int i = 0; i < dim; ++i) {
            I.rows[i].set(i);
        }
        return I;
    }
};

// Represents a full linear transform: V_new = T * V_old + C
struct Transform {
    Matrix T;
    BitVec C;

    Transform() {}
    explicit Transform(int dim) : T(dim), C(dim) {}

    static Transform identity(int dim) {
        Transform I;
        I.T = Matrix::identity(dim);
        I.C = BitVec(dim);
        return I;
    }
};

#pragma endregion

#pragma region "Parallel Math Operations"

// Parallel Matrix-Vector Multiplication (res = M * V)
BitVec multiply(const Matrix& M, const BitVec& V) {
    BitVec result(M.dimension);
    #pragma omp parallel for
    for (int i = 0; i < M.dimension; ++i) {
        uint64_t sum = 0;
        for (size_t w = 0; w < M.rows[i].words.size(); ++w) {
            sum ^= __builtin_popcountll(M.rows[i].words[w] & V.words[w]);
        }
        if ((sum & 1) != 0) {
            result.set(i);
        }
    }
    return result;
}

// Parallel Matrix-Matrix Multiplication (res = A * B)
Matrix multiply(const Matrix& A, const Matrix& B) {
    Matrix result(A.dimension);
    Matrix B_T(B.dimension); // Transpose of B for cache-friendly access
    #pragma omp parallel for
    for (int i = 0; i < B.dimension; ++i) {
        for (int j = 0; j < B.dimension; ++j) {
            if (B.rows[j].get(i)) {
                B_T.rows[i].set(j);
            }
        }
    }

    #pragma omp parallel for
    for (int i = 0; i < A.dimension; ++i) {
        for (int j = 0; j < A.dimension; ++j) {
            uint64_t sum = 0;
            // Ensure word vectors are the same size before accessing
            size_t num_words = min(A.rows[i].words.size(), B_T.rows[j].words.size());
            for (size_t w = 0; w < num_words; ++w) {
                sum ^= __builtin_popcountll(A.rows[i].words[w] & B_T.rows[j].words[w]);
            }
            if ((sum & 1) != 0) {
                result.rows[i].set(j);
            }
        }
    }
    return result;
}

// Compose two transforms: F_new = F2 * F1
Transform compose(const Transform& F2, const Transform& F1) {
    Transform result(F1.T.dimension);
    result.T = multiply(F2.T, F1.T);
    BitVec F2_C = multiply(F2.T, F1.C);
    F2_C.xor_inplace(F2.C);
    result.C = F2_C;
    return result;
}

// Exponentiation by squaring for transforms: F^n
Transform power(Transform F, long long n) {
    Transform result = Transform::identity(F.T.dimension);
    while (n > 0) {
        if (n % 2 == 1) result = compose(F, result);
        F = compose(F, F);
        n /= 2;
    }
    return result;
}

#pragma endregion

#pragma region "LFSR Logic and I/O Helper Implementations"

// Convert a hexadecimal string to a BitVec.
static BitVec hex_to_bitvec(string hex, int width) {
    if (hex.compare(0, 2, "0x") == 0 || hex.compare(0, 2, "0X") == 0)
        hex = hex.substr(2);
    
    BitVec bits(width);
    int hex_len = hex.size();
    for (int i = 0; i < width; i++) {
        int pos = hex_len - 1 - i / 4;
        if (pos >= 0) {
            char c = hex[pos];
            int v = 0;
            if (c >= '0' && c <= '9') v = c - '0';
            else if (c >= 'a' && c <= 'f') v = c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v = c - 'A' + 10;
            if ((v >> (i % 4)) & 1) {
                bits.set(i);
            }
        }
    }
    return bits;
}

// Convert a BitVec to a hexadecimal string.
static string bitvec_to_hex(const BitVec& bits) {
    int nibbles = (bits.num_bits + 3) / 4;
    string out(nibbles, '0');
    const char* hex_chars = "0123456789abcdef";

    for (int i = 0; i < nibbles; ++i) {
        int val = 0;
        for (int j = 0; j < 4; ++j) {
            int bit_idx = i * 4 + j;
            if (bit_idx < bits.num_bits && bits.get(bit_idx)) {
                val |= (1 << j);
            }
        }
        out[nibbles - 1 - i] = hex_chars[val];
    }
    return out;
}

// Reverse the bits in a BitVec.
static BitVec reverse_bitvec(const BitVec& v) {
    BitVec r(v.num_bits);
    for (int i = 0; i < v.num_bits; ++i) {
        if (v.get(i)) {
            r.set(v.num_bits - 1 - i);
        }
    }
    return r;
}

// Generate a mask for one output bit (one row of the transform matrix).
static BitVec lfsr_mask_row(int index, int LFSR_WIDTH, unsigned long long LFSR_POLY,
                             const string& LFSR_CONFIG, bool LFSR_FEED_FORWARD,
                             bool REVERSE, int DATA_WIDTH)
{
    vector<BitVec> lfsr_mask_state(LFSR_WIDTH, BitVec(LFSR_WIDTH));
    vector<BitVec> lfsr_mask_data(LFSR_WIDTH, BitVec(DATA_WIDTH));
    vector<BitVec> output_mask_state(DATA_WIDTH, BitVec(LFSR_WIDTH));
    vector<BitVec> output_mask_data(DATA_WIDTH, BitVec(DATA_WIDTH));

    for (int i = 0; i < LFSR_WIDTH; i++) lfsr_mask_state[i].set(i);
    for (int i = 0; i < DATA_WIDTH; i++) if (i < LFSR_WIDTH) output_mask_state[i].set(i);

    for (int m = DATA_WIDTH - 1; m >= 0; m--) {
        BitVec data_mask(DATA_WIDTH);
        data_mask.set(m);

        BitVec state_val = lfsr_mask_state[LFSR_WIDTH - 1];
        BitVec data_val = lfsr_mask_data[LFSR_WIDTH - 1];
        data_val.xor_inplace(data_mask);

        if (LFSR_CONFIG == "FIBONACCI") {
            for (int j = 1; j < LFSR_WIDTH; j++)
                if ((LFSR_POLY >> j) & 1) {
                    state_val.xor_inplace(lfsr_mask_state[j - 1]);
                    data_val.xor_inplace(lfsr_mask_data[j - 1]);
                }
            for (int j = LFSR_WIDTH - 1; j >= 1; j--) {
                lfsr_mask_state[j] = lfsr_mask_state[j - 1];
                lfsr_mask_data[j] = lfsr_mask_data[j - 1];
            }
            for (int j = DATA_WIDTH - 1; j >= 1; j--) {
                output_mask_state[j] = output_mask_state[j - 1];
                output_mask_data[j] = output_mask_data[j - 1];
            }
            output_mask_state[0] = state_val;
            output_mask_data[0] = data_val;
            if (LFSR_FEED_FORWARD) {
                state_val = BitVec(LFSR_WIDTH);
                data_val = BitVec(DATA_WIDTH);
                data_val.set(m);
            }
            lfsr_mask_state[0] = state_val;
            lfsr_mask_data[0] = data_val;
        } else { // GALOIS
            for (int j = LFSR_WIDTH - 1; j >= 1; j--) {
                lfsr_mask_state[j] = lfsr_mask_state[j - 1];
                lfsr_mask_data[j] = lfsr_mask_data[j - 1];
            }
            for (int j = DATA_WIDTH - 1; j >= 1; j--) {
                output_mask_state[j] = output_mask_state[j - 1];
                output_mask_data[j] = output_mask_data[j - 1];
            }
            output_mask_state[0] = state_val;
            output_mask_data[0] = data_val;
            if (LFSR_FEED_FORWARD) {
                state_val = BitVec(LFSR_WIDTH);
                data_val = BitVec(DATA_WIDTH);
                data_val.set(m);
            }
            lfsr_mask_state[0] = state_val;
            lfsr_mask_data[0] = data_val;
            for (int j = 1; j < LFSR_WIDTH; j++)
                if ((LFSR_POLY >> j) & 1) {
                    lfsr_mask_state[j].xor_inplace(state_val);
                    lfsr_mask_data[j].xor_inplace(data_val);
                }
        }
    }

    BitVec final_state_val, final_data_val;
    if (index < LFSR_WIDTH) {
        int i = REVERSE ? LFSR_WIDTH - index - 1 : index;
        final_state_val = lfsr_mask_state[i];
        final_data_val = lfsr_mask_data[i];
    } else {
        int k = index - LFSR_WIDTH;
        int i = REVERSE ? DATA_WIDTH - k - 1 : k;
        final_state_val = output_mask_state[i];
        final_data_val = output_mask_data[i];
    }
    
    if (REVERSE) {
        final_state_val = reverse_bitvec(final_state_val);
        final_data_val = reverse_bitvec(final_data_val);
    }
    
    BitVec full_row(LFSR_WIDTH + DATA_WIDTH);
    for(int i=0; i < LFSR_WIDTH; ++i) if(final_state_val.get(i)) full_row.set(i);
    for(int i=0; i < DATA_WIDTH; ++i) if(final_data_val.get(i)) full_row.set(LFSR_WIDTH + i);
    
    return full_row;
}

// Convert a BitVec to a big-endian vector of bytes.
static vector<uint8_t> bitvec_to_bytes_be(const BitVec& bits, int start_bit, int num_bits_to_convert)
{
    int n_bytes = (num_bits_to_convert + 7) / 8;
    vector<uint8_t> bytes(n_bytes, 0);
    for (int i = 0; i < num_bits_to_convert; i++) {
        if (bits.get(start_bit + i)) {
            size_t byte_idx = n_bytes - 1 - i / 8;
            bytes[byte_idx] |= uint8_t(1) << (i % 8);
        }
    }
    return bytes;
}

#pragma endregion

// The simulation function for a single chunk.
void simulate_chunk(
    long long num_words_in_chunk,
    const BitVec& start_state,
    const Transform& single_step_transform,
    const int LFSR_WIDTH,
    const int DATA_WIDTH,
    vector<uint8_t>& output_buffer) 
{
    BitVec current_state = start_state;
    output_buffer.reserve(num_words_in_chunk * (DATA_WIDTH / 8));

    for (long long w = 0; w < num_words_in_chunk; ++w) {
        BitVec output_total = multiply(single_step_transform.T, current_state);
        output_total.xor_inplace(single_step_transform.C);

        vector<uint8_t> bytes = bitvec_to_bytes_be(output_total, LFSR_WIDTH, DATA_WIDTH);
        output_buffer.insert(output_buffer.end(), bytes.begin(), bytes.end());

        current_state.words = output_total.words;
        int last_word_idx = (LFSR_WIDTH - 1) / 64;
        if (last_word_idx < current_state.words.size()) {
             int bits_in_last_word = LFSR_WIDTH % 64;
             if (bits_in_last_word > 0) {
                uint64_t mask = (uint64_t(1) << bits_in_last_word) - 1;
                current_state.words[last_word_idx] &= mask;
            }
             for(size_t i = last_word_idx + 1; i < current_state.words.size(); ++i) {
               current_state.words[i] = 0;
            }
        }
    }
}


int main(int argc, char* argv[]) {
    #pragma region "Argument Parsing"
    int LFSR_WIDTH = 31;
    unsigned long long LFSR_POLY = 0x10000001ull;
    string LFSR_CONFIG = "GALOIS";
    bool LFSR_FEED_FORWARD = false;
    bool REVERSE = false;
    int DATA_WIDTH = 512;
    string data_in_hex = "0";
    string state_in_hex = "0x7fffffff";
    string outfile = "out.bin";
    long long num_words = 100000000;
    int num_cores = 20;

    int opt;
    while ((opt = getopt(argc, argv, "w:p:c:f:r:d:i:s:o:n:t:")) != -1) {
        switch (opt) {
            case 'w': LFSR_WIDTH = stoi(optarg); break;
            case 'p': LFSR_POLY = stoull(optarg, nullptr, 0); break;
            case 'c': LFSR_CONFIG = optarg; break;
            case 'f': LFSR_FEED_FORWARD = stoi(optarg) != 0; break;
            case 'r': REVERSE = stoi(optarg) != 0; break;
            case 'd': DATA_WIDTH = stoi(optarg); break;
            case 'i': data_in_hex = optarg; break;
            case 's': state_in_hex = optarg; break;
            case 'o': outfile = optarg; break;
            case 'n': num_words = stoll(optarg); break;
            case 't': num_cores = stoi(optarg); break;
            default:
                 cerr << "Usage: " << argv[0]
                     << " [-t num_cores] ..." << endl;
                return 1;
        }
    }
    #pragma endregion

    const int total_width = LFSR_WIDTH + DATA_WIDTH;
    omp_set_num_threads(num_cores);

    cout << "Using " << num_cores << " cores for parallel computation." << endl;
    auto precompute_start = chrono::high_resolution_clock::now();
    
    cout << "Step 1: Computing single-step transform matrix..." << endl;
    Transform F_1(total_width);
    BitVec data_in = hex_to_bitvec(data_in_hex, DATA_WIDTH);
    #pragma omp parallel for
    for (int i = 0; i < total_width; ++i) {
        BitVec row = lfsr_mask_row(i, LFSR_WIDTH, LFSR_POLY, LFSR_CONFIG, LFSR_FEED_FORWARD, REVERSE, DATA_WIDTH);
        F_1.T.rows[i] = row;
    }
    BitVec full_input_vec(total_width);
    for(int i=0; i<DATA_WIDTH; ++i) if(data_in.get(i)) full_input_vec.set(LFSR_WIDTH + i);
    F_1.C = multiply(F_1.T, full_input_vec);

    if (num_words < num_cores) num_cores = num_words > 0 ? num_words : 1;
    long long chunk_size = (num_words + num_cores - 1) / num_cores;
    cout << "Step 2: Computing " << chunk_size << "-step transform matrix (T^" << chunk_size << ")..." << endl;
    Transform F_chunk = power(F_1, chunk_size);

    cout << "Step 3: Calculating start-points for " << num_cores << " chunks..." << endl;
    vector<Transform> start_transforms(num_cores);
    if (num_cores > 0) {
        start_transforms[0] = Transform::identity(total_width);
    }
    for(int i = 1; i < num_cores; ++i) {
        start_transforms[i] = compose(F_chunk, start_transforms[i-1]);
    }
    
    cout << "Step 4: Applying transforms to get start states..." << endl;
    vector<BitVec> start_states(num_cores, BitVec(total_width));
    BitVec initial_state_full = hex_to_bitvec(state_in_hex, LFSR_WIDTH);
    initial_state_full.words.resize((total_width + 63) / 64, 0);

    #pragma omp parallel for
    for (int i = 0; i < num_cores; ++i) {
        start_states[i] = multiply(start_transforms[i].T, initial_state_full);
        start_states[i].xor_inplace(start_transforms[i].C);
    }
    
    auto precompute_end = chrono::high_resolution_clock::now();
    chrono::duration<double> precompute_elapsed = precompute_end - precompute_start;
    cout << "Full pre-computation finished in " << precompute_elapsed.count() << " seconds." << endl;

    cout << "Step 5: Running simulation on " << num_cores << " cores..." << endl;
    auto sim_start = chrono::high_resolution_clock::now();
    vector<vector<uint8_t>> output_buffers(num_cores);

    #pragma omp parallel for
    for(int i = 0; i < num_cores; ++i) {
        long long current_chunk_start = (long long)i * chunk_size;
        long long words_in_this_chunk = min((long long)chunk_size, num_words - current_chunk_start);
        if (words_in_this_chunk > 0) {
            simulate_chunk(words_in_this_chunk, start_states[i], F_1, LFSR_WIDTH, DATA_WIDTH, output_buffers[i]);
        }
    }
    
    auto sim_end = chrono::high_resolution_clock::now();
    chrono::duration<double> sim_elapsed = sim_end - sim_start;
    cout << "Parallel simulation finished in " << sim_elapsed.count() << " seconds." << endl;

    cout << "Step 6: Writing results to " << outfile << "..." << endl;
    ofstream f(outfile, ios::binary);
    if (!f.is_open()) {
        cerr << "Failed to open output file: " << outfile << endl;
        return 1;
    }
    for (int i = 0; i < num_cores; ++i) {
        if(!output_buffers[i].empty())
            f.write((char*)output_buffers[i].data(), output_buffers[i].size());
    }
    f.close();
    
    BitVec final_state_vec(total_width);
    if (num_words > 0) {
        final_state_vec = start_states[num_cores - 1];
        long long last_chunk_size = num_words - (long long)(num_cores - 1) * chunk_size;
        if (last_chunk_size > 0) {
            Transform F_last = power(F_1, last_chunk_size);
            final_state_vec = multiply(F_last.T, start_states[num_cores-1]);
            final_state_vec.xor_inplace(F_last.C);
        }
    } else {
        final_state_vec = initial_state_full;
    }

    BitVec final_state_lfsr_width(LFSR_WIDTH);
    if (final_state_vec.words.size() * 64 >= LFSR_WIDTH) {
        final_state_lfsr_width.words.assign(final_state_vec.words.begin(), final_state_vec.words.begin() + (LFSR_WIDTH+63)/64);
    }
    
    cout << "final_state=0x" << bitvec_to_hex(final_state_lfsr_width) << endl;
    cout << "wrote " << num_words << " words to " << outfile << endl;

    return 0;
}