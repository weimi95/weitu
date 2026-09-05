package com.weitu.gallery.metadata

import android.content.Context
import android.net.Uri
import com.weitu.gallery.metadata.Metadata.TYPE_COMMENT
import com.weitu.gallery.metadata.Metadata.TYPE_EXIF
import com.weitu.gallery.metadata.Metadata.TYPE_ICC_PROFILE
import com.weitu.gallery.metadata.Metadata.TYPE_IPTC
import com.weitu.gallery.metadata.Metadata.TYPE_JFIF
import com.weitu.gallery.metadata.Metadata.TYPE_JPEG_ADOBE
import com.weitu.gallery.metadata.Metadata.TYPE_JPEG_DUCKY
import com.weitu.gallery.metadata.Metadata.TYPE_PHOTOSHOP_IRB
import com.weitu.gallery.metadata.Metadata.TYPE_XMP
import com.weitu.gallery.model.FieldMap
import com.weitu.gallery.utils.MimeTypes
import com.weitu.gallery.utils.StorageUtils
import pixy.meta.meta.Metadata
import pixy.meta.meta.MetadataEntry
import pixy.meta.meta.MetadataType
import pixy.meta.meta.iptc.IPTC
import pixy.meta.meta.iptc.IPTCDataSet
import pixy.meta.meta.iptc.IPTCRecord
import pixy.meta.meta.jpeg.JPGMeta
import pixy.meta.meta.xmp.XMP
import pixy.meta.string.XMLUtils
import java.io.File
import java.io.InputStream
import java.io.OutputStream

object PixyMetaHelper {
    fun describe(input: InputStream): HashMap<String, String> {
        val metadataMap = HashMap<String, String>()

        fun fetch(parents: String, entries: Iterable<MetadataEntry>) {
            for (entry in entries) {
                metadataMap["$parents ${entry.key}"] = entry.value
                if (entry.isMetadataEntryGroup) {
                    fetch("$parents ${entry.key} /", entry.metadataEntries)
                }
            }
        }

        val metadataByType = Metadata.readMetadata(input)
        for ((type, metadata) in metadataByType.entries) {
            if (type == MetadataType.XMP) {
                val xmp = metadataByType[MetadataType.XMP] as XMP?
                if (xmp != null) {
                    metadataMap["XMP"] = xmp.xmpDocString()
                    if (xmp.hasExtendedXmp()) {
                        metadataMap["XMP extended"] = xmp.extendedXmpDocString()
                    }
                }
            } else {
                fetch("$type /", metadata)
            }
        }

        return metadataMap
    }

    fun getIptc(input: InputStream): List<FieldMap>? {
        val iptc = Metadata.readMetadata(input)[MetadataType.IPTC] as? IPTC? ?: return null

        val iptcDataList = ArrayList<FieldMap>()
        iptc.dataSets.forEach { dataSetEntry ->
            val tag = dataSetEntry.key
            val dataSets = dataSetEntry.value
            iptcDataList.add(
                hashMapOf(
                    "record" to tag.recordNumber,
                    "tag" to tag.tag,
                    "values" to dataSets.map { it.data }.toMutableList(),
                )
            )
        }
        return iptcDataList
    }

    fun setIptc(
        input: InputStream,
        output: OutputStream,
        iptcDataList: List<FieldMap>?,
    ) {
        val iptc: List<IPTCDataSet> = iptcDataList?.flatMap {
            val record = it["record"] as Int
            val tag = it["tag"] as Int
            val values = it["values"] as List<*>
            values.map { data -> IPTCDataSet(IPTCRecord.fromRecordNumber(record), tag, data as ByteArray) }
        } ?: ArrayList()
        Metadata.insertIPTC(input, output, iptc)
    }

    fun getXmp(input: InputStream): XMP? = Metadata.readMetadata(input)[MetadataType.XMP] as XMP?

    // PixyMeta may fail with just a log, and write nothing to the output
    fun setXmp(
        input: InputStream,
        output: OutputStream,
        xmpString: String?,
        extendedXmpString: String?
    ) {
        if (extendedXmpString != null) {
            JPGMeta.insertXMP(input, output, xmpString, extendedXmpString)
        } else {
            Metadata.insertXMP(input, output, xmpString)
        }
    }

    fun XMP.xmpDocString(): String = XMLUtils.serializeToString(xmpDocument)

    fun XMP.extendedXmpDocString(): String = XMLUtils.serializeToString(extendedXmpDocument)

    fun copyIptcXmp(
        context: Context,
        sourceMimeType: String,
        sourceUri: Uri,
        targetMimeType: String,
        targetUri: Uri,
        editableFile: File,
        fallbackXmp: String? = null,
    ) {
        var pixyIptc: IPTC? = null
        var pixyXmp: XMP? = null
        if (MimeTypes.canReadWithPixyMeta(sourceMimeType)) {
            StorageUtils.openInputStream(context, sourceUri)?.use { input ->
                val metadata = Metadata.readMetadata(input)
                if (MimeTypes.canEditIptc(targetMimeType)) {
                    pixyIptc = metadata[MetadataType.IPTC] as IPTC?
                }
                if (MimeTypes.canEditXmp(targetMimeType)) {
                    pixyXmp = metadata[MetadataType.XMP] as XMP?
                }
            }
        }
        if (pixyIptc != null || pixyXmp != null || fallbackXmp != null) {
            editableFile.outputStream().use { output ->
                if (pixyIptc != null) {
                    // reopen input to read from start
                    StorageUtils.openInputStream(context, targetUri)?.use { input ->
                        val iptcs = pixyIptc.dataSets.flatMap { it.value }
                        Metadata.insertIPTC(input, output, iptcs)
                    }
                }
                if (pixyXmp != null) {
                    // reopen input to read from start
                    StorageUtils.openInputStream(context, targetUri)?.use { input ->
                        val xmpString = pixyXmp.xmpDocString()
                        val extendedXmp = if (pixyXmp.hasExtendedXmp()) pixyXmp.extendedXmpDocString() else null
                        setXmp(input, output, xmpString, if (targetMimeType == MimeTypes.JPEG) extendedXmp else null)
                    }
                } else if (fallbackXmp != null && MimeTypes.canEditXmp(targetMimeType)) {
                    // reopen input to read from start
                    StorageUtils.openInputStream(context, targetUri)?.use { input ->
                        setXmp(input, output, fallbackXmp, null)
                    }
                }
            }
        }
    }

    // Build a minimal Dublin Core (dc) XMP packet from locally stored metadata
    // (title / description / subjects), so it can be baked into a converted file
    // for source formats that cannot store metadata in the file itself (e.g. HEIC).
    // dc:title/dc:description are language alternatives (rdf:Alt) and dc:subject is
    // an unordered bag (rdf:Bag), which is what metadata-extractor / Aves expect.
    fun buildDublinCoreXmp(title: String?, description: String?, subjects: String?): String? {
        if (title.isNullOrBlank() && description.isNullOrBlank() && subjects.isNullOrBlank()) return null
        val subjectList = subjects?.split(';')?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()
        val sb = StringBuilder()
        sb.append("<?xpacket begin=\"\" id=\"W5M0MpCehiHzreSzNTczkc9d\"?>")
        sb.append("<x:xmpmeta xmlns:x=\"adobe:ns:meta/\" x:xmptk=\"Adobe XMP Core 5.1.0\">")
        sb.append("<rdf:RDF xmlns:rdf=\"http://www.w3.org/1999/02/22-rdf-syntax-ns#\">")
        sb.append("<rdf:Description rdf:about=\"\" xmlns:dc=\"http://purl.org/dc/elements/1.1/\">")
        if (!title.isNullOrBlank()) {
            sb.append("<dc:title><rdf:Alt><rdf:li xml:lang=\"x-default\">").append(escapeXml(title)).append("</rdf:li></rdf:Alt></dc:title>")
        }
        if (!description.isNullOrBlank()) {
            sb.append("<dc:description><rdf:Alt><rdf:li xml:lang=\"x-default\">").append(escapeXml(description)).append("</rdf:li></rdf:Alt></dc:description>")
        }
        if (subjectList.isNotEmpty()) {
            sb.append("<dc:subject><rdf:Bag>")
            subjectList.forEach { sb.append("<rdf:li>").append(escapeXml(it)).append("</rdf:li>") }
            sb.append("</rdf:Bag></dc:subject>")
        }
        sb.append("</rdf:Description>")
        sb.append("</rdf:RDF></x:xmpmeta>")
        sb.append("<?xpacket end=\"w\"?>")
        return sb.toString()
    }

    private fun escapeXml(s: String): String {
        return s.replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
            .replace("'", "&apos;")
    }

    fun removeMetadata(input: InputStream, output: OutputStream, metadataTypes: Set<String>) {
        val types = metadataTypes.map(::toMetadataType).toTypedArray()
        Metadata.removeMetadata(input, output, *types)
    }

    private fun toMetadataType(typeString: String): MetadataType? = when (typeString) {
        TYPE_COMMENT -> MetadataType.COMMENT
        TYPE_EXIF -> MetadataType.EXIF
        TYPE_ICC_PROFILE -> MetadataType.ICC_PROFILE
        TYPE_IPTC -> MetadataType.IPTC
        TYPE_JFIF -> MetadataType.JPG_JFIF
        TYPE_JPEG_ADOBE -> MetadataType.JPG_ADOBE
        TYPE_JPEG_DUCKY -> MetadataType.JPG_DUCKY
        TYPE_PHOTOSHOP_IRB -> MetadataType.PHOTOSHOP_IRB
        TYPE_XMP -> MetadataType.XMP
        else -> null
    }
}