//
//  KMKCertificateHelper.m
//  Pods
//
//  Created by Christian Sampaio on 12/4/14.
//
//

@import Security;

#import "MQTTCertificateHelper.h"
#include <openssl/rsa.h>
#include <openssl/x509.h>
#include <openssl/pem.h>
#import <CommonCrypto/CommonDigest.h>

@implementation MQTTCertificateHelper

static NSString *kPublicKeyIdentifier = @"com.potsdam.publickey";
static NSString *kBaseKeyIdentifier = @"com.potsdam";

- (BOOL)generateKeyPairWithUserIdentifier:(NSString *)userId {
    
    NSMutableDictionary *privateKeyAttr = [NSMutableDictionary new];
    NSMutableDictionary *publicKeyAttr = [NSMutableDictionary new];
    NSMutableDictionary *keyPairAttr = [NSMutableDictionary new];
    
    NSString *formattedPrivateKeyIdentifier = [NSString stringWithFormat:@"%@.%@",kBaseKeyIdentifier,userId];
    
    NSData *publicTag = [NSData dataWithBytes:[kPublicKeyIdentifier cStringUsingEncoding:NSUTF8StringEncoding]
                                       length:strlen((const char *)[kPublicKeyIdentifier cStringUsingEncoding:NSUTF8StringEncoding])];
    NSData *privateTag = [NSData dataWithBytes:[formattedPrivateKeyIdentifier cStringUsingEncoding:NSUTF8StringEncoding]
                                        length:strlen((const char *)[formattedPrivateKeyIdentifier cStringUsingEncoding:NSUTF8StringEncoding])];
    SecKeyRef publicKey = NULL;
    SecKeyRef privateKey = NULL;
    
    keyPairAttr[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    keyPairAttr[(__bridge id)kSecAttrKeySizeInBits] = @(2048);
    
    privateKeyAttr[(__bridge id)kSecAttrIsPermanent] = @(YES);
    privateKeyAttr[(__bridge id)kSecAttrApplicationTag] = privateTag;
    
    publicKeyAttr[(__bridge id)kSecAttrIsPermanent] = @(YES);
    publicKeyAttr[(__bridge id)kSecAttrApplicationTag] = publicTag;
    
    keyPairAttr[(__bridge id)kSecPrivateKeyAttrs] = privateKeyAttr;
    keyPairAttr[(__bridge id)kSecPublicKeyAttrs] = publicKeyAttr;
    
    OSStatus status = SecKeyGeneratePair((__bridge CFDictionaryRef)keyPairAttr, &publicKey, &privateKey);
    
    if(publicKey) CFRelease(publicKey);
    if(privateKey) CFRelease(privateKey);
    
    BOOL success = (status != noErr);
    
    return success;
}

- (NSString *)retrieveCSRByUserId:(NSString *)userId installId:(NSString*)installId applicationId:(NSString *)applicationId {
    
    [self generateKeyPairWithUserIdentifier:userId];
    
    X509_REQ *x509_req = [self generateCSRWithUserId:userId appInstallId:installId applicationId:applicationId];
    NSString *path = [self createPemFileWithCertificateSigningRequest:x509_req andUserId:userId];
    NSString *csr = [self createPlainTextOfCertificateSigningRequest:path];
    
    return csr;
}

- (X509_REQ *)generateCSRWithUserId:(NSString *)userId appInstallId:(NSString *)appInstallId applicationId:(NSString *)applicationId {
    X509_REQ *req;
    X509_NAME *nm;
    EVP_PKEY *key;
    
    if ((req=X509_REQ_new()) == NULL) {
        return NULL;
    }
    
    NSString *formattedPrivateKeyIdentifier = [NSString stringWithFormat:@"%@.%@",kBaseKeyIdentifier,userId];
    
    nm = X509_REQ_get_subject_name(req);
    
    const unsigned char *user = (const unsigned char *) [[@"userId=" stringByAppendingString:userId] UTF8String];
    const unsigned char *appInstall = (const unsigned char *) [[@"installId=" stringByAppendingString:appInstallId] UTF8String];
    const unsigned char *applicationInstall = (const unsigned char *) [[@"applicationId=" stringByAppendingString:applicationId] UTF8String];
    
    X509_NAME_add_entry_by_txt(nm, "emailAddress", MBSTRING_ASC, (const unsigned char *) "movilechat@movile.com", -1, -1, 0);
    X509_NAME_add_entry_by_txt(nm, "O", MBSTRING_ASC, (const unsigned char *) "Movile Internet Movel S.A.", -1, -1, 0);
    X509_NAME_add_entry_by_txt(nm, "OU", MBSTRING_ASC, (const unsigned char *) "IT Products", -1, -1, 0);
    
    X509_NAME_add_entry_by_txt(nm, "CN", MBSTRING_ASC, user, -1, -1, 0);
    X509_NAME_add_entry_by_txt(nm, "CN", MBSTRING_ASC, appInstall, -1, -1, 0);
    X509_NAME_add_entry_by_txt(nm, "CN", MBSTRING_ASC, applicationInstall, -1, -1, 0);
    
    NSData *keyData = [self keyDataWithTag:kPublicKeyIdentifier];
    NSData *privateData = [self keyDataWithTag:formattedPrivateKeyIdentifier];
    
    const unsigned char *bits = (unsigned char *)[keyData bytes];
    NSInteger length = [keyData length];
    
    const unsigned char *pbits = (unsigned char *)[privateData bytes];
    NSInteger plength = [privateData length];
    
    RSA *rsa = NULL;
    
    key = EVP_PKEY_new();
    d2i_RSAPublicKey(&rsa, &bits, length);
    d2i_RSAPrivateKey(&rsa, &pbits, plength);
    EVP_PKEY_assign_RSA(key,rsa);
    
    X509_REQ_set_pubkey(req, key);
    
    X509_REQ_sign(req, key, EVP_sha512());
    
    // Log
    //X509_REQ_print_fp(stdout, req);
    
    return req;
}

- (NSString *)createPemFileWithCertificateSigningRequest:(X509_REQ *)certSigningRequest andUserId:(NSString *)userId {

    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *pemFilePath = [docDir stringByAppendingString:[NSString stringWithFormat:@"%@%@%@", @"/", userId, @".csr"]];
    if (![[NSFileManager defaultManager] createFileAtPath:pemFilePath contents:nil attributes:nil]) {
        return nil;
    }
    
    NSFileHandle *outputFileHandle = [NSFileHandle fileHandleForWritingAtPath:pemFilePath];
    FILE *pemFile = fdopen([outputFileHandle fileDescriptor], "w");
    
    PEM_write_X509_REQ(pemFile, certSigningRequest);
    
    fclose(pemFile);
    
    return pemFilePath;
}

- (NSString *)createPlainTextOfCertificateSigningRequest:(NSString *)csrPath {
    NSData *data = [[NSFileManager defaultManager] contentsAtPath:csrPath];
    NSString *aux = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    return [self csrFormatted:aux];
}

- (NSString *)csrFormatted:(NSString *)csr {
    //NSString *begin = @"-----BEGIN CERTIFICATE REQUEST-----";
    //NSString *end = @"-----END CERTIFICATE REQUEST-----";
    //NSString *lineBreak = @"\n";
    //csr = [csr stringByReplacingOccurrencesOfString:begin withString:@""];
    //csr = [csr stringByReplacingOccurrencesOfString:end withString:@""];
    //csr = [csr stringByReplacingOccurrencesOfString:lineBreak withString:@""];
    NSData *plainData = [csr dataUsingEncoding:NSUTF8StringEncoding];
    NSString *base64String = [plainData base64EncodedStringWithOptions:0];
    return base64String;
}

- (NSString *)PEMFormattedPrivateKey:(NSString *)tag {
    NSData *privateKeyData = [self keyDataWithTag:tag];
    
    NSMutableData * encodedKey = [[NSMutableData alloc] init];
    [encodedKey appendData:privateKeyData];
    NSString *result = [NSString stringWithFormat:@"%@\n%@\n%@",
                        @"-----BEGIN RSA PRIVATE KEY-----",
                        [encodedKey base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength],
                        @"-----END RSA PRIVATE KEY-----"];
    
    return result;
}

/**
 *  Remove old csr after usage.
 */

- (void)deleteOldCsrWithUserId:(NSString *)userId {
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *pemFilePath = [docDir stringByAppendingString:[NSString stringWithFormat:@"%@%@%@", @"/", userId, @".csr"]];

    NSError *error = nil;

    [[NSFileManager defaultManager] removeItemAtPath:pemFilePath error:&error];
}

/**
 *  Method for crt creation.
 *
 *  @param encodedCrt The encoded crt from server
 *
 *  @return the user.crt file path
 */
- (void)createUserCrtFile:(NSString *)encodedCrt andUserId:(NSString *)userId {
    
    [self deleteOldCsrWithUserId:userId];
    
    NSData *decodedData = [[NSData alloc] initWithBase64EncodedString:encodedCrt options:0];
    NSString *decodedCrt = [[NSString alloc] initWithData:decodedData encoding:NSUTF8StringEncoding];

    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [docDir stringByAppendingString:[NSString stringWithFormat:@"%@%@%@", @"/", userId, @".crt"]];
    if (![[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil]) {
    }
    NSError *error = nil;
    [decodedCrt writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    
}


+ (NSString *)retrieveCRTPathByUserID:(NSString *)userID {
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [docDir stringByAppendingString:[NSString stringWithFormat:@"%@%@%@", @"/", userID, @".crt"]];
    
    return filePath;
}

/**
 *  CA Creation *** The CA string is the same for all applications ***
 *
 *  @return return the ca Path
 */
+ (NSString *)retrieveCaPath {
    
    NSString *ca = @"-----BEGIN CERTIFICATE-----\n"
    "MIIDxTCCAq2gAwIBAgIJAJUzv/hET+VyMA0GCSqGSIb3DQEBDQUAMHkxIzAhBgNV\n"
    "BAoMGk1vdmlsZSBJbnRlcm5ldCBNb3ZlbCBTLkEuMRQwEgYDVQQLDAtJVCBQcm9k\n"
    "dWN0czEkMCIGCSqGSIb3DQEJARYVbW92aWxlY2hhdEBtb3ZpbGUuY29tMRYwFAYD\n"
    "VQQDDA1Nb3ZpbGVjaGF0IENBMB4XDTE1MDYyNDE0MzUxNFoXDTMyMDYxOTE0MzUx\n"
    "NFoweTEjMCEGA1UECgwaTW92aWxlIEludGVybmV0IE1vdmVsIFMuQS4xFDASBgNV\n"
    "BAsMC0lUIFByb2R1Y3RzMSQwIgYJKoZIhvcNAQkBFhVtb3ZpbGVjaGF0QG1vdmls\n"
    "ZS5jb20xFjAUBgNVBAMMDU1vdmlsZWNoYXQgQ0EwggEiMA0GCSqGSIb3DQEBAQUA\n"
    "A4IBDwAwggEKAoIBAQDTY2pkWLRqXoR9YkSDb++vKkfmEmCdl8YaxJ/qc0XoweIW\n"
    "FBOIa7ua5giudR8juQNAPk9q5jW4DQJu9a6bCYZz9+RaFxw8kU5kQnJrW+C+FilC\n"
    "FfwLlAKRD8oxHP7jHMPzT4rVUR4tISOiFq69vhByTqHdzdUbhn9zeOd13gHKD2AW\n"
    "SBmv6yo5P0qgDfsRG304RV3phixj0CkcGcrJQzGAutd4D/kXITZcA7ojOZkHQ+db\n"
    "RGEZ5SdH30i7jZLTP9XCzLjSl9c/zMrQl22sISqh5GiOKCYF0Kb6R7Ty/K86gGuu\n"
    "vgYDaDw77QA7hP3gzuUlzyJm0zQ9DFSCov19ic+9AgMBAAGjUDBOMB0GA1UdDgQW\n"
    "BBQ5biQ4lSe8HbW7lpAxJkzK93fzzjAfBgNVHSMEGDAWgBQ5biQ4lSe8HbW7lpAx\n"
    "JkzK93fzzjAMBgNVHRMEBTADAQH/MA0GCSqGSIb3DQEBDQUAA4IBAQCnGgaoCZnj\n"
    "pOtrbEuQkALalf5UEP+6bsj+JB1MZjWuxQq+OZLwRGIGZOC0njN08ajSy2OGZI1c\n"
    "TpHVlRcZV2XmjEfQuYsM4TKdFxXLG2BmZrHFkqe3G9yexw8ELrrY6dH9+m1hi+Ky\n"
    "CGfzYI03tU9Pz7/WlxzkupTC3M3oUHH/dX0qJDmJQiiQrL1ex3tWP6/DFVvT3ySO\n"
    "dTqs60X4y77ynmJrV9fYgXstX5hVTtHnLxFIiQGtzY1ZWMCtceVHPQDEfOAz4U7y\n"
    "VUGkzOZ/TYInjGh2290AedbVCW6hBA9nJBzYMaQknxspNjHIg5B6xnPlk3Cck0wG\n"
    "V0GWXaDzM3GH\n"
    "-----END CERTIFICATE-----";
    
    NSString *docDir = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    NSString *filePath = [docDir stringByAppendingString:@"/CA.crt"];
    if ([[NSFileManager defaultManager] createFileAtPath:filePath contents:nil attributes:nil]) {
        NSError *error = nil;
        [ca writeToFile:filePath atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
    
    return filePath;
}

- (NSData *)keyDataWithTag:(NSString *)tag {
    NSMutableDictionary *queryKey = [self keyQueryDictionary:tag];
    queryKey[(__bridge id)kSecReturnData] = @(YES);
    
    SecKeyRef key = NULL;
    OSStatus err = SecItemCopyMatching((__bridge CFDictionaryRef)queryKey, (CFTypeRef *)&key);
    
    NSData *keyData = err == noErr ? (__bridge NSData *)key : nil;
    
    return keyData;
}

- (NSMutableDictionary *)keyQueryDictionary:(NSString *)tag {
    NSData *keyTag = [tag dataUsingEncoding:NSUTF8StringEncoding];
    
    NSMutableDictionary *result = [NSMutableDictionary new];
    result[(__bridge id)kSecClass] = (__bridge id)kSecClassKey;
    result[(__bridge id)kSecAttrKeyType] = (__bridge id)kSecAttrKeyTypeRSA;
    result[(__bridge id)kSecAttrApplicationTag] = keyTag;
    result[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleWhenUnlocked;
    
    return result;
}

@end
