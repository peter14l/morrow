package com.oasis.app

class PqAuraNative {
    companion object {
        init {
            System.loadLibrary("pq_aura")
        }

        @JvmStatic
        external fun decrypt(
            statePtr: Long,
            header: ByteArray,
            payload: ByteArray,
            ad: ByteArray
        ): ByteArray?

        @JvmStatic
        external fun initState(serializedState: ByteArray): Long

        @JvmStatic
        external fun loadAtomic(path: String, key: ByteArray): Long

        @JvmStatic
        external fun saveAtomic(statePtr: Long, path: String, key: ByteArray): Boolean

        @JvmStatic
        external fun freeState(statePtr: Long)
    }
}
