/**
 * Copyright (c) Ely Deckers.
 *
 * This source code is licensed under the MPL-2.0 license found in the
 * LICENSE file in the root directory of this source tree.
 */
package io.deckers.blob_courier.common

import com.facebook.react.bridge.Promise

const val ERROR_INVALID_VALUE = "ERROR_INVALID_VALUE"
const val ERROR_UNEXPECTED_EXCEPTION = "ERROR_UNEXPECTED_EXCEPTION"
const val ERROR_UNEXPECTED_ERROR = "ERROR_UNEXPECTED_ERROR"
const val ERROR_UNEXPECTED_EMPTY_VALUE = "ERROR_UNEXPECTED_EMPTY_VALUE"
const val ERROR_UNKNOWN_HOST = "ERROR_UNKNOWN_HOST"

class BlobCourierError(val code: String, message: String) : Throwable(message)

fun processUnexpectedError(promise: Promise, e: Error) = promise.reject(
  ERROR_UNEXPECTED_ERROR,
  "An unexpected error occurred: ${e.message}"
)

fun processUnexpectedException(promise: Promise, e: Exception) = promise.reject(
  ERROR_UNEXPECTED_EXCEPTION,
  "An unexpected exception occurred: ${e.message}"
)