#include <metal_stdlib>

using namespace metal;



kernel void writeSomeZeros(const device float *input [[ buffer(0) ]],
                           device unsigned char *output [[ buffer(1) ]],
                           uint id [[ thread_position_in_grid ]])
{
    int numberOfChannels = 128;
    int numberOfValues = 130000;
    float sum = 0;
    for (int i = 0; i < numberOfChannels; i++) {
        int channelIndex = i * numberOfValues + id;
        sum = sum + input[id];
    }

    output[id] = static_cast<unsigned char>(sum);
}

