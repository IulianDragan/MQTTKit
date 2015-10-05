//
//  KMKCertificateHelper.h
//  Pods
//
//  Created by Christian Sampaio on 12/4/14.
//

#import <Foundation/Foundation.h>

@interface MQTTCertificateHelper : NSObject

- (NSString *)retrieveCSRByUserId:(NSString *)userId installId:(NSString*)installId applicationId:(NSString *)applicationId;
- (void)createUserCrtFile:(NSString *)encodedCrt andUserId:(NSString *)userId;

+ (NSString *)retrieveCaPath;
+ (NSString *)retrieveCRTPathByUserID:(NSString *)userID;

@end
