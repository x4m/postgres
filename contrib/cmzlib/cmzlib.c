/*-------------------------------------------------------------------------
 *
 * cmzlib.c
 *	  zlib compression method
 *
 * Copyright (c) 2015-2018, PostgreSQL Global Development Group
 *
 *
 * IDENTIFICATION
 *	  contrib/cmzlib/cmzlib.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"
#include "access/compressamapi.h"
#include "access/toast_internals.h"

#include "fmgr.h"
#include "utils/builtins.h"

#include <zlib.h>

PG_MODULE_MAGIC;

PG_FUNCTION_INFO_V1(zlibhandler);

void		_PG_init(void);

/*
 * Module initialize function: initialize info about zlib
 */
void
_PG_init(void)
{

}

#define ZLIB_MAX_DICTIONARY_LENGTH		32768
#define ZLIB_DICTIONARY_DELIM			(" ,")

typedef struct
{
	int			level;
	Bytef		dict[ZLIB_MAX_DICTIONARY_LENGTH];
	unsigned int dictlen;
} zlib_state;

/*
 * zlib_cmcompress - compression routine for zlib compression method
 *
 * Compresses source into dest using the default compression level.
 * Returns the compressed varlena, or NULL if compression fails.
 */
static struct varlena *
zlib_cmcompress(const struct varlena *value, int32 header_size)
{
	int32		valsize,
				len;
	struct varlena *tmp = NULL;
	z_streamp	zp;
	int			res;
	zlib_state	state;

	state.level = Z_DEFAULT_COMPRESSION;

	zp = (z_streamp) palloc(sizeof(z_stream));
	zp->zalloc = Z_NULL;
	zp->zfree = Z_NULL;
	zp->opaque = Z_NULL;

	if (deflateInit(zp, state.level) != Z_OK)
		elog(ERROR, "could not initialize compression library: %s", zp->msg);

	valsize = VARSIZE_ANY_EXHDR(DatumGetPointer(value));
	tmp = (struct varlena *) palloc(valsize + header_size);
	zp->next_in = (void *) VARDATA_ANY(value);
	zp->avail_in = valsize;
	zp->avail_out = valsize;
	zp->next_out = (void *) ((char *) tmp + header_size);

	do
	{
		res = deflate(zp, Z_FINISH);
		if (res == Z_STREAM_ERROR)
			elog(ERROR, "could not compress data: %s", zp->msg);
	} while (zp->avail_in != 0);

	Assert(res == Z_STREAM_END);

	len = valsize - zp->avail_out;
	if (deflateEnd(zp) != Z_OK)
		elog(ERROR, "could not close compression stream: %s", zp->msg);
	pfree(zp);

	if (len > 0)
	{
		SET_VARSIZE_COMPRESSED(tmp, len + header_size);
		return tmp;
	}

	pfree(tmp);
	return NULL;
}

/*
 * zlib_cmdecompress - decompression routine for zlib compression method
 *
 * Returns the decompressed varlena.
 */
static struct varlena *
zlib_cmdecompress(const struct varlena *value, int32 header_size)
{
	struct varlena *result;
	z_streamp	zp;
	int			res = Z_OK;

	zp = (z_streamp) palloc(sizeof(z_stream));
	zp->zalloc = Z_NULL;
	zp->zfree = Z_NULL;
	zp->opaque = Z_NULL;

	if (inflateInit(zp) != Z_OK)
		elog(ERROR, "could not initialize compression library: %s", zp->msg);

	zp->next_in = (void *) ((char *) value + header_size);
	zp->avail_in = VARSIZE(value) - header_size;
	zp->avail_out = VARRAWSIZE_4B_C(value);

	result = (struct varlena *) palloc(zp->avail_out + VARHDRSZ);
	SET_VARSIZE(result, zp->avail_out + VARHDRSZ);
	zp->next_out = (void *) VARDATA(result);

	while (zp->avail_in > 0)
	{
		res = inflate(zp, 0);
		if (!(res == Z_OK || res == Z_STREAM_END))
			elog(ERROR, "could not uncompress data: %s", zp->msg);
	}

	if (inflateEnd(zp) != Z_OK)
		elog(ERROR, "could not close compression library: %s", zp->msg);

	pfree(zp);
	return result;
}

const CompressionAmRoutine zlib_compress_methods = {
	.type = T_CompressionAmRoutine,
	.datum_compress = zlib_cmcompress,
	.datum_decompress = zlib_cmdecompress,
	.datum_decompress_slice = NULL};

Datum
zlibhandler(PG_FUNCTION_ARGS)
{
	PG_RETURN_POINTER(&zlib_compress_methods);
}
