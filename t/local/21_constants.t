#!/usr/bin/perl

# DO NOT EDIT THIS FILE - update __DATA__ section of helper_script/regen_openssl_constants.pl

use strict;
use warnings;
use Net::SSLeay;

eval "use Test::Exception;";
if ($@)
{
    eval "use Test::More skip_all => 'Some tests need Test::Exception';";
}
else
{
    eval 'use Test::More tests => 426;';
}

my @c = (qw/
 ASN1_STRFLGS_ESC_CTRL           NID_dsa_2                              OP_ALLOW_UNSAFE_LEGACY_RENEGOTIATION
 ASN1_STRFLGS_ESC_MSB            NID_email_protect                      OP_CIPHER_SERVER_PREFERENCE
 ASN1_STRFLGS_ESC_QUOTE          NID_ext_key_usage                      OP_CISCO_ANYCONNECT
 ASN1_STRFLGS_RFC2253            NID_ext_req                            OP_COOKIE_EXCHANGE
 CB_ACCEPT_EXIT                  NID_friendlyName                       OP_CRYPTOPRO_TLSEXT_BUG
 CB_ACCEPT_LOOP                  NID_givenName                          OP_DONT_INSERT_EMPTY_FRAGMENTS
 CB_ALERT                        NID_hmacWithSHA1                       OP_EPHEMERAL_RSA
 CB_CONNECT_EXIT                 NID_id_ad                              OP_LEGACY_SERVER_CONNECT
 CB_CONNECT_LOOP                 NID_id_ce                              OP_MICROSOFT_BIG_SSLV3_BUFFER
 CB_EXIT                         NID_id_kp                              OP_MICROSOFT_SESS_ID_BUG
 CB_HANDSHAKE_DONE               NID_id_pbkdf2                          OP_MSIE_SSLV2_RSA_PADDING
 CB_HANDSHAKE_START              NID_id_pe                              OP_NETSCAPE_CA_DN_BUG
 CB_LOOP                         NID_id_pkix                            OP_NETSCAPE_CHALLENGE_BUG
 CB_READ                         NID_id_qt_cps                          OP_NETSCAPE_DEMO_CIPHER_CHANGE_BUG
 CB_READ_ALERT                   NID_id_qt_unotice                      OP_NETSCAPE_REUSE_CIPHER_CHANGE_BUG
 CB_WRITE                        NID_idea_cbc                           OP_NON_EXPORT_FIRST
 CB_WRITE_ALERT                  NID_idea_cfb64                         OP_NO_COMPRESSION
 ERROR_NONE                      NID_idea_ecb                           OP_NO_QUERY_MTU
 ERROR_SSL                       NID_idea_ofb64                         OP_NO_SESSION_RESUMPTION_ON_RENEGOTIATION
 ERROR_SYSCALL                   NID_info_access                        OP_NO_SSLv2
 ERROR_WANT_ACCEPT               NID_initials                           OP_NO_SSLv3
 ERROR_WANT_CONNECT              NID_invalidity_date                    OP_NO_TICKET
 ERROR_WANT_READ                 NID_issuer_alt_name                    OP_NO_TLSv1
 ERROR_WANT_WRITE                NID_keyBag                             OP_NO_TLSv1_1
 ERROR_WANT_X509_LOOKUP          NID_key_usage                          OP_NO_TLSv1_2
 ERROR_ZERO_RETURN               NID_localKeyID                         OP_PKCS1_CHECK_1
 EVP_PKS_DSA                     NID_localityName                       OP_PKCS1_CHECK_2
 EVP_PKS_EC                      NID_md2                                OP_SINGLE_DH_USE
 EVP_PKS_RSA                     NID_md2WithRSAEncryption               OP_SINGLE_ECDH_USE
 EVP_PKT_ENC                     NID_md5                                OP_SSLEAY_080_CLIENT_DH_BUG
 EVP_PKT_EXCH                    NID_md5WithRSA                         OP_SSLREF2_REUSE_CERT_TYPE_BUG
 EVP_PKT_EXP                     NID_md5WithRSAEncryption               OP_TLS_BLOCK_PADDING_BUG
 EVP_PKT_SIGN                    NID_md5_sha1                           OP_TLS_D5_BUG
 EVP_PK_DH                       NID_mdc2                               OP_TLS_ROLLBACK_BUG
 EVP_PK_DSA                      NID_mdc2WithRSA                        READING
 EVP_PK_EC                       NID_ms_code_com                        RECEIVED_SHUTDOWN
 EVP_PK_RSA                      NID_ms_code_ind                        RSA_3
 FILETYPE_ASN1                   NID_ms_ctl_sign                        RSA_F4
 FILETYPE_PEM                    NID_ms_efs                             R_BAD_AUTHENTICATION_TYPE
 F_CLIENT_CERTIFICATE            NID_ms_ext_req                         R_BAD_CHECKSUM
 F_CLIENT_HELLO                  NID_ms_sgc                             R_BAD_MAC_DECODE
 F_CLIENT_MASTER_KEY             NID_name                               R_BAD_RESPONSE_ARGUMENT
 F_D2I_SSL_SESSION               NID_netscape                           R_BAD_SSL_FILETYPE
 F_GET_CLIENT_FINISHED           NID_netscape_base_url                  R_BAD_SSL_SESSION_ID_LENGTH
 F_GET_CLIENT_HELLO              NID_netscape_ca_policy_url             R_BAD_STATE
 F_GET_CLIENT_MASTER_KEY         NID_netscape_ca_revocation_url         R_BAD_WRITE_RETRY
 F_GET_SERVER_FINISHED           NID_netscape_cert_extension            R_CHALLENGE_IS_DIFFERENT
 F_GET_SERVER_HELLO              NID_netscape_cert_sequence             R_CIPHER_TABLE_SRC_ERROR
 F_GET_SERVER_VERIFY             NID_netscape_cert_type                 R_INVALID_CHALLENGE_LENGTH
 F_I2D_SSL_SESSION               NID_netscape_comment                   R_NO_CERTIFICATE_SET
 F_READ_N                        NID_netscape_data_type                 R_NO_CERTIFICATE_SPECIFIED
 F_REQUEST_CERTIFICATE           NID_netscape_renewal_url               R_NO_CIPHER_LIST
 F_SERVER_HELLO                  NID_netscape_revocation_url            R_NO_CIPHER_MATCH
 F_SSL_CERT_NEW                  NID_netscape_ssl_server_name           R_NO_PRIVATEKEY
 F_SSL_GET_NEW_SESSION           NID_ns_sgc                             R_NO_PUBLICKEY
 F_SSL_NEW                       NID_organizationName                   R_NULL_SSL_CTX
 F_SSL_READ                      NID_organizationalUnitName             R_PEER_DID_NOT_RETURN_A_CERTIFICATE
 F_SSL_RSA_PRIVATE_DECRYPT       NID_pbeWithMD2AndDES_CBC               R_PEER_ERROR
 F_SSL_RSA_PUBLIC_ENCRYPT        NID_pbeWithMD2AndRC2_CBC               R_PEER_ERROR_CERTIFICATE
 F_SSL_SESSION_NEW               NID_pbeWithMD5AndCast5_CBC             R_PEER_ERROR_NO_CIPHER
 F_SSL_SESSION_PRINT_FP          NID_pbeWithMD5AndDES_CBC               R_PEER_ERROR_UNSUPPORTED_CERTIFICATE_TYPE
 F_SSL_SET_FD                    NID_pbeWithMD5AndRC2_CBC               R_PUBLIC_KEY_ENCRYPT_ERROR
 F_SSL_SET_RFD                   NID_pbeWithSHA1AndDES_CBC              R_PUBLIC_KEY_IS_NOT_RSA
 F_SSL_SET_WFD                   NID_pbeWithSHA1AndRC2_CBC              R_READ_WRONG_PACKET_TYPE
 F_SSL_USE_CERTIFICATE           NID_pbe_WithSHA1And128BitRC2_CBC       R_SHORT_READ
 F_SSL_USE_CERTIFICATE_ASN1      NID_pbe_WithSHA1And128BitRC4           R_SSL_SESSION_ID_IS_DIFFERENT
 F_SSL_USE_CERTIFICATE_FILE      NID_pbe_WithSHA1And2_Key_TripleDES_CBC R_UNABLE_TO_EXTRACT_PUBLIC_KEY
 F_SSL_USE_PRIVATEKEY            NID_pbe_WithSHA1And3_Key_TripleDES_CBC R_UNKNOWN_REMOTE_ERROR_TYPE
 F_SSL_USE_PRIVATEKEY_ASN1       NID_pbe_WithSHA1And40BitRC2_CBC        R_UNKNOWN_STATE
 F_SSL_USE_PRIVATEKEY_FILE       NID_pbe_WithSHA1And40BitRC4            R_X509_LIB
 F_SSL_USE_RSAPRIVATEKEY         NID_pbes2                              SENT_SHUTDOWN
 F_SSL_USE_RSAPRIVATEKEY_ASN1    NID_pbmac1                             SESSION_ASN1_VERSION
 F_SSL_USE_RSAPRIVATEKEY_FILE    NID_pkcs                               ST_ACCEPT
 F_WRITE_PENDING                 NID_pkcs3                              ST_BEFORE
 GEN_DIRNAME                     NID_pkcs7                              ST_CONNECT
 GEN_DNS                         NID_pkcs7_data                         ST_INIT
 GEN_EDIPARTY                    NID_pkcs7_digest                       ST_OK
 GEN_EMAIL                       NID_pkcs7_encrypted                    ST_READ_BODY
 GEN_IPADD                       NID_pkcs7_enveloped                    ST_READ_HEADER
 GEN_OTHERNAME                   NID_pkcs7_signed                       TLSEXT_STATUSTYPE_ocsp
 GEN_RID                         NID_pkcs7_signedAndEnveloped           VERIFY_CLIENT_ONCE
 GEN_URI                         NID_pkcs8ShroudedKeyBag                VERIFY_FAIL_IF_NO_PEER_CERT
 GEN_X400                        NID_pkcs9                              VERIFY_NONE
 LIBRESSL_VERSION_NUMBER         NID_pkcs9_challengePassword            VERIFY_PEER
 MBSTRING_ASC                    NID_pkcs9_contentType                  V_OCSP_CERTSTATUS_GOOD
 MBSTRING_BMP                    NID_pkcs9_countersignature             V_OCSP_CERTSTATUS_REVOKED
 MBSTRING_FLAG                   NID_pkcs9_emailAddress                 V_OCSP_CERTSTATUS_UNKNOWN
 MBSTRING_UNIV                   NID_pkcs9_extCertAttributes            WRITING
 MBSTRING_UTF8                   NID_pkcs9_messageDigest                X509_LOOKUP
 MIN_RSA_MODULUS_LENGTH_IN_BYTES NID_pkcs9_signingTime                  X509_PURPOSE_ANY
 MODE_ACCEPT_MOVING_WRITE_BUFFER NID_pkcs9_unstructuredAddress          X509_PURPOSE_CRL_SIGN
 MODE_AUTO_RETRY                 NID_pkcs9_unstructuredName             X509_PURPOSE_NS_SSL_SERVER
 MODE_ENABLE_PARTIAL_WRITE       NID_private_key_usage_period           X509_PURPOSE_OCSP_HELPER
 MODE_RELEASE_BUFFERS            NID_rc2_40_cbc                         X509_PURPOSE_SMIME_ENCRYPT
 NID_OCSP_sign                   NID_rc2_64_cbc                         X509_PURPOSE_SMIME_SIGN
 NID_SMIMECapabilities           NID_rc2_cbc                            X509_PURPOSE_SSL_CLIENT
 NID_X500                        NID_rc2_cfb64                          X509_PURPOSE_SSL_SERVER
 NID_X509                        NID_rc2_ecb                            X509_PURPOSE_TIMESTAMP_SIGN
 NID_ad_OCSP                     NID_rc2_ofb64                          X509_TRUST_COMPAT
 NID_ad_ca_issuers               NID_rc4                                X509_TRUST_EMAIL
 NID_algorithm                   NID_rc4_40                             X509_TRUST_OBJECT_SIGN
 NID_authority_key_identifier    NID_rc5_cbc                            X509_TRUST_OCSP_REQUEST
 NID_basic_constraints           NID_rc5_cfb64                          X509_TRUST_OCSP_SIGN
 NID_bf_cbc                      NID_rc5_ecb                            X509_TRUST_SSL_CLIENT
 NID_bf_cfb64                    NID_rc5_ofb64                          X509_TRUST_SSL_SERVER
 NID_bf_ecb                      NID_ripemd160                          X509_TRUST_TSA
 NID_bf_ofb64                    NID_ripemd160WithRSA                   X509_V_FLAG_ALLOW_PROXY_CERTS
 NID_cast5_cbc                   NID_rle_compression                    X509_V_FLAG_CB_ISSUER_CHECK
 NID_cast5_cfb64                 NID_rsa                                X509_V_FLAG_CHECK_SS_SIGNATURE
 NID_cast5_ecb                   NID_rsaEncryption                      X509_V_FLAG_CRL_CHECK
 NID_cast5_ofb64                 NID_rsadsi                             X509_V_FLAG_CRL_CHECK_ALL
 NID_certBag                     NID_safeContentsBag                    X509_V_FLAG_EXPLICIT_POLICY
 NID_certificate_policies        NID_sdsiCertificate                    X509_V_FLAG_EXTENDED_CRL_SUPPORT
 NID_client_auth                 NID_secretBag                          X509_V_FLAG_IGNORE_CRITICAL
 NID_code_sign                   NID_serialNumber                       X509_V_FLAG_INHIBIT_ANY
 NID_commonName                  NID_server_auth                        X509_V_FLAG_INHIBIT_MAP
 NID_countryName                 NID_sha                                X509_V_FLAG_NOTIFY_POLICY
 NID_crlBag                      NID_sha1                               X509_V_FLAG_POLICY_CHECK
 NID_crl_distribution_points     NID_sha1WithRSA                        X509_V_FLAG_POLICY_MASK
 NID_crl_number                  NID_sha1WithRSAEncryption              X509_V_FLAG_USE_CHECK_TIME
 NID_crl_reason                  NID_shaWithRSAEncryption               X509_V_FLAG_USE_DELTAS
 NID_delta_crl                   NID_stateOrProvinceName                X509_V_FLAG_X509_STRICT
 NID_des_cbc                     NID_subject_alt_name                   X509_V_OK
 NID_des_cfb64                   NID_subject_key_identifier             XN_FLAG_COMPAT
 NID_des_ecb                     NID_surname                            XN_FLAG_DN_REV
 NID_des_ede                     NID_sxnet                              XN_FLAG_DUMP_UNKNOWN_FIELDS
 NID_des_ede3                    NID_time_stamp                         XN_FLAG_FN_ALIGN
 NID_des_ede3_cbc                NID_title                              XN_FLAG_FN_LN
 NID_des_ede3_cfb64              NID_undef                              XN_FLAG_FN_MASK
 NID_des_ede3_ofb64              NID_uniqueIdentifier                   XN_FLAG_FN_NONE
 NID_des_ede_cbc                 NID_x509Certificate                    XN_FLAG_FN_OID
 NID_des_ede_cfb64               NID_x509Crl                            XN_FLAG_FN_SN
 NID_des_ede_ofb64               NID_zlib_compression                   XN_FLAG_MULTILINE
 NID_des_ofb64                   NOTHING                                XN_FLAG_ONELINE
 NID_description                 OCSP_RESPONSE_STATUS_INTERNALERROR     XN_FLAG_RFC2253
 NID_desx_cbc                    OCSP_RESPONSE_STATUS_MALFORMEDREQUEST  XN_FLAG_SEP_COMMA_PLUS
 NID_dhKeyAgreement              OCSP_RESPONSE_STATUS_SIGREQUIRED       XN_FLAG_SEP_CPLUS_SPC
 NID_dnQualifier                 OCSP_RESPONSE_STATUS_SUCCESSFUL        XN_FLAG_SEP_MASK
 NID_dsa                         OCSP_RESPONSE_STATUS_TRYLATER          XN_FLAG_SEP_MULTILINE
 NID_dsaWithSHA                  OCSP_RESPONSE_STATUS_UNAUTHORIZED      XN_FLAG_SEP_SPLUS_SPC
 NID_dsaWithSHA1                 OPENSSL_VERSION_NUMBER                 XN_FLAG_SPC_EQ
 NID_dsaWithSHA1_2               OP_ALL                                 

/);

my @missing;
my %h = map { $_=>1 } @Net::SSLeay::EXPORT_OK;

for (@c) {
  like(eval("&Net::SSLeay::$_; 'ok'") || $@, qr/^(ok|Your vendor has not defined SSLeay macro.*)$/, "$_");
  push(@missing, $_) unless $h{$_};
}

is(join(",", sort @missing), '', 'constants missing in @EXPORT_OK count='.scalar(@missing));

