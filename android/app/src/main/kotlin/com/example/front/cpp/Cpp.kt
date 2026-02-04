package com.example.front.cpp

object Cpp {
    init {
        System.loadLibrary("lc3")
    }

    // LC3 decoding
    @JvmStatic
    external fun decodeLC3(lc3Data: ByteArray): ByteArray

    // RNNoise (noise reduction)
    @JvmStatic
    external fun createRNNoiseState(): Long
    @JvmStatic
    external fun destroyRNNoiseState(st: Long)
    @JvmStatic
    external fun rnNoise(st: Long, input: FloatArray): FloatArray
}
