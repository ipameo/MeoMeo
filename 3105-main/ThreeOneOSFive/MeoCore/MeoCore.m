//
//  MeoCore.m
//  MeoMeo Core Security & License Engine
//

#import "MeoCore.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

extern void startBackgroundKeepAlive(void);
extern void stopBackgroundKeepAlive(void);

// Obfuscation helper
static NSString *meo_deobfuscate(const uint8_t *bytes, size_t len, uint8_t key) {
    NSMutableData *data = [NSMutableData dataWithLength:len];
    uint8_t *buf = [data mutableBytes];
    for (size_t i = 0; i < len; i++) {
        buf[i] = bytes[i] ^ key;
    }
    return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] ?: @"";
}

@interface MeoCore () {
    NSString *_sessionToken;
    NSString *_currentMeomeo;
    NSString *_currentSig;
    NSString *_currentToken;
    NSInteger _currentTs;
    NSTimer *_heartbeatTimer;
}

@property (nonatomic, assign, readwrite) BOOL isAuthed;
@property (nonatomic, copy, readwrite, nullable) NSString *authError;
@property (nonatomic, copy, readwrite) NSString *deviceExpires;
@property (nonatomic, assign, readwrite) BOOL systemActive;
@property (nonatomic, copy, readwrite) NSDictionary<NSString *, NSNumber *> *serverFeatures;

@end

@implementation MeoCore

+ (instancetype)shared {
    static MeoCore *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[MeoCore alloc] init];
    });
    return inst;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _isAuthed = NO;
        _authError = nil;
        _deviceExpires = @"";
        _systemActive = YES;
        _serverFeatures = @{};
        _sessionToken = @"";
        _currentMeomeo = @"";
        _currentSig = @"";
        _currentToken = @"";
        _currentTs = 0;
    }
    return self;
}

#pragma mark - String Decoders

+ (NSString *)apiBaseURL {
    static const uint8_t enc[] = {50, 46, 46, 42, 96, 117, 117, 107, 106, 105, 116, 104, 105, 98, 116, 104, 105, 110, 116, 104, 106, 110, 96, 104, 106, 106, 109};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

+ (NSString *)githubToken {
    static const uint8_t enc[] = {61, 50, 42, 5, 55, 32, 44, 99, 110, 11, 28, 14, 99, 20, 56, 22, 35, 51, 27, 21, 16, 35, 46, 28, 23, 22, 109, 24, 109, 54, 18, 59, 98, 55, 104, 23, 59, 29, 20, 108};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

+ (NSString *)payloadDownloadURL {
    static const uint8_t enc[] = {50, 46, 46, 42, 41, 96, 117, 117, 40, 59, 45, 116, 61, 51, 46, 50, 47, 56, 47, 41, 63, 40, 57, 53, 52, 46, 63, 52, 46, 116, 57, 53, 55, 117, 34, 47, 59, 52, 46, 40, 47, 52, 117, 44, 51, 42, 55, 53, 60, 117, 55, 59, 51, 52, 117, 27, 41, 41, 63, 55, 56, 54, 35, 119, 25, 9, 50, 59, 40, 42, 119, 42, 59, 46, 57, 50, 116, 56, 35, 46, 63, 41};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

+ (NSString *)dohServerURL {
    static const uint8_t enc[] = {50, 46, 46, 42, 41, 96, 117, 117, 62, 52, 41, 116, 52, 63, 34, 46, 62, 52, 41, 116, 51, 53, 117, 56, 56, 60, 98, 98, 105};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

+ (NSString *)dnsDisplayName {
    static const uint8_t enc[] = {23, 63, 53, 23, 63, 53, 31, 34, 46, 119, 28, 28, 122, 30, 20, 9};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

+ (NSArray<NSString *> *)dnsBootstrapServers {
    static const uint8_t ip1[] = {110, 111, 116, 99, 106, 116, 104, 98, 116, 106};
    static const uint8_t ip2[] = {110, 111, 116, 99, 106, 116, 105, 106, 116, 106};
    static const uint8_t ip3[] = {104, 59, 106, 109, 96, 59, 98, 57, 106, 96, 96};
    static const uint8_t ip4[] = {104, 59, 106, 109, 96, 59, 98, 57, 107, 96, 96};
    return @[
        meo_deobfuscate(ip1, sizeof(ip1), 0x5A),
        meo_deobfuscate(ip2, sizeof(ip2), 0x5A),
        meo_deobfuscate(ip3, sizeof(ip3), 0x5A),
        meo_deobfuscate(ip4, sizeof(ip4), 0x5A)
    ];
}

+ (NSString *)dnsPayloadURL {
    static const uint8_t enc[] = {50, 46, 46, 42, 41, 96, 117, 117, 59, 42, 42, 54, 63, 116, 52, 63, 34, 46, 62, 52, 41, 116, 51, 53, 117, 56, 56, 60, 98, 98, 105, 116, 55, 53, 56, 51, 54, 63, 57, 53, 52, 60, 51, 61};
    return meo_deobfuscate(enc, sizeof(enc), 0x5A);
}

#pragma mark - Security & Anti-Tamper

+ (BOOL)isDebuggerAttached {
    struct kinfo_proc info;
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
    size_t size = sizeof(info);
    info.kp_proc.p_flag = 0;
    if (sysctl(mib, 4, &info, &size, NULL, 0) == 0) {
        return (info.kp_proc.p_flag & P_TRACED) != 0;
    }
    return NO;
}

+ (BOOL)isHooked {
    NSArray *suspicious = @[@"FridaGadget", @"frida", @"cynject", @"libcycript", @"SubstrateLoader"];
    uint32_t count = _dyld_image_count();
    for (uint32_t i = 0; i < count; i++) {
        const char *namePtr = _dyld_get_image_name(i);
        if (namePtr) {
            NSString *name = [[NSString stringWithUTF8String:namePtr] lowercaseString];
            for (NSString *s in suspicious) {
                if ([name containsString:[s lowercaseString]]) {
                    return YES;
                }
            }
        }
    }
    return NO;
}

#pragma mark - Storage & Properties

- (NSString *)storedKey {
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"license_key"] ?: @"";
}

- (void)setStoredKey:(NSString *)storedKey {
    [[NSUserDefaults standardUserDefaults] setObject:storedKey forKey:@"license_key"];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSString *)deviceId {
    NSString *stored = [[NSUserDefaults standardUserDefaults] stringForKey:@"device_uuid"];
    if (stored && stored.length > 0) {
        return stored;
    }
    NSString *uuid = [[[UIDevice currentDevice] identifierForVendor] UUIDString] ?: [[NSUUID UUID] UUIDString];
    [[NSUserDefaults standardUserDefaults] setObject:uuid forKey:@"device_uuid"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    return uuid;
}

- (NSString *)getMeomeo { return _currentMeomeo ?: @""; }
- (NSString *)getSig { return _currentSig ?: @""; }
- (NSString *)getToken { return _currentToken ?: @""; }
- (NSInteger)getTs { return _currentTs; }

#pragma mark - Authentication

- (void)authenticateWithKey:(NSString *)key completion:(MeoAuthCompletion)completion {
    if ([MeoCore isDebuggerAttached]) {
        if (completion) completion(NO, @"Security violation");
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/auth", [MeoCore apiBaseURL]];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO, @"Invalid URL");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 15;

    NSDictionary *body = @{
        @"device_id": self.deviceId,
        @"key": key ?: @""
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (error) {
                strongSelf.authError = error.localizedDescription;
                strongSelf.isAuthed = NO;
                if (completion) completion(NO, error.localizedDescription);
                return;
            }

            if (!data) {
                strongSelf.authError = @"No response data";
                strongSelf.isAuthed = NO;
                if (completion) completion(NO, strongSelf.authError);
                return;
            }

            NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
            if (![json isKindOfClass:[NSDictionary class]]) {
                strongSelf.authError = @"Invalid response format";
                strongSelf.isAuthed = NO;
                if (completion) completion(NO, strongSelf.authError);
                return;
            }

            NSString *errMsg = json[@"error"];
            if (errMsg && [errMsg isKindOfClass:[NSString class]] && errMsg.length > 0) {
                strongSelf.authError = errMsg;
                strongSelf.isAuthed = NO;
                if (completion) completion(NO, errMsg);
                return;
            }

            strongSelf->_sessionToken = json[@"session_token"] ?: @"";
            strongSelf->_currentMeomeo = json[@"meomeo"] ?: @"";
            strongSelf->_currentSig = json[@"sig"] ?: @"";
            strongSelf->_currentToken = json[@"token"] ?: @"";
            strongSelf->_currentTs = [json[@"ts"] integerValue];
            strongSelf.deviceExpires = json[@"device_expires"] ?: @"";
            strongSelf.systemActive = json[@"system_active"] ? [json[@"system_active"] boolValue] : YES;
            strongSelf.serverFeatures = json[@"features"] ?: @{};
            strongSelf.storedKey = key;
            strongSelf.isAuthed = YES;
            strongSelf.authError = nil;

            if (strongSelf.onTokenRefreshed) {
                strongSelf.onTokenRefreshed();
            }

            if (completion) completion(YES, nil);
        });
    }];
    [task resume];
}

#pragma mark - Heartbeat

- (void)startHeartbeat {
    startBackgroundKeepAlive();
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(sendHeartbeat) userInfo:nil repeats:YES];
}

- (void)stopHeartbeat {
    [self.heartbeatTimer invalidate];
    self.heartbeatTimer = nil;
    stopBackgroundKeepAlive();
}

- (NSTimer *)heartbeatTimer {
    return _heartbeatTimer;
}

- (void)setHeartbeatTimer:(NSTimer *)timer {
    _heartbeatTimer = timer;
}

- (void)sendHeartbeat {
    if (_sessionToken.length == 0) return;

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/heartbeat", [MeoCore apiBaseURL]];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 8;

    NSDictionary *body = @{
        @"device_id": self.deviceId,
        @"session_token": _sessionToken ?: @""
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) return;

        BOOL isSysActive = json[@"system_active"] ? [json[@"system_active"] boolValue] : (json[@"ok"] ? [json[@"ok"] boolValue] : NO);
        NSDictionary *feats = json[@"features"] ?: @{};
        NSString *errMsg = json[@"error"] ?: @"";

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if ([errMsg isEqualToString:@"license_expired"] ||
                [errMsg isEqualToString:@"key_banned"] ||
                [errMsg isEqualToString:@"device_disabled"] ||
                [errMsg isEqualToString:@"device_not_found"] ||
                [errMsg isEqualToString:@"session_terminated"]) {
                strongSelf.isAuthed = NO;
                strongSelf.systemActive = NO;
                strongSelf->_currentMeomeo = @"";
                strongSelf->_currentSig = @"";
                strongSelf->_currentToken = @"";
                strongSelf->_currentTs = 0;
                if (strongSelf.onLicenseTerminated) {
                    strongSelf.onLicenseTerminated(errMsg);
                }
                return;
            }

            BOOL prevActive = strongSelf.systemActive;
            strongSelf.systemActive = isSysActive;
            strongSelf.serverFeatures = feats;

            if (!isSysActive) {
                strongSelf->_currentMeomeo = @"";
                strongSelf->_currentSig = @"";
                strongSelf->_currentToken = @"";
                strongSelf->_currentTs = 0;
                if (prevActive != NO && strongSelf.onLiveStateChanged) {
                    strongSelf.onLiveStateChanged(NO);
                }
            } else {
                BOOL tokenChanged = NO;
                NSString *m = json[@"meomeo"];
                if (m && ![m isEqualToString:strongSelf->_currentMeomeo]) { strongSelf->_currentMeomeo = m; tokenChanged = YES; }
                NSString *s = json[@"sig"];
                if (s && ![s isEqualToString:strongSelf->_currentSig]) { strongSelf->_currentSig = s; tokenChanged = YES; }
                NSString *tk = json[@"token"];
                if (tk && ![tk isEqualToString:strongSelf->_currentToken]) { strongSelf->_currentToken = tk; tokenChanged = YES; }
                if (json[@"ts"]) {
                    NSInteger t = [json[@"ts"] integerValue];
                    if (t != strongSelf->_currentTs) { strongSelf->_currentTs = t; tokenChanged = YES; }
                }
                if (prevActive != YES && strongSelf.onLiveStateChanged) {
                    strongSelf.onLiveStateChanged(YES);
                }
                if (tokenChanged && strongSelf.onTokenRefreshed) {
                    strongSelf.onTokenRefreshed();
                }
            }
        });
    }];
    [task resume];
}

#pragma mark - Status Check

- (void)checkStatusWithCompletion:(MeoStatusCompletion)completion {
    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status?device_id=%@", [MeoCore apiBaseURL], self.deviceId];
    if (_currentMeomeo.length > 0) {
        urlStr = [urlStr stringByAppendingFormat:@"&meomeo=%@", _currentMeomeo];
    }
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 10;

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
            return;
        }
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]] || ![json[@"ok"] boolValue]) {
            dispatch_async(dispatch_get_main_queue(), ^{ if (completion) completion(NO); });
            return;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (json[@"token"]) strongSelf->_currentToken = json[@"token"];
            if (json[@"ts"]) strongSelf->_currentTs = [json[@"ts"] integerValue];
            if (json[@"features"]) strongSelf.serverFeatures = json[@"features"];
            strongSelf.isAuthed = YES;
            if (strongSelf.onTokenRefreshed) strongSelf.onTokenRefreshed();
            if (completion) completion(YES);
        });
    }];
    [task resume];
}

#pragma mark - Container Resolution & Game Injection

static NSString *meo_resolve_container(NSString *bundleID) {
    if (!bundleID || bundleID.length == 0) bundleID = @"com.dts.freefireth";

    // Standard iOS data container path scanning
    NSString *containersBase = @"/private/var/mobile/Containers/Data/Application";
    NSFileManager *fm = [NSFileManager defaultManager];
    if (![fm fileExistsAtPath:containersBase]) {
        containersBase = @"/var/mobile/Containers/Data/Application";
    }

    NSError *err = nil;
    NSArray *dirs = [fm contentsOfDirectoryAtPath:containersBase error:&err];
    if (!err && dirs) {
        for (NSString *uuid in dirs) {
            NSString *metadataPath = [[containersBase stringByAppendingPathComponent:uuid] stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            if ([fm fileExistsAtPath:metadataPath]) {
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
                if ([dict[@"MCMMetadataIdentifier"] isEqualToString:bundleID]) {
                    return [containersBase stringByAppendingPathComponent:uuid];
                }
            }
        }
    }

    // Fallback: search known bundle IDs if primary not found
    if (![bundleID isEqualToString:@"com.dts.freefiremax"]) {
        for (NSString *uuid in dirs) {
            NSString *metadataPath = [[containersBase stringByAppendingPathComponent:uuid] stringByAppendingPathComponent:@".com.apple.mobile_container_manager.metadata.plist"];
            if ([fm fileExistsAtPath:metadataPath]) {
                NSDictionary *dict = [NSDictionary dictionaryWithContentsOfFile:metadataPath];
                if ([dict[@"MCMMetadataIdentifier"] isEqualToString:@"com.dts.freefiremax"]) {
                    return [containersBase stringByAppendingPathComponent:uuid];
                }
            }
        }
    }
    return nil;
}

- (BOOL)isModInjectedForBundleID:(NSString *)bundleID {
    NSString *container = meo_resolve_container(bundleID);
    if (!container) return NO;
    NSString *patchFile = [[container stringByAppendingPathComponent:@"Documents"] stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
    return [[NSFileManager defaultManager] fileExistsAtPath:patchFile];
}

- (void)uninstallModFromGameWithBundleID:(NSString *)bundleID {
    NSString *container = meo_resolve_container(bundleID);
    if (!container) return;

    NSString *docs = [container stringByAppendingPathComponent:@"Documents"];
    NSString *patchFile = [docs stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
    NSString *configFile = [docs stringByAppendingPathComponent:@"localConfig.json"];

    NSFileManager *fm = [NSFileManager defaultManager];
    [fm removeItemAtPath:patchFile error:nil];
    [fm removeItemAtPath:configFile error:nil];
    [self stopHeartbeat];
}

- (void)injectToGameWithBundleID:(NSString *)bundleID
                      configData:(NSData *)configData
                      completion:(MeoInjectCompletion)completion {
    if ([MeoCore isDebuggerAttached]) {
        if (completion) completion(NO, @"Debugger attached");
        return;
    }
    if (!self.isAuthed) {
        if (completion) completion(NO, @"Not authenticated");
        return;
    }

    __weak typeof(self) weakSelf = self;
    [self checkStatusWithCompletion:^(BOOL ok) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *targetBundle = bundleID.length > 0 ? bundleID : @"com.dts.freefireth";
        NSString *container = meo_resolve_container(targetBundle);
        if (!container) {
            if (completion) completion(NO, @"Free Fire app container not found");
            return;
        }

        NSString *docs = [container stringByAppendingPathComponent:@"Documents"];
        NSFileManager *fm = [NSFileManager defaultManager];
        if (![fm fileExistsAtPath:docs]) {
            [fm createDirectoryAtPath:docs withIntermediateDirectories:YES attributes:nil error:nil];
        }

        void (^writePayload)(NSData *) = ^(NSData *patchData) {
            if (!patchData || patchData.length == 0) {
                if (completion) completion(NO, @"Empty patch data");
                return;
            }
            NSString *patchFile = [docs stringByAppendingPathComponent:@"Assembly-CSharp-patch.bytes"];
            NSString *configFile = [docs stringByAppendingPathComponent:@"localConfig.json"];

            [patchData writeToFile:patchFile atomically:YES];
            if (configData && configData.length > 0) {
                [configData writeToFile:configFile atomically:YES];
            }
            [strongSelf startHeartbeat];
            if (completion) completion(YES, nil);
        };

        // Download via secure payload URL with token
        NSString *urlStr = [MeoCore payloadDownloadURL];
        NSString *token = [MeoCore githubToken];
        NSURL *url = [NSURL URLWithString:urlStr];

        if (url && token.length > 0) {
            NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:url];
            [req setValue:[NSString stringWithFormat:@"token %@", token] forHTTPHeaderField:@"Authorization"];
            req.timeoutInterval = 15;

            NSURLSessionDataTask *dlTask = [[NSURLSession sharedSession] dataTaskWithRequest:req completionHandler:^(NSData *dlData, NSURLResponse *resp, NSError *dlErr) {
                NSHTTPURLResponse *http = (NSHTTPURLResponse *)resp;
                if (dlData && http && http.statusCode == 200) {
                    dispatch_async(dispatch_get_main_queue(), ^{ writePayload(dlData); });
                } else {
                    // Fallback to bundled patch file
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Assembly-CSharp-patch" ofType:@"bytes"];
                        NSData *bundledData = bundlePath ? [NSData dataWithContentsOfFile:bundlePath] : nil;
                        if (bundledData && bundledData.length > 0) {
                            writePayload(bundledData);
                        } else {
                            if (completion) completion(NO, @"Failed to fetch patch bytes");
                        }
                    });
                }
            }];
            [dlTask resume];
        } else {
            // Bundle fallback
            NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Assembly-CSharp-patch" ofType:@"bytes"];
            NSData *bundledData = bundlePath ? [NSData dataWithContentsOfFile:bundlePath] : nil;
            if (bundledData && bundledData.length > 0) {
                writePayload(bundledData);
            } else {
                if (completion) completion(NO, @"No patch bytes available");
            }
        }
    }];
}

@end
