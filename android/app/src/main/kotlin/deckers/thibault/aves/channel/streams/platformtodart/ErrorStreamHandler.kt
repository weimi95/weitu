package com.weitu.gallery.channel.streams.platformtodart

import com.weitu.gallery.channel.streams.BaseStreamHandler
import com.weitu.gallery.utils.LogUtils

class ErrorStreamHandler : BaseStreamHandler() {
    fun notifyError(error: String) = success(error)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<ErrorStreamHandler>()
        const val CHANNEL = "deckers.thibault/aves/error"
    }
}