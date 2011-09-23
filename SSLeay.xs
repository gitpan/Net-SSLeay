/* SSLeay.xs - Perl module for using Eric Young's implementation of SSL
 *
 * Copyright (c) 1996-2002 Sampo Kellomaki <sampo@iki.fi>
 * Copyright (C) 2005 Florian Ragwitz <rafl@debian.org>
 * Copyright (C) 2005 Mike McCauley <mikem@open.com.au>
 * 
 * All Rights Reserved.
 *
 * Change data removed. See Changes
 *
 * $Id: SSLeay.xs 276 2011-09-23 02:40:02Z mikem-guest $
 * 
 * The distribution and use of this module are subject to the conditions
 * listed in LICENSE file at the root of OpenSSL-0.9.6b
 * distribution (i.e. free, but mandatory attribution and NO WARRANTY).
 */

/* Prevent warnings about strncpy from Windows compilers */
#define _CRT_SECURE_NO_DEPRECATE

#ifdef __cplusplus
extern "C" {
#endif
#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"
#ifdef __cplusplus
}
#endif

/* OpenSSL-0.9.3a has some strange warning about this in
 *    openssl/des.h
 */
#undef _

/* Sigh: openssl 1.0 has
 typedef void *BLOCK;
which conflicts with perls
 typedef struct block BLOCK;
*/
#define BLOCK OPENSSL_BLOCK
#include <openssl/err.h>
#include <openssl/lhash.h>
#include <openssl/rand.h>
#include <openssl/buffer.h>
#include <openssl/ssl.h>
#include <openssl/pkcs12.h>
#include <openssl/comp.h>    /* openssl-0.9.6a forgets to include this */
#ifndef OPENSSL_NO_MD2
#include <openssl/md2.h>
#endif
#include <openssl/md4.h>
#include <openssl/md5.h>     /* openssl-SNAP-20020227 does not automatically include this */
#if OPENSSL_VERSION_NUMBER >= 0x00905000L
#include <openssl/ripemd.h>
#endif
#include <openssl/x509.h>
#include <openssl/x509v3.h>
#include <openssl/engine.h>
#undef BLOCK

/* Debugging output */

#if 0
#define PR(s) printf(s);
#define PRN(s,n) printf("'%s' (%d)\n",s,n);
#define SEX_DEBUG 1
#else
#define PR(s)
#define PRN(s,n)
#undef  SEX_DEBUG
#endif

#include "constants.c"

/* ============= typedefs to agument TYPEMAP ============== */

typedef void callback_no_ret(void);
typedef void cb_ssl_int_int_ret_void(const SSL *ssl,int,int);
typedef RSA * cb_ssl_int_int_ret_RSA(SSL * ssl,int is_export, int keylength);
typedef DH * cb_ssl_int_int_ret_DH(SSL * ssl,int is_export, int keylength);

typedef STACK_OF(X509_NAME) X509_NAME_STACK;

typedef int perl_filehandle_t;

/* ============= callback stuff ============== */

static HV* ssleay_ctx_verify_callbacks = (HV*)NULL;

static int
ssleay_verify_callback_invoke (int ok, X509_STORE_CTX* x509_store) {
	SSL* ssl;
	SV* key;
	char* key_str;
	STRLEN key_len;
	SV** callback;
	int count, res;
	dSP;

	ssl = X509_STORE_CTX_get_ex_data( x509_store, SSL_get_ex_data_X509_STORE_CTX_idx() );
	key = sv_2mortal(newSViv( (IV)ssl ));
	key_str = SvPV(key, key_len);

	callback = hv_fetch( ssleay_ctx_verify_callbacks, key_str, key_len, 0 );

	if (callback == NULL) {
		SSL_CTX* ssl_ctx = SSL_get_SSL_CTX(ssl);
		key = sv_2mortal(newSViv( (IV)ssl_ctx ));
		key_str = SvPV(key, key_len);

		callback = hv_fetch( ssleay_ctx_verify_callbacks, key_str, key_len, 0 );

		if (callback == NULL) {
			croak ("Net::SSLeay: verify_callback called, but not "
				"set to point to any perl function.\n");
		}
	}


	ENTER;
	SAVETMPS;

	PRN("verify callback glue", ok);

	PUSHMARK(sp);
	EXTEND( sp, 2 );
	PUSHs( sv_2mortal(newSViv(ok)) );
	PUSHs( sv_2mortal(newSViv(PTR2IV(x509_store))) );
	PUTBACK;

	PR("About to call verify callback.\n");
	count = call_sv(*callback, G_SCALAR);
	PR("Returned from verify callback.\n");

	SPAGAIN;

	if (count != 1) {
		croak ( "Net::SSLeay: verify_callback "
			"perl function did not return a scalar.\n");
	}

	res = POPi;

	PUTBACK;
	FREETMPS;
	LEAVE;

	return res;
}

static HV* ssleay_ctx_passwd_cbs = (HV*)NULL;

struct _ssleay_cb_t {
	SV* func;
	SV* data;
};
typedef struct _ssleay_cb_t ssleay_ctx_passwd_cb_t;
typedef struct _ssleay_cb_t ssleay_ctx_cert_verify_cb_t;
typedef struct _ssleay_cb_t ssleay_session_secret_cb_t;
typedef struct _ssleay_cb_t ssleay_RSA_generate_key_cb_t;

ssleay_ctx_passwd_cb_t*
ssleay_ctx_passwd_cb_new(SSL_CTX* ctx) {
	ssleay_ctx_passwd_cb_t* cb;
	SV* hash_value;
	SV* key;
	char* key_str;
	STRLEN key_len;

	New(0, cb, 1, ssleay_ctx_passwd_cb_t);
	cb->func = NULL;
	cb->data = NULL;

	if (ctx == NULL)
		croak( "Net::SSLeay: ctx == NULL in ssleay_ctx_passwd_cb_new" );

	hash_value = sv_2mortal(newSViv( (IV)cb ));

	key = sv_2mortal(newSViv( (IV)ctx ));
	key_str = SvPV(key, key_len);

	if (ssleay_ctx_passwd_cbs == (HV*)NULL)
		ssleay_ctx_passwd_cbs = newHV();

	SvREFCNT_inc(hash_value);
	hv_store( ssleay_ctx_passwd_cbs, key_str, key_len, hash_value, 0 );

	return cb;
}

ssleay_ctx_passwd_cb_t*
ssleay_ctx_passwd_cb_get(SSL_CTX* ctx) {
	SV* key;
	char* key_str;
	STRLEN key_len;
	SV** hash_value;
	ssleay_ctx_passwd_cb_t* cb;

	key = sv_2mortal(newSViv( (IV)ctx ));
	key_str = SvPV(key, key_len);

	hash_value = hv_fetch( ssleay_ctx_passwd_cbs, key_str, key_len, 0 );

	if (hash_value == NULL || *hash_value == NULL) {
		cb = ssleay_ctx_passwd_cb_new(ctx);
	} else {
		cb = (ssleay_ctx_passwd_cb_t*)SvIV( *hash_value );
	}

	return cb;
}

void
ssleay_ctx_passwd_cb_func_set(SSL_CTX* ctx, SV* func) {
	ssleay_ctx_passwd_cb_t* cb;

	cb = ssleay_ctx_passwd_cb_get(ctx);

	if (cb->func)
		SvREFCNT_dec(cb->func);

	SvREFCNT_inc(func);
	cb->func = func;
}

void
ssleay_ctx_passwd_cb_userdata_set(SSL_CTX* ctx, SV* data) {
	ssleay_ctx_passwd_cb_t* cb;

	cb = ssleay_ctx_passwd_cb_get(ctx);

	if (cb->data)
		SvREFCNT_dec(cb->data);

	SvREFCNT_inc(data);
	cb->data = data;
}

void
ssleay_ctx_passwd_cb_free_func(SSL_CTX* ctx) {
	ssleay_ctx_passwd_cb_t* cb;

	cb = ssleay_ctx_passwd_cb_get(ctx);

	if (cb && cb->func) {
		SvREFCNT_dec(cb->func);
		cb->func = NULL;
	}
}

void
ssleay_ctx_passwd_cb_free_userdata(SSL_CTX* ctx) {
	ssleay_ctx_passwd_cb_t* cb;

	cb = ssleay_ctx_passwd_cb_get(ctx);

	if (cb && cb->data) {
		SvREFCNT_dec(cb->data);
		cb->data = NULL;
	}
}

/* pem_password_cb function */

static int
ssleay_ctx_passwd_cb_invoke(char *buf, int size, int rwflag, void *userdata) {
	dSP;

	int count;
	char *res;
	ssleay_ctx_passwd_cb_t* cb = (ssleay_ctx_passwd_cb_t*)userdata;

	ENTER;
	SAVETMPS;

	PUSHMARK(sp);
	XPUSHs( sv_2mortal( newSViv(rwflag)) );
	if (cb->data)
		XPUSHs( cb->data );
	PUTBACK;

	if (cb->func == NULL)
		croak ("Net::SSLeay: ssleay_ctx_passwd_cb_invoke called, but not "
			   "set to point to any perl function.\n");

	count = call_sv( cb->func, G_SCALAR );

	SPAGAIN;

	if (count != 1)
		croak ("Net::SSLeay: ssleay_ctx_passwd_cb_invoke "
			   "perl function did not return a scalar.\n");

	res = POPp;

	if (res == NULL) {
		*buf = '\0';
	} else {
		strncpy(buf, res, size);
		buf[size - 1] = '\0';
	}

	PUTBACK;
	FREETMPS;
	LEAVE;

	return strlen(buf);
}

static HV* ssleay_ctx_cert_verify_cbs = (HV*)NULL;

ssleay_ctx_cert_verify_cb_t*
ssleay_ctx_cert_verify_cb_new(SSL_CTX* ctx, SV* func, SV* data) {
	ssleay_ctx_cert_verify_cb_t* cb;
	SV* hash_value;
	SV* key;
	char* key_str;
	STRLEN key_len;

	cb = New(0, cb, 1, ssleay_ctx_cert_verify_cb_t);

	SvREFCNT_inc(func);
	SvREFCNT_inc(data);
	cb->func = func;
	cb->data = data;

	if (ctx == NULL) {
		croak( "Net::SSLeay: ctx == NULL in ssleay_ctx_cert_verify_cb_new" );
	}

	hash_value = sv_2mortal(newSViv( (IV)cb ));

	key = sv_2mortal(newSViv( (IV)ctx ));
	key_str = SvPV(key, key_len);

	if (ssleay_ctx_cert_verify_cbs == (HV*)NULL)
		ssleay_ctx_cert_verify_cbs = newHV();

	SvREFCNT_inc(hash_value);
	hv_store( ssleay_ctx_cert_verify_cbs, key_str, key_len, hash_value, 0 );

	return cb;
}

ssleay_ctx_cert_verify_cb_t*
ssleay_ctx_cert_verify_cb_get(SSL_CTX* ctx) {
	SV* key;
	char* key_str;
	STRLEN key_len;
	SV** hash_value;
	ssleay_ctx_cert_verify_cb_t* cb;

	key = sv_2mortal(newSViv( (IV)ctx ));
	key_str = SvPV(key, key_len);

	hash_value = hv_fetch( ssleay_ctx_cert_verify_cbs, key_str, key_len, 0 );

	if (hash_value == NULL || *hash_value == NULL) {
		cb = NULL;
	} else {
		cb = (ssleay_ctx_cert_verify_cb_t*)SvIV( *hash_value );
	}

	return cb;
}

void
ssleay_ctx_cert_verify_cb_free(SSL_CTX* ctx) {
	ssleay_ctx_passwd_cb_t* cb;

	cb = ssleay_ctx_cert_verify_cb_get(ctx);

	if (cb) {
		if (cb->func) {
			SvREFCNT_dec(cb->func);
			cb->func = NULL;
		}

		if (cb->data) {
			SvREFCNT_dec(cb->data);
			cb->data = NULL;
		}
	}

	Safefree(cb);
}

int
ssleay_ctx_cert_verify_cb_invoke(X509_STORE_CTX* x509_store_ctx, void* data) {
	dSP;

	int count;
	int res;
	ssleay_ctx_cert_verify_cb_t* cb = (ssleay_ctx_cert_verify_cb_t*)data;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs(sv_2mortal(newSViv( (IV)x509_store_ctx )));
	if (cb->data) {
		XPUSHs( cb->data );
	}
	PUTBACK;

	if (cb->func == NULL) {
		croak ("Net::SSLeay: ssleay_ctx_cert_verify_cb_invoke called, but not "
				"set to point to any perl function.\n");
	}

	count = call_sv( cb->func, G_SCALAR );

	SPAGAIN;

	if (count != 1) {
		croak ("Net::SSLeay: ssleay_ctx_cert_verify_cb_invoke "
				"perl function did not return a scalar.\n");
	}

	res = POPi;

	PUTBACK;
	FREETMPS;
	LEAVE;

	return res;
}

#if defined(SSL_F_SSL_SET_HELLO_EXTENSION) || defined(SSL_F_SSL_SET_SESSION_TICKET_EXT)
static HV* ssleay_session_secret_cbs = (HV*)NULL;

ssleay_session_secret_cb_t*
ssleay_session_secret_cb_new(SSL* s, SV* func, SV* data) {
	ssleay_session_secret_cb_t* cb;
	SV* hash_value;
	SV* key;
	char* key_str;
	STRLEN key_len;

	cb = New(0, cb, 1, ssleay_session_secret_cb_t);

	SvREFCNT_inc(func);
	SvREFCNT_inc(data);
	cb->func = func;
	cb->data = data;

	if (s == NULL) {
		croak( "Net::SSLeay: s == NULL in ssleay_session_secret_cb_new" );
	}

	hash_value = sv_2mortal(newSViv( (IV)cb ));

	key = sv_2mortal(newSViv( (IV)s ));
	key_str = SvPV(key, key_len);

	if (ssleay_session_secret_cbs == (HV*)NULL)
		ssleay_session_secret_cbs = newHV();

	SvREFCNT_inc(hash_value);
	hv_store( ssleay_session_secret_cbs, key_str, key_len, hash_value, 0 );

	return cb;
}

ssleay_session_secret_cb_t*
ssleay_session_secret_cb_get(SSL* s) {
	SV* key;
	char* key_str;
	STRLEN key_len;
	SV** hash_value;
	ssleay_session_secret_cb_t* cb;

	key = sv_2mortal(newSViv( (IV)s ));
	key_str = SvPV(key, key_len);

	hash_value = hv_fetch( ssleay_session_secret_cbs, key_str, key_len, 0 );

	if (hash_value == NULL || *hash_value == NULL) {
		cb = NULL;
	} else {
		cb = (ssleay_session_secret_cb_t*)SvIV( *hash_value );
	}

	return cb;
}

void
ssleay_session_secret_cb_free(SSL* s) {
	ssleay_session_secret_cb_t* cb;

	cb = ssleay_session_secret_cb_get(s);

	if (cb) {
		if (cb->func) {
			SvREFCNT_dec(cb->func);
			cb->func = NULL;
		}

		if (cb->data) {
			SvREFCNT_dec(cb->data);
			cb->data = NULL;
		}
	}

	Safefree(cb);
}

int
ssleay_session_secret_cb_invoke(SSL* s, void* secret, int *secret_len,
			   STACK_OF(SSL_CIPHER) *peer_ciphers,
			   SSL_CIPHER **cipher, void *arg) 
{
	dSP;

	int count;
	int res;
	int i;
	AV *ciphers = newAV();
	SV *pref_cipher = sv_newmortal();
	ssleay_session_secret_cb_t* cb = (ssleay_session_secret_cb_t*)arg;

	ENTER;
	SAVETMPS;

	PUSHMARK(SP);
	XPUSHs( sv_2mortal( newSVpv(secret, *secret_len)) );
	for (i=0; i<sk_SSL_CIPHER_num(peer_ciphers); i++)
	{
	    SSL_CIPHER *c = sk_SSL_CIPHER_value(peer_ciphers,i);
	    av_store(ciphers, i, sv_2mortal(newSVpv(SSL_CIPHER_get_name(c), 0)));
	}
	XPUSHs(sv_2mortal(newRV((SV*)ciphers)));
	XPUSHs(sv_2mortal(newRV(pref_cipher)));
	if (cb->data) {
		XPUSHs( cb->data );
	}
	PUTBACK;

	if (cb->func == NULL) {
		croak ("Net::SSLeay: ssleay_session_secret_cb_invoke called, but not "
				"set to point to any perl function.\n");
	}

	count = call_sv( cb->func, G_SCALAR );

	SPAGAIN;

	if (count != 1) {
		croak ("Net::SSLeay: ssleay_session_secret_cb_invoke "
				"perl function did not return a scalar.\n");
	}

	res = POPi;
	if (res)
	{
	    /* See if there is a preferred cipher selected, if so
	       it is an index into the stack */
	    if (SvIOK(pref_cipher))
	    {
		*cipher = sk_SSL_CIPHER_value(peer_ciphers, SvIV(pref_cipher));
	    }
	}

	PUTBACK;
	FREETMPS;
	LEAVE;

	return res;
}

#endif

ssleay_RSA_generate_key_cb_t*
ssleay_RSA_generate_key_cb_new(SV* func, SV* data) {
	ssleay_RSA_generate_key_cb_t* cb;

	New(0, cb, 1, ssleay_RSA_generate_key_cb_t);
	cb->func = NULL;
	cb->data = NULL;

	if (func) {
		SvREFCNT_inc(func);
		cb->func = func;
	}

	if (data) {
		SvREFCNT_inc(data);
		cb->data = data;
	}

	return cb;
}

void
ssleay_RSA_generate_key_cb_free(ssleay_RSA_generate_key_cb_t* cb) {
	if (cb) {
		if (cb->func) {
			SvREFCNT_dec(cb->func);
			cb->func = NULL;
		}

		if (cb->data) {
			SvREFCNT_dec(cb->data);
			cb->data = NULL;
		}
	}

	Safefree(cb);
}

void
ssleay_RSA_generate_key_cb_invoke(int i, int n, void* data) {
	dSP;

	ssleay_RSA_generate_key_cb_t* cb = (ssleay_RSA_generate_key_cb_t*)data;

	if (cb->func) {
		int count;

		ENTER;
		SAVETMPS;

		PUSHMARK(sp);

		XPUSHs(sv_2mortal( newSViv(i) ));
		XPUSHs(sv_2mortal( newSViv(n) ));

		if (cb->data)
			XPUSHs( cb->data );

		PUTBACK;

		count = call_sv( cb->func, G_VOID|G_DISCARD );

		if (count != 0)
			croak ("Net::SSLeay: ssleay_RSA_generate_key_cb_invoke "
					"perl function did return something in void context.\n");

		PUTBACK;
		FREETMPS;
		LEAVE;
	}
}


MODULE = Net::SSLeay		PACKAGE = Net::SSLeay          PREFIX = SSL_

PROTOTYPES: ENABLE

double
constant(name)
     char *		name

int
hello()
        CODE:
        PR("\tSSLeay Hello World!\n");
        RETVAL = 1;
        OUTPUT:
        RETVAL

#define REM1 "============= SSL CONTEXT functions =============="

SSL_CTX *
SSL_CTX_new()
     CODE:
     RETVAL = SSL_CTX_new (SSLv23_method());
     OUTPUT:
     RETVAL

#ifndef OPENSSL_NO_SSL2
#if OPENSSL_VERSION_NUMBER < 0x10000000L

SSL_CTX *
SSL_CTX_v2_new()
     CODE:
     RETVAL = SSL_CTX_new (SSLv2_method());
     OUTPUT:
     RETVAL

#endif
#endif

SSL_CTX *
SSL_CTX_v3_new()
     CODE:
     RETVAL = SSL_CTX_new (SSLv3_method());
     OUTPUT:
     RETVAL

SSL_CTX *
SSL_CTX_v23_new()
     CODE:
     RETVAL = SSL_CTX_new (SSLv23_method());
     OUTPUT:
     RETVAL

SSL_CTX *
SSL_CTX_tlsv1_new()
     CODE:
     RETVAL = SSL_CTX_new (TLSv1_method());
     OUTPUT:
     RETVAL

SSL_CTX *
SSL_CTX_new_with_method(meth)
     CODE:
     RETVAL = SSL_CTX_new (SSLv23_method());
     OUTPUT:
     RETVAL

void
SSL_CTX_free(ctx)
     SSL_CTX *	        ctx

int
SSL_CTX_add_session(ctx,ses)
     SSL_CTX *          ctx
     SSL_SESSION *      ses

int
SSL_CTX_remove_session(ctx,ses)
     SSL_CTX *          ctx
     SSL_SESSION *      ses

void
SSL_CTX_flush_sessions(ctx,tm)
     SSL_CTX *          ctx
     long               tm

int
SSL_CTX_set_default_verify_paths(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_load_verify_locations(ctx,CAfile,CApath)
     SSL_CTX * ctx
     char * CAfile
     char * CApath
     CODE:
     RETVAL = SSL_CTX_load_verify_locations (ctx,
					     CAfile?(*CAfile?CAfile:NULL):NULL,
					     CApath?(*CApath?CApath:NULL):NULL
					     );
     OUTPUT:
     RETVAL

void
SSL_CTX_set_verify(ctx,mode,callback=NULL)
	SSL_CTX * ctx
	int                mode
	SV *               callback
	PREINIT:
	SV* key;
	char* key_str;
	STRLEN key_len;
	CODE:

	if (ssleay_ctx_verify_callbacks == (HV*)NULL)
		ssleay_ctx_verify_callbacks = newHV();

	key = sv_2mortal(newSViv( (IV)ctx ));
	key_str = SvPV(key, key_len);

	/* Former versions of SSLeay checked if the callback was a true boolean value
	 * and didn't call it if it was false. Therefor some people set the callback
	 * to '0' if they don't want to use it (IO::Socket::SSL for example). Therefor
	 * we don't execute the callback if it's value isn't something true to retain
	 * backwards compatibility.
	 */

	if (callback == NULL || !SvTRUE(callback)) {
		hv_delete( ssleay_ctx_verify_callbacks, key_str, key_len, G_DISCARD );
		SSL_CTX_set_verify( ctx, mode, NULL );
	} else {
		hv_store( ssleay_ctx_verify_callbacks, key_str, key_len, newSVsv(callback), 0 );
		SSL_CTX_set_verify( ctx, mode, &ssleay_verify_callback_invoke );
	}

int
SSL_get_error(s,ret)
     SSL *              s
     int ret

#define REM10 "============= SSL functions =============="

SSL *
SSL_new(ctx)
     SSL_CTX *	        ctx

void
SSL_free(s)
     SSL *              s

#if 0 /* this seems to be gone in 0.9.0 */
void
SSL_debug(file)
       char *  file

#endif

int
SSL_accept(s)
     SSL *   s

void
SSL_clear(s)
     SSL *   s

int
SSL_connect(s)
     SSL *   s


#if defined(WIN32)

int
SSL_set_fd(s,fd)
     SSL *   s
     perl_filehandle_t     fd
     CODE:
     RETVAL = SSL_set_fd(s,_get_osfhandle(fd));
     OUTPUT:
     RETVAL

int
SSL_set_rfd(s,fd)
     SSL *   s
     perl_filehandle_t     fd
     CODE:
     RETVAL = SSL_set_rfd(s,_get_osfhandle(fd));
     OUTPUT:
     RETVAL

int
SSL_set_wfd(s,fd)
     SSL *   s
     perl_filehandle_t     fd
     CODE:
     RETVAL = SSL_set_wfd(s,_get_osfhandle(fd));
     OUTPUT:
     RETVAL

#else

int
SSL_set_fd(s,fd)
     SSL *   s
     perl_filehandle_t     fd

int
SSL_set_rfd(s,fd)
     SSL *   s
     perl_filehandle_t     fd

int
SSL_set_wfd(s,fd)
     SSL *   s
     perl_filehandle_t     fd

#endif

int
SSL_get_fd(s)
     SSL *   s

void
SSL_read(s,max=32768)
	SSL *   s
	int     max
	PREINIT:
	char *buf;
	int got;
	CODE:
	New(0, buf, max, char);
	ST(0) = sv_newmortal();   /* Undefined to start with */
	if ((got = SSL_read(s, buf, max)) >= 0)
		sv_setpvn( ST(0), buf, got);
	Safefree(buf);

void
SSL_peek(s,max=32768)
	SSL *   s
	int     max
	PREINIT:
	char *buf;
	int got;
	CODE:
	New(0, buf, max, char);
	ST(0) = sv_newmortal();   /* Undefined to start with */
	if ((got = SSL_peek(s, buf, max)) >= 0)
		sv_setpvn( ST(0), buf, got);
	Safefree(buf);

int
SSL_write(s,buf)
     SSL *   s
     PREINIT:
     STRLEN len;
     INPUT:
     char *  buf = SvPV( ST(1), len);
     CODE:
     RETVAL = SSL_write (s, buf, (int)len);
     OUTPUT:
     RETVAL

int
SSL_write_partial(s,from,count,buf)
     SSL *   s
     int     from
     int     count
     PREINIT:
     STRLEN len;
     INPUT:
     char *  buf = SvPV( ST(3), len);
     CODE:
      /*
     if (SvROK( ST(3) )) {
       SV* t = SvRV( ST(3) );
       buf = SvPV( t, len);
     } else
       buf = SvPV( ST(3), len);
       */
     PRN("write_partial from",from);
     PRN(&buf[from],len);
     PRN("write_partial count",count);
     len -= from;
     if (len < 0) {
       croak("from beyound end of buffer");
       RETVAL = -1;
     } else
       RETVAL = SSL_write (s, &(buf[from]), ((STRLEN)count<=len)?count:len);
     OUTPUT:
     RETVAL

int
SSL_use_RSAPrivateKey(s,rsa)
     SSL *              s
     RSA *              rsa

int
SSL_use_RSAPrivateKey_ASN1(s,d,len)
     SSL *              s
     unsigned char *    d
     long               len

int
SSL_use_RSAPrivateKey_file(s,file,type)
     SSL *              s
     char *             file
     int                type

int
SSL_CTX_use_RSAPrivateKey_file(ctx,file,type)
     SSL_CTX *          ctx
     char *             file
     int                type

int
SSL_use_PrivateKey(s,pkey)
     SSL *              s
     EVP_PKEY *         pkey

int
SSL_use_PrivateKey_ASN1(pk,s,d,len)
     int                pk
     SSL *              s
     unsigned char *    d
     long               len

int
SSL_use_PrivateKey_file(s,file,type)
     SSL *              s
     char *             file
     int                type

int
SSL_CTX_use_PrivateKey_file(ctx,file,type)
     SSL_CTX *          ctx
     char *             file
     int                type

int
SSL_use_certificate(s,x)
     SSL *              s
     X509 *             x

int
SSL_use_certificate_ASN1(s,d,len)
     SSL *              s
     unsigned char *    d
     long               len

int
SSL_use_certificate_file(s,file,type)
     SSL *              s
     char *             file
     int                type

int
SSL_CTX_use_certificate_file(ctx,file,type)
     SSL_CTX *          ctx
     char *             file
     int                type

const char *
SSL_state_string(s)
     SSL *              s

const char *
SSL_rstate_string(s)
     SSL *              s

const char *
SSL_state_string_long(s)
     SSL *              s

const char *
SSL_rstate_string_long(s)
     SSL *              s


long
SSL_get_time(ses)
     SSL_SESSION *      ses

long
SSL_set_time(ses,t)
     SSL_SESSION *      ses
     long               t

long
SSL_get_timeout(ses)
     SSL_SESSION *      ses

long
SSL_set_timeout(ses,t)
     SSL_SESSION *      ses
     long               t

void
SSL_copy_session_id(to,from)
     SSL *              to
     SSL *              from

void
SSL_set_read_ahead(s,yes=1)
     SSL *              s
     int                yes

int
SSL_get_read_ahead(s)
     SSL *              s

int
SSL_pending(s)
     SSL *              s

int
SSL_CTX_set_cipher_list(s,str)
     SSL_CTX *              s
     char *             str

const char *
SSL_get_cipher_list(s,n)
     SSL *              s
     int                n

int
SSL_set_cipher_list(s,str)
     SSL *              s
     char *       str

const char *
SSL_get_cipher(s)
     SSL *              s

char *
SSL_get_shared_ciphers(s,buf,len)
     SSL *              s
     char *             buf
     int                len

X509 *
SSL_get_peer_certificate(s)
     SSL *              s

void
SSL_set_verify(s,mode,callback)
    SSL *              s
    int                mode
    SV *               callback
	PREINIT:
	SV* key;
	char* key_str;
	STRLEN key_len;
    CODE:

	if (ssleay_ctx_verify_callbacks == (HV*)NULL)
		ssleay_ctx_verify_callbacks = newHV();

	key = sv_2mortal(newSViv( (IV)s ));
	key_str = SvPV(key, key_len);

	if (callback == NULL) {
		hv_delete( ssleay_ctx_verify_callbacks, key_str, key_len, G_DISCARD );
		SSL_set_verify( s, mode, NULL );
	} else {
		hv_store( ssleay_ctx_verify_callbacks, key_str, key_len, newSVsv(callback), 0 );
		SSL_set_verify( s, mode, &ssleay_verify_callback_invoke );
	}

void
SSL_set_bio(s,rbio,wbio)
     SSL *              s
     BIO *              rbio
     BIO *              wbio

BIO *
SSL_get_rbio(s)
     SSL *              s

BIO *
SSL_get_wbio(s)
     SSL *              s


SSL_SESSION *
SSL_SESSION_new()

int
SSL_SESSION_print(fp,ses)
     BIO *              fp
     SSL_SESSION *      ses

void
SSL_SESSION_free(ses)
     SSL_SESSION *      ses

int
i2d_SSL_SESSION(in,pp)
     SSL_SESSION *      in
     unsigned char *    &pp

int
SSL_set_session(to,ses)
     SSL *              to
     SSL_SESSION *      ses

SSL_SESSION *
d2i_SSL_SESSION(a,pp,length)
     SSL_SESSION *      &a
     const unsigned char *    &pp
     long               length

#define REM30 "SSLeay-0.9.0 defines these as macros. I expand them here for safety's sake"

SSL_SESSION *
SSL_get_session(s)
	SSL *              s
	ALIAS:
		SSL_get0_session = 1

SSL_SESSION *
SSL_get1_session(s)
     SSL *              s

X509 *
SSL_get_certificate(s)
     SSL *              s

SSL_CTX *
SSL_get_SSL_CTX(s)
     SSL *              s

long
SSL_ctrl(ssl,cmd,larg,parg)
	 SSL * ssl
	 int cmd
	 long larg
	 char * parg

long
SSL_CTX_ctrl(ctx,cmd,larg,parg)
    SSL_CTX * ctx
    int cmd
    long larg
    char * parg

long
SSL_get_options(ssl)
     SSL *          ssl

void
SSL_set_options(ssl,op)
     SSL *          ssl
     long	    op

long
SSL_CTX_get_options(ctx)
     SSL_CTX *      ctx

void
SSL_CTX_set_options(ctx,op)
     SSL_CTX *      ctx
     long	    op

#if OPENSSL_VERSION_NUMBER >= 0x10000000L

struct lhash_st_SSL_SESSION *
SSL_CTX_sessions(ctx)
     SSL_CTX *          ctx

#else

LHASH *
SSL_CTX_sessions(ctx)
     SSL_CTX *          ctx
     CODE:
    /* NOTE: This should be deprecated. Corresponding macro was removed from ssl.h as of 0.9.2 */
     if (ctx == NULL) croak("NULL SSL context passed as argument.");
     RETVAL = ctx -> sessions;
     OUTPUT:
     RETVAL

#endif

unsigned long
SSL_CTX_sess_number(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_connect(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_connect_good(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_connect_renegotiate(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_accept(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_accept_renegotiate(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_accept_good(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_hits(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_cb_hits(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_misses(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_timeouts(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_cache_full(ctx)
     SSL_CTX *          ctx

int
SSL_CTX_sess_get_cache_size(ctx)
     SSL_CTX *          ctx

void
SSL_CTX_sess_set_cache_size(ctx,size)
     SSL_CTX *          ctx
     int                size      

int
SSL_want(s)
     SSL *              s

int
SSL_state(s)
     SSL *              s

BIO_METHOD *
BIO_f_ssl()

BIO_METHOD *
BIO_s_mem()

unsigned long
ERR_get_error()

unsigned long
ERR_peek_error()

void
ERR_put_error(lib,func,reason,file,line)
     int                lib
     int                func
     int                reason
     char *             file
     int                line

void
ERR_clear_error()

char *
ERR_error_string(error,buf=NULL)
     unsigned long      error
     char *             buf
     CODE:
     RETVAL = ERR_error_string(error,buf);
     OUTPUT:
     RETVAL

void
SSL_load_error_strings()

void
ERR_load_crypto_strings()

int
SSL_library_init()
	ALIAS:
		SSLeay_add_ssl_algorithms  = 1
		OpenSSL_add_ssl_algorithms = 2
		add_ssl_algorithms         = 3

void
ENGINE_load_builtin_engines()

void
ENGINE_register_all_complete()

ENGINE*
ENGINE_by_id(id)
	char * id

int
ENGINE_set_default(e, flags)
        ENGINE * e
        int flags

void
ERR_load_SSL_strings()

void
ERR_load_RAND_strings()

int
RAND_bytes(buf, num)
    SV *buf
    int num
    PREINIT:
        int rc;
        unsigned char *random;
    CODE:
        New(0, random, num, unsigned char);
        rc = RAND_bytes(random, num);
        sv_setpvn(buf, (const char*)random, num);
        Safefree(random);
        RETVAL = rc;
    OUTPUT:
        RETVAL

int
RAND_pseudo_bytes(buf, num)
    SV *buf
    int num
    PREINIT:
        int rc;
        unsigned char *random;
    CODE:
        New(0, random, num, unsigned char);
        rc = RAND_pseudo_bytes(random, num);
        sv_setpvn(buf, (const char*)random, num);
        Safefree(random);
        RETVAL = rc;
    OUTPUT:
        RETVAL

void
RAND_add(buf, num, entropy)
    SV *buf
    int num
    double entropy
    PREINIT:
        STRLEN len;
    CODE:
        RAND_add((const void *)SvPV(buf, len), num, entropy);

int
RAND_poll()

int
RAND_status()

int
RAND_egd_bytes(path, bytes)
    const char *path
    int bytes

SV *
RAND_file_name(num)
    size_t num
    PREINIT:
        char *buf;
    CODE:
        New(0, buf, num, char);
        if (!RAND_file_name(buf, num)) {
            Safefree(buf);
            XSRETURN_UNDEF;
        }
        RETVAL = newSVpv(buf, 0);
        Safefree(buf);
    OUTPUT:
        RETVAL

void
RAND_seed(buf)
     PREINIT:
     STRLEN len;
     INPUT:
     char *  buf = SvPV( ST(1), len);
     CODE:
     RAND_seed (buf, (int)len);

void
RAND_cleanup()

int
RAND_load_file(file_name, how_much)
     char *  file_name
     int     how_much

int
RAND_write_file(file_name)
     char *  file_name

int
RAND_egd(path)
     char *  path

#define REM40 "Minimal X509 stuff..., this is a bit ugly and should be put in its own modules Net::SSLeay::X509.pm"

X509_NAME*
X509_get_issuer_name(cert)
     X509 *      cert

X509_NAME*
X509_get_subject_name(cert)
     X509 *      cert

void
X509_NAME_oneline(name)
	X509_NAME *    name
	PREINIT:
	char * buf;
	CODE:
	ST(0) = sv_newmortal();   /* Undefined to start with */
	if (buf = X509_NAME_oneline(name, NULL, 0))
		sv_setpvn( ST(0), buf, strlen(buf));
	OPENSSL_free(buf); /* mem was allocated by openssl */

void
X509_NAME_get_text_by_NID(name,nid)
	X509_NAME *    name
	int nid
	PREINIT:
	char* buf;
	int length;
	CODE:
	ST(0) = sv_newmortal();   /* Undefined to start with */
	length = X509_NAME_get_text_by_NID(name, nid, NULL, 0);

       if (length>=0) {				 
               New(0, buf, length+1, char);
               if (X509_NAME_get_text_by_NID(name, nid, buf, length + 1)>=0)
                       sv_setpvn( ST(0), buf, length);
               Safefree(buf);
       }

X509 *
X509_STORE_CTX_get_current_cert(x509_store_ctx)
     X509_STORE_CTX * 	x509_store_ctx

void *
X509_STORE_CTX_get_ex_data(x509_store_ctx,idx)
     X509_STORE_CTX * x509_store_ctx
     int idx

void
X509_get_fingerprint(cert,type)
		X509 * 	cert
		char *	type
	PREINIT:
		const EVP_MD *digest_tp = NULL;
		unsigned char digest[EVP_MAX_MD_SIZE];
		unsigned int dsz, k = 0;
		char text[EVP_MAX_MD_SIZE * 3 + 1];
	CODE:
		if (!k && !strcmp(type,"md5")) {
		 	k = 1; digest_tp = EVP_md5();
		}
		if (!k && !strcmp(type,"sha1")) {
			k = 1; digest_tp = EVP_sha1();
		}
#if OPENSSL_VERSION_NUMBER >= 0x0090800fL
#ifndef OPENSSL_NO_SHA256
		if (!k && !strcmp(type,"sha256")) {
			k = 1; digest_tp = EVP_sha256();
		}
#endif
#endif
		if (!k && !strcmp(type,"ripemd160")) {
			k = 1; digest_tp = EVP_ripemd160();
		}
		if (!k)	/* Default digest */
			digest_tp = EVP_sha1();
		if ( digest_tp == NULL ) {
			/* Out of memory */
			XSRETURN_UNDEF;
		}
		if (!X509_digest(cert, digest_tp, digest, &dsz)) {
			/* Out of memory */
			XSRETURN_UNDEF;
		}
		text[0] = '\0';
		for(k=0; k<dsz; k++) {
			sprintf(&text[strlen(text)], "%02X:", digest[k]);
		}
		text[strlen(text)-1] = '\0';
		ST(0) = sv_newmortal();   /* Undefined to start with */
		sv_setpvn( ST(0), text, strlen(text));

void
X509_get_subjectAltNames(cert)
	X509 *      cert
	PPCODE:
	int                    i, j, count = 0;
	X509_EXTENSION         *subjAltNameExt = NULL;
	STACK_OF(GENERAL_NAME) *subjAltNameDNs = NULL;
	GENERAL_NAME           *subjAltNameDN  = NULL;
	int                    num_gnames;
	if (  (i = X509_get_ext_by_NID(cert, NID_subject_alt_name, -1)) >= 0
		&& (subjAltNameExt = X509_get_ext(cert, i))
		&& (subjAltNameDNs = X509V3_EXT_d2i(subjAltNameExt)))
	{
		num_gnames = sk_GENERAL_NAME_num(subjAltNameDNs);
	
		for (j = 0; j < num_gnames; j++)
                {
		     subjAltNameDN = sk_GENERAL_NAME_value(subjAltNameDNs, j);

                     switch (subjAltNameDN->type)
                     {
                     case GEN_OTHERNAME:
                         EXTEND(SP, 2);
                         count++;
                         PUSHs(sv_2mortal(newSViv(subjAltNameDN->type)));
                         PUSHs(sv_2mortal(newSVpv((const char*)ASN1_STRING_data(subjAltNameDN->d.otherName->value->value.utf8string), ASN1_STRING_length(subjAltNameDN->d.otherName->value->value.utf8string))));
                         break;
                     
                     case GEN_EMAIL:
                     case GEN_DNS:
                     case GEN_URI:	
                         EXTEND(SP, 2);
                         count++;
                         PUSHs(sv_2mortal(newSViv(subjAltNameDN->type)));
                         PUSHs(sv_2mortal(newSVpv((const char*)ASN1_STRING_data(subjAltNameDN->d.ia5), ASN1_STRING_length(subjAltNameDN->d.ia5))));
                         break;

                     case GEN_DIRNAME:
                         {
                         char * buf = X509_NAME_oneline(subjAltNameDN->d.dirn, NULL, 0);
                         EXTEND(SP, 2);
                         count++;
                         PUSHs(sv_2mortal(newSViv(subjAltNameDN->type)));
                         PUSHs(sv_2mortal(newSVpv((buf), strlen((buf)))));
                         break;
                         }

                     case GEN_IPADD:
                         EXTEND(SP, 2);
                         count++;
                         PUSHs(sv_2mortal(newSViv(subjAltNameDN->type)));
                         PUSHs(sv_2mortal(newSVpv((const char*)subjAltNameDN->d.ip->data, subjAltNameDN->d.ip->length)));
                         break;
                        
                     }
		}
	}
	XSRETURN(count * 2);

int
X509_get_ext_by_NID(x,nid,loc)
	X509* x
	int nid
	int loc

X509_EXTENSION *
X509_get_ext(x,loc)
	X509* x
	int loc
	
void *
X509V3_EXT_d2i(ext)
	X509_EXTENSION *ext

int
X509_STORE_CTX_get_error(x509_store_ctx)
     X509_STORE_CTX * 	x509_store_ctx

int
X509_STORE_CTX_get_error_depth(x509_store_ctx)
     X509_STORE_CTX * 	x509_store_ctx

int
X509_STORE_CTX_set_ex_data(x509_store_ctx,idx,data)
     X509_STORE_CTX *   x509_store_ctx
     int idx
     void * data

void
X509_STORE_CTX_set_error(x509_store_ctx,s)
     X509_STORE_CTX * x509_store_ctx
     int s

void
X509_STORE_CTX_set_cert(x509_store_ctx,x)
     X509_STORE_CTX * x509_store_ctx
     X509 * x

int 
X509_STORE_add_cert(ctx, x)
    X509_STORE *ctx
    X509 *x

int 
X509_STORE_add_crl(ctx, x)
    X509_STORE *ctx
    X509_CRL *x

#if OPENSSL_VERSION_NUMBER >= 0x0090800fL

void 
X509_STORE_set_flags(ctx, flags)
    X509_STORE *ctx
    long flags

void 
X509_STORE_set_purpose(ctx, purpose)
    X509_STORE *ctx
    int purpose

void 
X509_STORE_set_trust(ctx, trust)
    X509_STORE *ctx
    int trust

int 
X509_STORE_set1_param(ctx, pm)
    X509_STORE *ctx
    X509_VERIFY_PARAM *pm

#endif

int 
X509_load_cert_file(ctx, file, type)
    X509_LOOKUP *ctx
    char *file
    int type

int 
X509_load_crl_file(ctx, file, type)
    X509_LOOKUP *ctx
    char *file
    int type

int 
X509_load_cert_crl_file(ctx, file, type)
    X509_LOOKUP *ctx
    char *file
    int type

const char *
X509_verify_cert_error_string(n)
    long n   


ASN1_UTCTIME *
X509_get_notBefore(cert)
     X509 *	cert

ASN1_UTCTIME *
X509_get_notAfter(cert)
     X509 *	cert

void 
P_ASN1_UTCTIME_put2string(tm)
     ASN1_UTCTIME *	tm
     PREINIT:
     BIO *bp;
     int i;
     char buffer[256];
     CODE:
     bp = BIO_new(BIO_s_mem());
     ASN1_UTCTIME_print(bp,tm);
     i = BIO_read(bp,buffer,255);
     buffer[i] = '\0';
     ST(0) = sv_newmortal();   /* Undefined to start with */
     if ( i > 0 )
         sv_setpvn( ST(0), buffer, i );
     BIO_free(bp);

int
EVP_PKEY_copy_parameters(to,from)
     EVP_PKEY *		to
     EVP_PKEY * 	from

void 
PEM_get_string_X509(x509)
     X509 *	x509
     PREINIT:
     BIO *bp;
     int i;
     char buffer[8196];
     CODE:
     bp = BIO_new(BIO_s_mem());
     PEM_write_bio_X509(bp,x509);
     i = BIO_read(bp,buffer,8195);
     buffer[i] = '\0';
     ST(0) = sv_newmortal();   /* Undefined to start with */
     if ( i > 0 )
         sv_setpvn( ST(0), buffer, i );
     BIO_free(bp);

int
CTX_use_PKCS12_file(ctx, file, password)
    SSL_CTX *          ctx
    char *             file
    char *             password
    PREINIT:
    BIO *bio;
    int i;
    int count;
    char buffer[16384];
    PKCS12 *p12;
    EVP_PKEY* private_key;
    X509* certificate;
    SSL_CTX *          ctx1;
    CODE:
    RETVAL = 1;

    FILE *fp = fopen (file, "r");   
    bio = BIO_new(BIO_s_mem());
    while(count = fread(buffer, 1, sizeof(buffer), fp))
	BIO_write(bio, buffer, count);
    fclose(fp);

    OPENSSL_add_all_algorithms_noconf();
    p12 = d2i_PKCS12_bio(bio, NULL);
    if (!p12)
    	RETVAL = 0;
    BIO_free(bio);
    if (RETVAL && !PKCS12_parse(p12, password, &private_key, &certificate, NULL))
    	RETVAL = 0;
    PKCS12_free(p12);
    if (RETVAL && !SSL_CTX_use_PrivateKey(ctx, private_key))
    	RETVAL = 0;
    if (RETVAL && !SSL_CTX_use_certificate(ctx, certificate))
    	RETVAL = 0;
    if (!RETVAL)
        ERR_print_errors_fp(stderr);
    OUTPUT:
    RETVAL

#ifndef OPENSSL_NO_MD2

void
MD2(data)
	PREINIT:
	STRLEN len;
	unsigned char md[MD2_DIGEST_LENGTH];
	unsigned char * ret;
	INPUT:
	unsigned char* data = (unsigned char *) SvPV( ST(0), len);
	CODE:
	ret = MD2(data,len,md);
	if (ret!=NULL) {
		XSRETURN_PVN((char *) md, MD2_DIGEST_LENGTH);
	} else {
		XSRETURN_UNDEF;
	}

#endif

void
MD4(data)
	PREINIT:
	STRLEN len;
	unsigned char md[MD4_DIGEST_LENGTH];
	unsigned char * ret;
	INPUT:
	unsigned char* data = (unsigned char *) SvPV( ST(0), len );
	CODE:
	ret = MD4(data,len,md);
	if (ret!=NULL) {
		XSRETURN_PVN((char *) md, MD4_DIGEST_LENGTH);
	} else {
		XSRETURN_UNDEF;
	}

void 
MD5(data)
     PREINIT:
     STRLEN len;
     unsigned char md[MD5_DIGEST_LENGTH];
     unsigned char * ret;
     INPUT:
     unsigned char *  data = (unsigned char *) SvPV( ST(0), len);
     CODE:
     ret = MD5(data,len,md);
     if (ret!=NULL) {
	  XSRETURN_PVN((char *) md, MD5_DIGEST_LENGTH);
     } else {
	  XSRETURN_UNDEF;
     }

#if OPENSSL_VERSION_NUMBER >= 0x00905000L

void 
RIPEMD160(data)
     PREINIT:
     STRLEN len;
     unsigned char md[RIPEMD160_DIGEST_LENGTH];
     unsigned char * ret;
     INPUT:
     unsigned char *  data = (unsigned char *) SvPV( ST(0), len);
     CODE:
     ret = RIPEMD160(data,len,md);
     if (ret!=NULL) {
	  XSRETURN_PVN((char *) md, RIPEMD160_DIGEST_LENGTH);
     } else {
	  XSRETURN_UNDEF;
     }

#endif

#ifndef OPENSSL_NO_SSL2 
#if OPENSSL_VERSION_NUMBER < 0x10000000L

SSL_METHOD *
SSLv2_method()

#endif
#endif

SSL_METHOD *
SSLv3_method()

SSL_METHOD *
TLSv1_method()

int
SSL_set_ssl_method(ssl, method)
     SSL *          ssl
     SSL_METHOD *   method

SSL_METHOD *
SSL_get_ssl_method(ssl)
     SSL *          ssl

#define REM_AUTOMATICALLY_GENERATED_1_09

BIO *
BIO_new_buffer_ssl_connect(ctx)
     SSL_CTX *	ctx

BIO *
BIO_new_file(filename,mode)
     char * filename
     char * mode

BIO *
BIO_new_ssl(ctx,client)
     SSL_CTX *	ctx
     int 	client

BIO *
BIO_new_ssl_connect(ctx)
     SSL_CTX *	ctx

BIO *
BIO_new(type)
     BIO_METHOD * type;

int
BIO_free(bio)
     BIO * bio;

void
BIO_read(s,max=32768)
	BIO *   s
	int max
	PREINIT:
	char *buf = NULL;
	int got;
	CODE:
	New(0, buf, max, char);
	ST(0) = sv_newmortal();   /* Undefined to start with */
	if ((got = BIO_read(s, buf, max)) >= 0)
		sv_setpvn( ST(0), buf, got);
	Safefree(buf);

int
BIO_write(s,buf)
     BIO *   s
     PREINIT:
     STRLEN len;
     INPUT:
     char *  buf = SvPV( ST(1), len);
     CODE:
     RETVAL = BIO_write (s, buf, (int)len);
     OUTPUT:
     RETVAL

int
BIO_eof(s)
     BIO *   s

int
BIO_pending(s)
     BIO *   s

int
BIO_wpending(s)
     BIO *   s

int 
BIO_ssl_copy_session_id(to,from)
     BIO *	to
     BIO *	from

void 
BIO_ssl_shutdown(ssl_bio)
     BIO *	ssl_bio

int 
SSL_add_client_CA(ssl,x)
     SSL *	ssl
     X509 *	x

const char *
SSL_alert_desc_string(value)
     int 	value

const char *
SSL_alert_desc_string_long(value)
     int 	value

const char *
SSL_alert_type_string(value)
     int 	value

const char *
SSL_alert_type_string_long(value)
     int 	value

long	
SSL_callback_ctrl(ssl,i,fp)
     SSL *  ssl
     int    i
     callback_no_ret * fp

int 
SSL_check_private_key(ctx)
     SSL *	ctx

char *
SSL_CIPHER_description(cipher,buf,size)
     SSL_CIPHER *  cipher
     char *	buf
     int 	size

int	
SSL_CIPHER_get_bits(c,alg_bits)
     SSL_CIPHER *	c
     int *	alg_bits

int 
SSL_COMP_add_compression_method(id,cm)
     int 	id
     COMP_METHOD *	cm

int 
SSL_CTX_add_client_CA(ctx,x)
     SSL_CTX *	ctx
     X509 *	x

long	
SSL_CTX_callback_ctrl(ctx,i,fp)
     SSL_CTX *  ctx
     int        i
     callback_no_ret * fp

int 
SSL_CTX_check_private_key(ctx)
     SSL_CTX *	ctx

void *
SSL_CTX_get_ex_data(ssl,idx)
     SSL_CTX *	ssl
     int 	idx

int 
SSL_CTX_get_quiet_shutdown(ctx)
     SSL_CTX *	ctx

long 
SSL_CTX_get_timeout(ctx)
     SSL_CTX *	ctx

int 
SSL_CTX_get_verify_depth(ctx)
     SSL_CTX *	ctx

int 
SSL_CTX_get_verify_mode(ctx)
     SSL_CTX *	ctx

void 
SSL_CTX_set_cert_store(ctx,store)
     SSL_CTX *     ctx
     X509_STORE *  store

X509_STORE *
SSL_CTX_get_cert_store(ctx)
     SSL_CTX *     ctx

void 
SSL_CTX_set_cert_verify_callback(ctx,func,data=NULL)
	SSL_CTX* ctx
	SV* func
	SV*	data
	PREINIT:
	ssleay_ctx_cert_verify_cb_t* cb;
	CODE:
	if (func == NULL || func == &PL_sv_undef) {
		ssleay_ctx_cert_verify_cb_free(ctx);
		SSL_CTX_set_cert_verify_callback(ctx, NULL, NULL);
	} else {
		cb = ssleay_ctx_cert_verify_cb_new(ctx, func, data);
		SSL_CTX_set_cert_verify_callback(ctx, ssleay_ctx_cert_verify_cb_invoke, cb);
	}

X509_NAME_STACK *
SSL_CTX_get_client_CA_list(ctx)
	SSL_CTX *ctx

void 
SSL_CTX_set_client_CA_list(ctx,list)
     SSL_CTX *	ctx
     X509_NAME_STACK * list

void 
SSL_CTX_set_default_passwd_cb(ctx,func=NULL)
	SSL_CTX *	ctx
	SV * func
	PREINIT:
	ssleay_ctx_passwd_cb_t* cb;
	CODE:
	if (func == NULL || func == &PL_sv_undef) {
		ssleay_ctx_passwd_cb_free_func(ctx);
		SSL_CTX_set_default_passwd_cb(ctx, NULL);
	} else {
		cb = ssleay_ctx_passwd_cb_get(ctx);
		ssleay_ctx_passwd_cb_func_set(ctx, func);
		SSL_CTX_set_default_passwd_cb(ctx, &ssleay_ctx_passwd_cb_invoke);
		SSL_CTX_set_default_passwd_cb_userdata(ctx, (void*)cb);
	}

void 
SSL_CTX_set_default_passwd_cb_userdata(ctx,u=NULL)
	SSL_CTX *	ctx
	SV*	u
	CODE:
	if (u == NULL) {
		ssleay_ctx_passwd_cb_free_userdata(ctx);
	} else {
		ssleay_ctx_passwd_cb_userdata_set(ctx, u);
	}

int 
SSL_CTX_set_ex_data(ssl,idx,data)
     SSL_CTX *	ssl
     int 	idx
     void *	data

int 
SSL_CTX_set_purpose(s,purpose)
     SSL_CTX *	s
     int 	purpose

void 
SSL_CTX_set_quiet_shutdown(ctx,mode)
     SSL_CTX *	ctx
     int 	mode

int 
SSL_CTX_set_ssl_version(ctx,meth)
     SSL_CTX *	ctx
     SSL_METHOD *	meth

long 
SSL_CTX_set_timeout(ctx,t)
     SSL_CTX *	ctx
     long 	t

int 
SSL_CTX_set_trust(s,trust)
     SSL_CTX *	s
     int 	trust

void 
SSL_CTX_set_verify_depth(ctx,depth)
     SSL_CTX *	ctx
     int 	depth

int 
SSL_CTX_use_certificate(ctx,x)
     SSL_CTX *	ctx
     X509 *	x

int	
SSL_CTX_use_certificate_chain_file(ctx,file)
     SSL_CTX *	ctx
     const char * file

int 
SSL_CTX_use_PrivateKey(ctx,pkey)
     SSL_CTX *	ctx
     EVP_PKEY *	pkey

int 
SSL_CTX_use_RSAPrivateKey(ctx,rsa)
     SSL_CTX *	ctx
     RSA *	rsa

int 
SSL_do_handshake(s)
     SSL *	s

SSL *
SSL_dup(ssl)
     SSL *	ssl

SSL_CIPHER *
SSL_get_current_cipher(s)
     SSL *	s

long 
SSL_get_default_timeout(s)
     SSL *	s

void *
SSL_get_ex_data(ssl,idx)
     SSL *	ssl
     int 	idx

size_t 
SSL_get_finished(s,buf,count)
     SSL *	s
     void *	buf
     size_t 	count

size_t 
SSL_get_peer_finished(s,buf,count)
     SSL *	s
     void *	buf
     size_t 	count

int 
SSL_get_quiet_shutdown(ssl)
     SSL *	ssl

int 
SSL_get_shutdown(ssl)
     SSL *	ssl

int	
SSL_get_verify_depth(s)
     SSL *	s

int	
SSL_get_verify_mode(s)
     SSL *	s

long 
SSL_get_verify_result(ssl)
     SSL *	ssl

int 
SSL_renegotiate(s)
     SSL *	s

#if OPENSSL_VERSION_NUMBER < 0x10000000L

int	
SSL_SESSION_cmp(a,b)
     SSL_SESSION *	a
     SSL_SESSION *	b

#endif

void *
SSL_SESSION_get_ex_data(ss,idx)
     SSL_SESSION *	ss
     int 	idx

long	
SSL_SESSION_get_time(s)
     SSL_SESSION *	s

long	
SSL_SESSION_get_timeout(s)
     SSL_SESSION *	s

int	
SSL_SESSION_print_fp(fp,ses)
     FILE *	fp
     SSL_SESSION *	ses

int 
SSL_SESSION_set_ex_data(ss,idx,data)
     SSL_SESSION *	ss
     int 	idx
     void *	data

long	
SSL_SESSION_set_time(s,t)
     SSL_SESSION *	s
     long 	t

long	
SSL_SESSION_set_timeout(s,t)
     SSL_SESSION *	s
     long 	t

void 
SSL_set_accept_state(s)
     SSL *	s

void
sk_X509_NAME_free(sk)
	X509_NAME_STACK *sk

int
sk_X509_NAME_num(sk)
	X509_NAME_STACK *sk

X509_NAME *
sk_X509_NAME_value(sk,i)
	X509_NAME_STACK *sk
	int i

X509_NAME_STACK *
SSL_get_client_CA_list(s)
	SSL *	s

void 
SSL_set_client_CA_list(s,list)
     SSL *	s
     X509_NAME_STACK *  list

void 
SSL_set_connect_state(s)
     SSL *	s

int 
SSL_set_ex_data(ssl,idx,data)
     SSL *	ssl
     int 	idx
     void *	data

void 
SSL_set_info_callback(ssl,cb)
     SSL *	ssl
     cb_ssl_int_int_ret_void *  cb

int 
SSL_set_purpose(s,purpose)
     SSL *	s
     int 	purpose

void 
SSL_set_quiet_shutdown(ssl,mode)
     SSL *	ssl
     int 	mode

void 
SSL_set_shutdown(ssl,mode)
     SSL *	ssl
     int 	mode

int 
SSL_set_trust(s,trust)
     SSL *	s
     int 	trust

void
SSL_set_verify_depth(s,depth)
     SSL *	s
     int 	depth

void 
SSL_set_verify_result(ssl,v)
     SSL *	ssl
     long 	v

int 
SSL_shutdown(s)
     SSL *	s

int 
SSL_version(ssl)
     SSL *	ssl

#define REM_MANUALLY_ADDED_1_09

X509_NAME_STACK *
SSL_load_client_CA_file(file)
     const char * file

int	
SSL_add_file_cert_subjects_to_stack(stackCAs,file)
     X509_NAME_STACK * stackCAs
     const char * file

#ifndef WIN32
#ifndef VMS
#ifndef MAC_OS_pre_X

int
SSL_add_dir_cert_subjects_to_stack(stackCAs,dir)
     X509_NAME_STACK * stackCAs
     const char * dir

#endif
#endif
#endif

int
SSL_CTX_get_ex_new_index(argl,argp,new_func,dup_func,free_func)
     long argl
     void *  argp
     CRYPTO_EX_new *   new_func
     CRYPTO_EX_dup *   dup_func
     CRYPTO_EX_free *  free_func

int
SSL_CTX_set_session_id_context(ctx,sid_ctx,sid_ctx_len)
     SSL_CTX *   ctx
     const unsigned char *   sid_ctx
     unsigned int sid_ctx_len

int
SSL_set_session_id_context(ssl,sid_ctx,sid_ctx_len)
     SSL *   ssl
     const unsigned char *   sid_ctx
     unsigned int sid_ctx_len

void
SSL_CTX_set_tmp_rsa_callback(ctx, cb)
     SSL_CTX *   ctx
     cb_ssl_int_int_ret_RSA *   cb

void
SSL_set_tmp_rsa_callback(ssl, cb)
     SSL *   ssl
     cb_ssl_int_int_ret_RSA *  cb

void
SSL_CTX_set_tmp_dh_callback(ctx, dh)
     SSL_CTX *   ctx
     cb_ssl_int_int_ret_DH *  dh

void
SSL_set_tmp_dh_callback(ssl,dh)
     SSL *  ssl
     cb_ssl_int_int_ret_DH *  dh

int
SSL_get_ex_new_index(argl, argp, new_func, dup_func, free_func)
     long argl
     void *   argp
     CRYPTO_EX_new *  new_func
     CRYPTO_EX_dup *  dup_func
     CRYPTO_EX_free * free_func

int
SSL_SESSION_get_ex_new_index(argl, argp, new_func, dup_func, free_func)
     long argl
     void *   argp
     CRYPTO_EX_new *  new_func
     CRYPTO_EX_dup *  dup_func
     CRYPTO_EX_free * free_func

#define REM_SEMIAUTOMATIC_MACRO_GEN_1_09

long
SSL_clear_num_renegotiations(ssl)
  SSL *  ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_CLEAR_NUM_RENEGOTIATIONS,0,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_add_extra_chain_cert(ctx,x509)
     SSL_CTX *	ctx
     X509 *     x509
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_EXTRA_CHAIN_CERT,0,(char*)x509);
  OUTPUT:
  RETVAL

void *
SSL_CTX_get_app_data(ctx)
     SSL_CTX *	ctx
  CODE:
  RETVAL = SSL_CTX_get_ex_data(ctx,0);
  OUTPUT:
  RETVAL

long	
SSL_CTX_get_mode(ctx)
     SSL_CTX *	ctx
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_MODE,0,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_get_read_ahead(ctx)
     SSL_CTX *	ctx
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_GET_READ_AHEAD,0,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_get_session_cache_mode(ctx)
     SSL_CTX *	ctx
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_GET_SESS_CACHE_MODE,0,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_need_tmp_RSA(ctx)
     SSL_CTX *	ctx
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_NEED_TMP_RSA,0,NULL);
  OUTPUT:
  RETVAL

int 
SSL_CTX_set_app_data(ctx,arg)
     SSL_CTX *	ctx
     char *	arg
  CODE:
  RETVAL = SSL_CTX_set_ex_data(ctx,0,arg);
  OUTPUT:
  RETVAL

long	
SSL_CTX_set_mode(ctx,op)
     SSL_CTX *	ctx
     long 	op
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_MODE,op,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_set_read_ahead(ctx,m)
     SSL_CTX *	ctx
     long 	m
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_SET_READ_AHEAD,m,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_set_session_cache_mode(ctx,m)
     SSL_CTX *	ctx
     long 	m
  CODE:
  RETVAL = SSL_CTX_ctrl(ctx,SSL_CTRL_SET_SESS_CACHE_MODE,m,NULL);
  OUTPUT:
  RETVAL

long	
SSL_CTX_set_tmp_dh(ctx,dh)
     SSL_CTX *	ctx
     DH *	dh

long	
SSL_CTX_set_tmp_rsa(ctx,rsa)
     SSL_CTX *	ctx
     RSA *	rsa

void *
SSL_get_app_data(s)
     SSL *	s
  CODE:
  RETVAL = SSL_get_ex_data(s,0);
  OUTPUT:
  RETVAL

int	
SSL_get_cipher_bits(s,np)
     SSL *	s
     int *	np
  CODE:
  RETVAL = SSL_CIPHER_get_bits(SSL_get_current_cipher(s),np);
  OUTPUT:
  RETVAL

long	
SSL_get_mode(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_MODE,0,NULL);
  OUTPUT:
  RETVAL

int 
SSL_get_state(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_state(ssl);
  OUTPUT:
  RETVAL

long	
SSL_need_tmp_RSA(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_NEED_TMP_RSA,0,NULL);
  OUTPUT:
  RETVAL

long	
SSL_num_renegotiations(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_GET_NUM_RENEGOTIATIONS,0,NULL);
  OUTPUT:
  RETVAL

void *
SSL_SESSION_get_app_data(ses)
     SSL_SESSION *	ses
  CODE:
  RETVAL = SSL_SESSION_get_ex_data(ses,0);
  OUTPUT:
  RETVAL

long	
SSL_session_reused(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_GET_SESSION_REUSED,0,NULL);
  OUTPUT:
  RETVAL

int 
SSL_SESSION_set_app_data(s,a)
     SSL_SESSION *	s
     void *	a
  CODE:
  RETVAL = SSL_SESSION_set_ex_data(s,0,(char *)a);
  OUTPUT:
  RETVAL

int 
SSL_set_app_data(s,arg)
     SSL *	s
     void *	arg
  CODE:
  RETVAL = SSL_set_ex_data(s,0,(char *)arg);
  OUTPUT:
  RETVAL

long	
SSL_set_mode(ssl,op)
     SSL *	ssl
     long 	op
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_MODE,op,NULL);
  OUTPUT:
  RETVAL

int	
SSL_set_pref_cipher(s,n)
     SSL *	s
     const char * n
  CODE:
  RETVAL = SSL_set_cipher_list(s,n);
  OUTPUT:
  RETVAL

long	
SSL_set_tmp_dh(ssl,dh)
     SSL *	ssl
     DH *	dh

long	
SSL_set_tmp_rsa(ssl,rsa)
     SSL *	ssl
     char *	rsa
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_SET_TMP_RSA,0,(char *)rsa);
  OUTPUT:
  RETVAL

RSA *
RSA_generate_key(bits,e,perl_cb=NULL,perl_cb_arg=NULL)
		int bits
		unsigned long e
		SV* perl_cb
		SV* perl_cb_arg
	PREINIT:
		ssleay_RSA_generate_key_cb_t* cb = NULL;
	CODE:
		cb = ssleay_RSA_generate_key_cb_new(perl_cb, perl_cb_arg);
		RETVAL = RSA_generate_key(bits, e, ssleay_RSA_generate_key_cb_invoke, cb);
		ssleay_RSA_generate_key_cb_free(cb);
	OUTPUT:
		RETVAL

void
RSA_free(r)
    RSA * r

void
X509_free(a)
    X509 * a

DH *
PEM_read_bio_DHparams(bio,x=NULL,cb=NULL,u=NULL)
	BIO  * bio
	void * x
	pem_password_cb * cb
	void * u

X509_CRL *
PEM_read_bio_X509_CRL(bio,x=NULL,cb=NULL,u=NULL)
	BIO  * bio
	void * x
	pem_password_cb * cb
	void * u

void
DH_free(dh)
	DH * dh

long
SSL_total_renegotiations(ssl)
     SSL *	ssl
  CODE:
  RETVAL = SSL_ctrl(ssl,SSL_CTRL_GET_TOTAL_RENEGOTIATIONS,0,NULL);
  OUTPUT:
  RETVAL

void
SSL_SESSION_get_master_key(s)
     SSL_SESSION *   s
     CODE:
     ST(0) = sv_newmortal();   /* Undefined to start with */
     sv_setpvn(ST(0), (const char*)s->master_key, s->master_key_length);

void
SSL_SESSION_set_master_key(s,key)
     SSL_SESSION *   s
     PREINIT:
     STRLEN len;
     INPUT:
     char * key = SvPV(ST(1), len);
     CODE:
     memcpy(s->master_key, key, len);
     s->master_key_length = len;

void
SSL_get_client_random(s)
     SSL *   s
     CODE:
     ST(0) = sv_newmortal();   /* Undefined to start with */
     sv_setpvn(ST(0), (const char*)s->s3->client_random, SSL3_RANDOM_SIZE);

void
SSL_get_server_random(s)
     SSL *   s
     CODE:
     ST(0) = sv_newmortal();   /* Undefined to start with */
     sv_setpvn(ST(0), (const char*)s->s3->server_random, SSL3_RANDOM_SIZE);

int
SSL_get_keyblock_size(s)
     SSL *   s	
     CODE:
     if (s == NULL ||
	 s->enc_read_ctx == NULL ||
	 s->enc_read_ctx->cipher == NULL ||
	 s->read_hash == NULL)
     {
	RETVAL = -1;
     }
     else
     {
	const EVP_CIPHER *c;
	const EVP_MD *h;
	c = s->enc_read_ctx->cipher;
#if OPENSSL_VERSION_NUMBER >= 0x00909000L
	h = EVP_MD_CTX_md(s->read_hash);
#else
	h = s->read_hash;
#endif

	RETVAL = 2 * (EVP_CIPHER_key_length(c) +
		    EVP_MD_size(h) +
		    EVP_CIPHER_iv_length(c));
     }
     OUTPUT:
     RETVAL



#if defined(SSL_F_SSL_SET_HELLO_EXTENSION)
int
SSL_set_hello_extension(s, type, data)
     SSL *   s
     int     type
     PREINIT:
     STRLEN len;
     INPUT:
     char *  data = SvPV( ST(2), len);
     CODE:
     RETVAL = SSL_set_hello_extension(s, type, data, len);
     OUTPUT:
     RETVAL

#endif

#if defined(SSL_F_SSL_SET_HELLO_EXTENSION) || defined(SSL_F_SSL_SET_SESSION_TICKET_EXT)

void 
SSL_set_session_secret_cb(s,func,data=NULL)
	SSL * s
	SV* func
	SV*	data
	PREINIT:
	ssleay_session_secret_cb_t* cb;
	CODE:
	if (func == NULL || func == &PL_sv_undef) {
		ssleay_session_secret_cb_free(s);
		SSL_set_session_secret_cb(s, NULL, NULL);
	} else {
		cb = ssleay_session_secret_cb_new(s, func, data);
		SSL_set_session_secret_cb(s, (int (*)(SSL *s, void *secret, int *secret_len,
			   STACK_OF(SSL_CIPHER) *peer_ciphers,
			   SSL_CIPHER **cipher, void *arg))&ssleay_session_secret_cb_invoke, cb);
	}

#endif

int EVP_add_digest(const EVP_MD *digest)

#if OPENSSL_VERSION_NUMBER >= 0x0090800fL

#ifndef OPENSSL_NO_SHA256

const EVP_MD *EVP_sha256()

#endif

#endif

#if OPENSSL_VERSION_NUMBER >= 0x10000000L

int
SSL_CTX_set1_param(ctx, vpm)
     SSL_CTX *          ctx
     X509_VERIFY_PARAM *vpm

int
SSL_set1_param(ctx, vpm)
     SSL *          ctx
     X509_VERIFY_PARAM *vpm

#endif

#if OPENSSL_VERSION_NUMBER >= 0x0090800fL

X509_VERIFY_PARAM *
X509_VERIFY_PARAM_new()

void 
X509_VERIFY_PARAM_free(param)
     X509_VERIFY_PARAM *param

int
X509_VERIFY_PARAM_inherit(to, from)
     X509_VERIFY_PARAM *to
     X509_VERIFY_PARAM *from

int
X509_VERIFY_PARAM_set1(to, from)
     X509_VERIFY_PARAM *to
     X509_VERIFY_PARAM *from

int
X509_VERIFY_PARAM_set1_name(param, name)
     X509_VERIFY_PARAM *param
     const char *name

int 
X509_VERIFY_PARAM_set_flags(param, flags)
    X509_VERIFY_PARAM *param
    unsigned long flags

int 
X509_VERIFY_PARAM_clear_flags(param, flags)
    X509_VERIFY_PARAM *param
    unsigned long flags

unsigned long 
X509_VERIFY_PARAM_get_flags(param)
     X509_VERIFY_PARAM *param

int 
X509_VERIFY_PARAM_set_purpose(param, purpose)
    X509_VERIFY_PARAM *param
    int purpose

int 
X509_VERIFY_PARAM_set_trust(param, trust)
    X509_VERIFY_PARAM *param
    int trust

void 
X509_VERIFY_PARAM_set_depth(param, depth)
    X509_VERIFY_PARAM *param
    int depth

void 
X509_VERIFY_PARAM_set_time(param, t)
    X509_VERIFY_PARAM *param
    time_t t

int 
X509_VERIFY_PARAM_add0_policy(param, policy)
    X509_VERIFY_PARAM *param
    ASN1_OBJECT *policy

int 
X509_VERIFY_PARAM_set1_policies(param, policies)
    X509_VERIFY_PARAM *param
    STACK_OF(ASN1_OBJECT) *policies

int 
X509_VERIFY_PARAM_get_depth(param)
    X509_VERIFY_PARAM *param

int 
X509_VERIFY_PARAM_add0_table(param)
    X509_VERIFY_PARAM *param

X509_VERIFY_PARAM *
X509_VERIFY_PARAM_lookup(name)
    const char *name

void 
X509_VERIFY_PARAM_table_cleanup()

void 
X509_policy_tree_free(tree)
    X509_POLICY_TREE *tree

int 
X509_policy_tree_level_count(tree)
    X509_POLICY_TREE *tree

X509_POLICY_LEVEL *
X509_policy_tree_get0_level(tree, i)
    X509_POLICY_TREE *tree
    int i

STACK_OF(X509_POLICY_NODE) *
X509_policy_tree_get0_policies(tree)
    X509_POLICY_TREE *tree

STACK_OF(X509_POLICY_NODE) *
X509_policy_tree_get0_user_policies(tree)
    X509_POLICY_TREE *tree

int 
X509_policy_level_node_count(level)
    X509_POLICY_LEVEL *level

X509_POLICY_NODE *
X509_policy_level_get0_node(level, i)
    X509_POLICY_LEVEL *level
    int i

ASN1_OBJECT *
X509_policy_node_get0_policy(node)
    X509_POLICY_NODE *node

STACK_OF(POLICYQUALINFO) *
X509_policy_node_get0_qualifiers(node)
    X509_POLICY_NODE *node

X509_POLICY_NODE *
X509_policy_node_get0_parent(node)
    X509_POLICY_NODE *node

#endif

ASN1_OBJECT *	
OBJ_dup(o)
    ASN1_OBJECT *o

ASN1_OBJECT *	
OBJ_nid2obj(n)
    int n

const char *	
OBJ_nid2ln(n)
    int n

const char *	
OBJ_nid2sn(n)
    int n

int		
OBJ_obj2nid(o)
    ASN1_OBJECT *o

ASN1_OBJECT *	
OBJ_txt2obj(s, no_name)
    const char *s
    int no_name

void
OBJ_obj2txt(a, no_name)
    ASN1_OBJECT *a
    int no_name
    PREINIT:
	char buf[100];
	int  len;
    CODE:
    len = OBJ_obj2txt(buf, sizeof(buf), a, no_name);
    ST(0) = sv_newmortal();
    sv_setpvn(ST(0), buf, len);

int		
OBJ_txt2nid(s)
    const char *s

int		
OBJ_ln2nid(s)
    const char *s

int		
OBJ_sn2nid(s)
    const char *s

int		
OBJ_cmp(a, b)
    ASN1_OBJECT *a
    ASN1_OBJECT *b

#define REM_EOF "/* EOF - SSLeay.xs */"
