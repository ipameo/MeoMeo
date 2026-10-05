//
//  MeoCore.h
//  MeoMeo Core Security & License Engine
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef void (^MeoAuthCompletion)(BOOL success, NSString * _Nullable error);
typedef void (^MeoStatusCompletion)(BOOL success);
typedef void (^MeoInjectCompletion)(BOOL success, NSString * _Nullable error);
typedef void (^MeoLiveStateCallback)(BOOL active);
typedef void (^MeoTokenRefreshCallback)(void);
typedef void (^MeoTerminatedCallback)(NSString *reason);

@interface MeoCore : NSObject

@property (nonatomic, readonly) BOOL isAuthed;
@property (nonatomic, copy, readonly, nullable) NSString *authError;
@property (nonatomic, copy, readonly) NSString *deviceId;
@property (nonatomic, copy) NSString *storedKey;
@property (nonatomic, copy, readonly) NSString *deviceExpires;
@property (nonatomic, readonly) BOOL systemActive;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSNumber *> *serverFeatures;

// Callbacks
@property (nonatomic, copy, nullable) MeoLiveStateCallback onLiveStateChanged;
@property (nonatomic, copy, nullable) MeoTokenRefreshCallback onTokenRefreshed;
@property (nonatomic, copy, nullable) MeoTerminatedCallback onLicenseTerminated;

+ (instancetype)shared;

// Anti-tamper & Security checks
+ (BOOL)isDebuggerAttached;
+ (BOOL)isHooked;

// Authentication
- (void)authenticateWithKey:(NSString *)key completion:(MeoAuthCompletion)completion;

// Heartbeat
- (void)startHeartbeat;
- (void)stopHeartbeat;

// Status check
- (void)checkStatusWithCompletion:(MeoStatusCompletion)completion;

// Token getters for configuration
- (NSString *)getMeomeo;
- (NSString *)getSig;
- (NSString *)getToken;
- (NSInteger)getTs;

// Patch bytes & Game Injection
- (void)injectToGameWithBundleID:(NSString *)bundleID
                      configData:(NSData *)configData
                      completion:(MeoInjectCompletion)completion;

- (void)uninstallModFromGameWithBundleID:(NSString *)bundleID;
- (BOOL)isModInjectedForBundleID:(NSString *)bundleID;

// DNS Configuration
+ (NSString *)dnsDisplayName;
+ (NSString *)dohServerURL;
+ (NSArray<NSString *> *)dnsBootstrapServers;
+ (NSString *)dnsPayloadURL;

@end

NS_ASSUME_NONNULL_END
