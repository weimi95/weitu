package com.weitu.gallery.decoding

import android.content.Context
import android.graphics.Bitmap
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Log
import android.util.Size
import androidx.annotation.RequiresApi
import androidx.core.graphics.scale
import com.bumptech.glide.Glide
import com.bumptech.glide.load.DecodeFormat
import com.bumptech.glide.load.engine.DiskCacheStrategy
import com.bumptech.glide.request.RequestOptions
import com.bumptech.glide.signature.ObjectKey
import com.weitu.gallery.channel.streams.darttoplatform.ByteSink
import com.weitu.gallery.glide.AvesAppGlideModule
import com.weitu.gallery.glide.MultiPageImage
import com.weitu.gallery.utils.BitmapUtils
import com.weitu.gallery.utils.BitmapUtils.applyExifOrientation
import com.weitu.gallery.utils.ContextUtils.devicePixelRatio
import com.weitu.gallery.utils.LogUtils
import com.weitu.gallery.utils.MimeTypes
import com.weitu.gallery.utils.MimeTypes.SVG
import com.weitu.gallery.utils.MimeTypes.isVideo
import com.weitu.gallery.utils.MimeTypes.needRotationAfterContentResolverThumbnail
import com.weitu.gallery.utils.MimeTypes.needRotationAfterGlide
import com.weitu.gallery.utils.StorageUtils
import com.weitu.gallery.utils.UriUtils.tryParseId
import java.io.ByteArrayInputStream
import kotlin.math.min
import kotlin.math.roundToInt

class ThumbnailFetcher internal constructor(
    private val context: Context,
    private val uri: Uri,
    private val pageId: Int?,
    private val decoded: Boolean,
    private val mimeType: String,
    private val dateModifiedMillis: Long,
    private val rotationDegrees: Int,
    private val isFlipped: Boolean,
    widthDip: Double?,
    heightDip: Double?,
    private val result: ByteSink,
) {
    private val density = context.devicePixelRatio()
    private val defaultSize = (DEFAULT_SIZE_DIP * density).roundToInt()
    private val width: Int = if (widthDip?.takeIf { it > 0 } != null) (widthDip * density).roundToInt() else defaultSize
    private val height: Int = if (heightDip?.takeIf { it > 0 } != null) (heightDip * density).roundToInt() else defaultSize
    private val svgFetch = mimeType == SVG
    private val tiffFetch = mimeType == MimeTypes.TIFF
    private val multiPageFetch = pageId != null && MultiPageImage.isSupported(mimeType)
    private val customFetch = svgFetch || tiffFetch || multiPageFetch

    suspend fun fetch() {
        var bitmap: Bitmap? = null
        var exception: Exception? = null

        try {
            // prefer the system thumbnail (same one as the stock gallery app) whenever possible,
            // not only for the default size, to keep the app cache small.
            // we still skip it for flipped entries, and for sizes beyond what the system
            // media provider caches, as it would yield upscaled/blurry thumbnails.
            if (!customFetch && !isFlipped && width <= MAX_SYSTEM_THUMBNAIL_SIZE && height <= MAX_SYSTEM_THUMBNAIL_SIZE) {
                // Fetch low quality thumbnails when size is not specified.
                // As of Android 11, the Media Store content resolver may return a thumbnail
                // that is automatically rotated according to EXIF orientation, but not flipped,
                // so we skip this step for flipped entries.
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    bitmap = getByResolver()
                } else if (StorageUtils.isMediaStoreContentUri(uri)) {
                    bitmap = getByMediaStore()
                }
            }
        } catch (e: Exception) {
            exception = e
        }

        // fallback if the native methods failed or for higher quality thumbnails
        if (bitmap == null) {
            try {
                bitmap = getByGlide()
            } catch (e: Exception) {
                exception = e
            }
        }

        if (bitmap != null) {
            if (bitmap.width > width && bitmap.height > height) {
                // rescale when the resulting bitmap is larger than requested
                val scalingFactor: Double = min(bitmap.width.toDouble() / width, bitmap.height.toDouble() / height)
                val dstWidth = (bitmap.width / scalingFactor).roundToInt()
                val dstHeight = (bitmap.height / scalingFactor).roundToInt()
                val reduction = 1f - (dstWidth * dstHeight).toFloat() / (bitmap.width * bitmap.height)
                if (reduction > RESCALE_REDUCTION_THRESHOLD) {
                    Log.d(
                        LOG_TAG, "rescale thumbnail for mimeType=$mimeType uri=$uri width=$width height=$height" +
                                ", with bitmap byteCount=${bitmap.byteCount} size=${bitmap.width}x${bitmap.height}, to target=${dstWidth}x${dstHeight}" +
                                ", reduced by ${(reduction * 100).roundToInt()}%)"
                    )
                    bitmap = bitmap.scale(dstWidth, dstHeight)
                }
            }

            if (bitmap.byteCount > BITMAP_SIZE_DANGER_THRESHOLD) {
                result.error(
                    "getThumbnail-large", "thumbnail bitmap dangerously large" +
                            " for mimeType=$mimeType uri=$uri pageId=$pageId width=$width height=$height" +
                            ", with bitmap byteCount=${bitmap.byteCount} size=${bitmap.width}x${bitmap.height} config=${bitmap.config?.name}", null
                )
                return
            }
        }

        // do not recycle bitmaps fetched from `ContentResolver` or Glide as their lifecycle is unknown
        val bytes = BitmapUtils.getBytes(bitmap, recycle = false, decoded = decoded, applyGainmap = false, mimeType = mimeType)
        if (bytes == null) {
            var errorDetails: String? = exception?.message
            if (errorDetails?.isNotEmpty() == true) {
                errorDetails = errorDetails.split(Regex("\n"), 2).first()
            }
            result.error("getThumbnail-null", "failed to get thumbnail for mimeType=$mimeType uri=$uri", errorDetails)
        } else {
            result.streamBytes(ByteArrayInputStream(bytes))
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.Q)
    fun getByResolver(): Bitmap? {
        val resolver = context.contentResolver
        var bitmap: Bitmap? = resolver.loadThumbnail(uri, Size(width, height), null)
        if (needRotationAfterContentResolverThumbnail(mimeType)) {
            bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
        }
        return bitmap
    }

    fun getByMediaStore(): Bitmap? {
        val contentId = uri.tryParseId() ?: return null
        val resolver = context.contentResolver
        return if (isVideo(mimeType)) {
            @Suppress("DEPRECATION")
            MediaStore.Video.Thumbnails.getThumbnail(resolver, contentId, MediaStore.Video.Thumbnails.MINI_KIND, null)
        } else {
            @Suppress("DEPRECATION")
            var bitmap = MediaStore.Images.Thumbnails.getThumbnail(resolver, contentId, MediaStore.Images.Thumbnails.MINI_KIND, null)
            // from Android 10 (API 29), returned thumbnail is already rotated according to EXIF orientation
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q && bitmap != null) {
                bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
            }
            bitmap
        }
    }

    fun getByGlide(): Bitmap? {
        // add signature to ignore cache for images which got modified but kept the same URI
        var options = RequestOptions()
            .format(DecodeFormat.PREFER_ARGB_8888)
            .signature(ObjectKey("$dateModifiedMillis-$rotationDegrees-$isFlipped-$width-$pageId"))
            .override(width, height)
        if (isVideo(mimeType)) {
            options = options.diskCacheStrategy(DiskCacheStrategy.RESOURCE)
        }

        val target = Glide.with(context)
            .asBitmap()
            .apply(options)
            .load(AvesAppGlideModule.getModel(context, uri, mimeType, pageId))
            .submit(width, height)

        return try {
            var bitmap = target.get()
            if (needRotationAfterGlide(mimeType, pageId)) {
                bitmap = applyExifOrientation(context, bitmap, rotationDegrees, isFlipped)
            }
            bitmap
        } finally {
            Glide.with(context).clear(target)
        }
    }

    companion object {
        private val LOG_TAG = LogUtils.createTag<ThumbnailFetcher>()
        private const val BITMAP_SIZE_DANGER_THRESHOLD = 20 * (1 shl 20) // MiB
        private const val DEFAULT_SIZE_DIP: Double = 64.0
        // beyond this size the system media provider has no suitable cached thumbnail,
        // so we let Glide decode from the source file instead
        private const val MAX_SYSTEM_THUMBNAIL_SIZE = 512
        private const val RESCALE_REDUCTION_THRESHOLD: Float = .15f
    }
}