#include <iostream>
#include <fstream>
#include <vector>
#include <string>
#include <cstdint>
#include <cctype>
#include <algorithm>
#include <unistd.h>


using namespace std;

using Bits = vector<uint8_t>;

static Bits hex_to_bits(string hex, int width)
{
    if (hex.compare(0, 2, "0x") == 0 || hex.compare(0,2,"0X") == 0)
        hex = hex.substr(2);
    Bits bits(width, 0);
    int hex_len = hex.size();
    for (int i=0;i<width;i++)
    {
        int pos = hex_len - 1 - i/4;
        if (pos >= 0)
        {
            char c = hex[pos];
            int v=0;
            if (c >= '0' && c <= '9') v = c-'0';
            else if (c >= 'a' && c <= 'f') v = c-'a'+10;
            else if (c >= 'A' && c <= 'F') v = c-'A'+10;
            bits[i] = (v >> (i%4)) & 1;
        }
    }
    return bits;
}

static string bits_to_hex(const Bits& bits)
{
    int width = bits.size();
    int nibbles = (width+3)/4;
    vector<uint8_t> buf(nibbles, 0);
    for (int i=0; i<width; i++)
    {
        int idx = nibbles-1 - i/4;
        buf[idx] |= bits[i] << (i%4);
    }
    string out(nibbles, '0');
    for (int i=0; i<nibbles; i++)
        out[i] = "0123456789abcdef"[buf[i] & 0xF];
    return out;
}

static Bits reverse_vec(const Bits& v)
{
    Bits r(v.rbegin(), v.rend());
    return r;
}

static void xor_inplace(Bits& a, const Bits& b)
{
    for (size_t i=0;i<a.size();i++) a[i] ^= b[i];
}

struct Mask { Bits state; Bits data; };

static Mask lfsr_mask(int index, int LFSR_WIDTH, unsigned long long LFSR_POLY,
                      const string& LFSR_CONFIG, bool LFSR_FEED_FORWARD,
                      bool REVERSE, int DATA_WIDTH)
{
    vector<Bits> lfsr_mask_state(LFSR_WIDTH, Bits(LFSR_WIDTH,0));
    vector<Bits> lfsr_mask_data(LFSR_WIDTH, Bits(DATA_WIDTH,0));
    vector<Bits> output_mask_state(DATA_WIDTH, Bits(LFSR_WIDTH,0));
    vector<Bits> output_mask_data(DATA_WIDTH, Bits(DATA_WIDTH,0));

    for (int i=0;i<LFSR_WIDTH;i++)
        lfsr_mask_state[i][i]=1;
    for (int i=0;i<DATA_WIDTH;i++)
        if (i < LFSR_WIDTH) output_mask_state[i][i]=1;

    for (int m=DATA_WIDTH-1;m>=0;m--)
    {
        Bits data_mask(DATA_WIDTH,0);
        data_mask[m]=1;

        Bits state_val = lfsr_mask_state[LFSR_WIDTH-1];
        Bits data_val = lfsr_mask_data[LFSR_WIDTH-1];
        xor_inplace(data_val, data_mask);

        if (LFSR_CONFIG == "FIBONACCI") {
            for (int j=1;j<LFSR_WIDTH;j++)
                if ((LFSR_POLY >> j) & 1) {
                    xor_inplace(state_val, lfsr_mask_state[j-1]);
                    xor_inplace(data_val, lfsr_mask_data[j-1]);
                }
            for (int j=LFSR_WIDTH-1;j>=1;j--) {
                lfsr_mask_state[j] = lfsr_mask_state[j-1];
                lfsr_mask_data[j]  = lfsr_mask_data[j-1];
            }
            for (int j=DATA_WIDTH-1;j>=1;j--) {
                output_mask_state[j] = output_mask_state[j-1];
                output_mask_data[j]  = output_mask_data[j-1];
            }
            output_mask_state[0] = state_val;
            output_mask_data[0]  = data_val;
            if (LFSR_FEED_FORWARD) {
                state_val.assign(LFSR_WIDTH,0);
                data_val.assign(DATA_WIDTH,0);
                data_val[m]=1;
            }
            lfsr_mask_state[0] = state_val;
            lfsr_mask_data[0]  = data_val;
        } else {
            for (int j=LFSR_WIDTH-1;j>=1;j--) {
                lfsr_mask_state[j] = lfsr_mask_state[j-1];
                lfsr_mask_data[j]  = lfsr_mask_data[j-1];
            }
            for (int j=DATA_WIDTH-1;j>=1;j--) {
                output_mask_state[j] = output_mask_state[j-1];
                output_mask_data[j]  = output_mask_data[j-1];
            }
            output_mask_state[0] = state_val;
            output_mask_data[0]  = data_val;
            if (LFSR_FEED_FORWARD) {
                state_val.assign(LFSR_WIDTH,0);
                data_val.assign(DATA_WIDTH,0);
                data_val[m]=1;
            }
            lfsr_mask_state[0] = state_val;
            lfsr_mask_data[0]  = data_val;
            for (int j=1;j<LFSR_WIDTH;j++)
                if ((LFSR_POLY >> j) & 1) {
                    xor_inplace(lfsr_mask_state[j], state_val);
                    xor_inplace(lfsr_mask_data[j], data_val);
                }
        }
    }

    Bits state_val, data_val;
    if (REVERSE) {
        if (index < LFSR_WIDTH) {
            state_val = reverse_vec(lfsr_mask_state[LFSR_WIDTH-index-1]);
            data_val  = reverse_vec(lfsr_mask_data[LFSR_WIDTH-index-1]);
        } else {
            int k = index - LFSR_WIDTH;
            state_val = reverse_vec(output_mask_state[DATA_WIDTH-k-1]);
            data_val  = reverse_vec(output_mask_data[DATA_WIDTH-k-1]);
        }
    } else {
        if (index < LFSR_WIDTH) {
            state_val = lfsr_mask_state[index];
            data_val  = lfsr_mask_data[index];
        } else {
            int k = index - LFSR_WIDTH;
            state_val = output_mask_state[k];
            data_val  = output_mask_data[k];
        }
    }

    return {state_val, data_val};
}

static uint8_t parity(const Bits& a, const Bits& b, const Bits& state_in, const Bits& data_in)
{
    int p=0;
    for (size_t i=0;i<a.size();i++) if (a[i] && state_in[i]) p^=1;
    for (size_t i=0;i<b.size();i++) if (b[i] && data_in[i]) p^=1;
    return p;
}

static vector<uint8_t> bits_to_bytes_be(const Bits& bits)
{
    int n = (bits.size()+7)/8;
    vector<uint8_t> bytes(n,0);
    for (size_t i=0;i<bits.size();i++) {
        if (bits[i]) {
            size_t idx = bytes.size()-1 - i/8;
            bytes[idx] |= uint8_t(1) << (i%8);
        }
    }
    return bytes;
}

int main(int argc, char* argv[])
{
    int LFSR_WIDTH = 31;
    unsigned long long LFSR_POLY = 0x10000001ull;
    string LFSR_CONFIG = "FIBONACCI";
    bool LFSR_FEED_FORWARD = false;
    bool REVERSE = false;
    int DATA_WIDTH = 64;
    string data_in_hex = "0";
    string state_in_hex = "0x7fffffff";
    string outfile = "out.bin";
    int num_words = 100;

    int opt;
    while ((opt = getopt(argc, argv, "w:p:c:f:r:d:i:s:o:n:")) != -1) {
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
            case 'n': num_words = stoi(optarg); break;
            default:
                cerr << "Usage: " << argv[0]
                     << " [-w LFSR_WIDTH] [-p LFSR_POLY] [-c LFSR_CONFIG]"
                     << " [-f FEED_FORWARD] [-r REVERSE] [-d DATA_WIDTH]"
                     << " [-i DATA_IN] [-s STATE_IN] [-o OUTFILE] [-n NUM]" << endl;
                return 1;
        }
    }

    Bits state = hex_to_bits(state_in_hex, LFSR_WIDTH);
    Bits data_in = hex_to_bits(data_in_hex, DATA_WIDTH);

    ofstream f(outfile, ios::binary);
    if (!f.is_open()) {
        cerr << "Failed to open output file" << endl;
        return 1;
    }

    for (int w = 0; w < num_words; w++) {
        Bits state_out(LFSR_WIDTH);
        Bits data_out(DATA_WIDTH);
        for (int n=0;n<LFSR_WIDTH;n++) {
            Mask m = lfsr_mask(n, LFSR_WIDTH, LFSR_POLY, LFSR_CONFIG, LFSR_FEED_FORWARD, REVERSE, DATA_WIDTH);
            state_out[n] = parity(m.state, m.data, state, data_in);
        }
        for (int n=0;n<DATA_WIDTH;n++) {
            Mask m = lfsr_mask(n+LFSR_WIDTH, LFSR_WIDTH, LFSR_POLY, LFSR_CONFIG, LFSR_FEED_FORWARD, REVERSE, DATA_WIDTH);
            data_out[n] = parity(m.state, m.data, state, data_in);
        }

        vector<uint8_t> bytes = bits_to_bytes_be(data_out);
        f.write((char*)bytes.data(), bytes.size());

        state = state_out;
    }

    f.close();

    cout << "final_state=0x" << bits_to_hex(state) << endl;
    cout << "wrote " << num_words << " words to " << outfile << endl;


    return 0;
}

