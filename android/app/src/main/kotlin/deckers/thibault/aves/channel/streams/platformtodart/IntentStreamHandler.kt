package com.weitu.gallery.channel.streams.platformtodart

import com.weitu.gallery.channel.streams.BaseStreamHandler
import com.weitu.gallery.utils.LogUtils

class IntentStreamHandler : BaseStreamHandler() {
    fun notifyNewIntent(intentData: MutableMap<String, Any?>?) = success(intentData)

    override val logTag = LOG_TAG

    companion object {
        private val LOG_TAG = LogUtils.createTag<IntentStreamHandler>()
        const val CHANNEL = "deckers.thibault/aves/new_intent_stream"
    }
}