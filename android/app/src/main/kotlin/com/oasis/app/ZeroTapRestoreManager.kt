package com.oasis.app

import android.content.Context
import android.util.Log
import androidx.credentials.ClearCredentialStateRequest
import androidx.credentials.CreateRestoreCredentialRequest
import androidx.credentials.CredentialManager
import androidx.credentials.GetCredentialRequest
import androidx.credentials.GetRestoreCredentialOption
import androidx.credentials.RestoreCredential
import androidx.credentials.exceptions.ClearCredentialException
import androidx.credentials.exceptions.CreateCredentialCancellationException
import androidx.credentials.exceptions.CreateCredentialException
import androidx.credentials.exceptions.GetCredentialCancellationException
import androidx.credentials.exceptions.GetCredentialException
import androidx.credentials.exceptions.NoCredentialException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class ZeroTapRestoreManager(private val context: Context) {
    companion object {
        private const val TAG = "ZeroTapRestoreManager"
        const val CHANNEL_NAME = "com.yourapp.zerotap/restore"
    }

    private val credentialManager by lazy { CredentialManager.create(context) }
    private val scope = CoroutineScope(Dispatchers.Main)

    fun getRestoreKey(onResult: (String?, String?) -> Unit) {
        scope.launch {
            try {
                val getRestoreOption = GetRestoreCredentialOption()
                val getCredRequest = GetCredentialRequest.Builder()
                    .addCredentialOption(getRestoreOption)
                    .build()

                val response = withContext(Dispatchers.IO) {
                    credentialManager.getCredential(context, getCredRequest)
                }

                val credential = response.credential
                if (credential is RestoreCredential) {
                    Log.d(TAG, "Successfully retrieved restore credential key")
                    onResult(credential.restoreToken, null)
                } else {
                    val rawToken = credential.data.getString("androidx.credentials.BUNDLE_KEY_RESTORE_TOKEN")
                    if (!rawToken.isNullOrEmpty()) {
                        Log.d(TAG, "Retrieved restore token from bundle data")
                        onResult(rawToken, null)
                    } else {
                        Log.d(TAG, "Non-restore credential received: ${credential.type}")
                        onResult(null, null)
                    }
                }
            } catch (e: NoCredentialException) {
                Log.d(TAG, "No restore credential available on this device: ${e.message}")
                onResult(null, null)
            } catch (e: GetCredentialCancellationException) {
                Log.d(TAG, "GetCredential cancelled by user or system: ${e.message}")
                onResult(null, null)
            } catch (e: GetCredentialException) {
                Log.w(TAG, "GetCredentialException while fetching restore key: ${e.message}")
                onResult(null, null)
            } catch (t: Throwable) {
                Log.e(TAG, "Unexpected error retrieving restore key", t)
                onResult(null, t.message)
            }
        }
    }

    fun saveRestoreKey(token: String, onResult: (Boolean, String?) -> Unit) {
        scope.launch {
            try {
                val createRequest = CreateRestoreCredentialRequest(restoreToken = token)
                withContext(Dispatchers.IO) {
                    credentialManager.createCredential(context, createRequest)
                }
                Log.d(TAG, "Successfully saved restore key to CredentialManager")
                onResult(true, null)
            } catch (e: CreateCredentialCancellationException) {
                Log.d(TAG, "CreateCredential cancelled: ${e.message}")
                onResult(false, null)
            } catch (e: CreateCredentialException) {
                Log.w(TAG, "CreateCredentialException while saving restore key: ${e.message}")
                onResult(false, e.message)
            } catch (t: Throwable) {
                Log.e(TAG, "Unexpected error saving restore key", t)
                onResult(false, t.message)
            }
        }
    }

    fun clearRestoreKey(onResult: (Boolean) -> Unit) {
        scope.launch {
            try {
                withContext(Dispatchers.IO) {
                    credentialManager.clearCredentialState(ClearCredentialStateRequest())
                }
                Log.d(TAG, "Successfully cleared credential state")
                onResult(true)
            } catch (e: ClearCredentialException) {
                Log.w(TAG, "Failed to clear credential state: ${e.message}")
                onResult(false)
            } catch (t: Throwable) {
                Log.e(TAG, "Unexpected error clearing credential state", t)
                onResult(false)
            }
        }
    }
}
