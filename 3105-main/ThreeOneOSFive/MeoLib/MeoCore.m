//
//  MeoCore.m
//  MoneyExt Core Security & License Engine
//

#import "MeoCore.h"
#import <UIKit/UIKit.h>
#import <sys/sysctl.h>
#import <mach-o/dyld.h>

extern void startBackgroundKeepAlive(void);
extern void stopBackgroundKeepAlive(void);

// Obfuscation helper (XOR)
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

        // Default Config Settings
        _espMaster = NO;
        _espBox = NO;
        _espLine = NO;
        _espName = NO;
        _espHealth = NO;
        _espDistance = NO;
        _espTracer = NO;
        _espSkeleton = NO;
        _aimEnabled = NO;
        _aimSystemEnabled = NO;
        _espFov = NO;
        _noRecoil = NO;
        _aimTarget = 0;
        _fovSize = 60.0f;
        _headshotRate = 60.0f;
        _buffDame = NO;
        _speedHack = 1;

        [self loadConfig];
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
    NSString *key = @"device_unique_identifier";
    NSString *devId = [[NSUserDefaults standardUserDefaults] stringForKey:key];
    if (!devId || devId.length == 0) {
        devId = [UIDevice currentDevice].identifierForVendor.UUIDString ?: [[NSUUID UUID] UUIDString];
        [[NSUserDefaults standardUserDefaults] setObject:devId forKey:key];
        [[NSUserDefaults standardUserDefaults] synchronize];
    }
    return devId;
}

#pragma mark - Authentication

- (void)authenticateWithKey:(NSString *)key completion:(MeoAuthCompletion)completion {
    if ([MeoCore isDebuggerAttached]) {
        if (completion) completion(NO, @"Security violation: debugger detected");
        return;
    }

    NSString *cleanedKey = [key stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if (cleanedKey.length == 0) {
        if (completion) completion(NO, @"Please enter License Key");
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/auth", [MeoCore apiBaseURL]];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO, @"Invalid configuration URL");
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 12;

    NSDictionary *body = @{
        @"key": cleanedKey,
        @"device_id": self.deviceId,
        @"platform": @"ios",
        @"os_version": [UIDevice currentDevice].systemVersion ?: @"16.0",
        @"app_version": @"1.0.0"
    };

    NSError *err = nil;
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:&err];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, [NSString stringWithFormat:@"Connection error: %@", error.localizedDescription]);
            });
            return;
        }

        if (!data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @"Empty response from server");
            });
            return;
        }

        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (completion) completion(NO, @"Invalid server response");
            });
            return;
        }

        BOOL ok = NO;
        if (json[@"ok"] != nil) {
            ok = [json[@"ok"] boolValue];
        } else if ([json[@"status"] isEqualToString:@"active"] || (json[@"session_token"] && [json[@"session_token"] length] > 0)) {
            ok = YES;
        }
        if (json[@"error"] != nil && [json[@"error"] length] > 0) {
            ok = NO;
        }

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (ok) {
                strongSelf.isAuthed = YES;
                strongSelf.authError = nil;
                strongSelf.storedKey = cleanedKey;
                strongSelf->_sessionToken = json[@"session_token"] ?: @"";
                strongSelf->_currentToken = json[@"token"] ?: @"";
                strongSelf->_currentTs = [json[@"ts"] integerValue];
                strongSelf->_currentMeomeo = json[@"meomeo"] ?: @"";
                strongSelf->_currentSig = json[@"sig"] ?: @"";
                strongSelf.deviceExpires = json[@"device_expires"] ?: (json[@"expires_at"] ?: @"");
                strongSelf.systemActive = json[@"system_active"] ? [json[@"system_active"] boolValue] : YES;
                strongSelf.serverFeatures = json[@"features"] ?: @{};

                [strongSelf startHeartbeat];
                if (completion) completion(YES, nil);
            } else {
                strongSelf.isAuthed = NO;
                NSString *reason = json[@"error"] ?: @"Invalid key";
                strongSelf.authError = reason;
                [strongSelf resetAllFeatures];
                if (completion) completion(NO, reason);
            }
        });
    }];
    [task resume];
}

#pragma mark - Heartbeat & Background Engine

- (void)startHeartbeat {
    [self stopHeartbeat];
    __weak typeof(self) weakSelf = self;
    _heartbeatTimer = [NSTimer scheduledTimerWithTimeInterval:30.0 repeats:YES block:^(NSTimer * _Nonnull timer) {
        [weakSelf sendHeartbeat];
    }];
}

- (void)stopHeartbeat {
    if (_heartbeatTimer) {
        [_heartbeatTimer invalidate];
        _heartbeatTimer = nil;
    }
}

- (void)sendHeartbeat {
    if (!self.isAuthed || _sessionToken.length == 0) return;

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/heartbeat", [MeoCore apiBaseURL]];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) return;

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.HTTPMethod = @"POST";
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    request.timeoutInterval = 10;

    NSDictionary *body = @{
        @"session_token": _sessionToken,
        @"device_id": self.deviceId
    };
    request.HTTPBody = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];

    __weak typeof(self) weakSelf = self;
    NSURLSessionDataTask *task = [[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!data) return;
        NSDictionary *json = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
        if (![json isKindOfClass:[NSDictionary class]]) return;

        dispatch_async(dispatch_get_main_queue(), ^{
            __strong typeof(weakSelf) strongSelf = weakSelf;
            if (!strongSelf) return;

            if (![json[@"ok"] boolValue]) {
                strongSelf.isAuthed = NO;
                strongSelf.systemActive = NO;
                [strongSelf resetAllFeatures];
                [strongSelf stopHeartbeat];
                if (strongSelf.onLicenseTerminated) {
                    strongSelf.onLicenseTerminated(json[@"error"] ?: @"license_expired");
                }
            } else {
                if (json[@"token"]) strongSelf->_currentToken = json[@"token"];
                if (json[@"ts"]) strongSelf->_currentTs = [json[@"ts"] integerValue];
                if (json[@"system_active"]) {
                    BOOL active = [json[@"system_active"] boolValue];
                    if (active != strongSelf.systemActive) {
                        strongSelf.systemActive = active;
                        if (strongSelf.onLiveStateChanged) strongSelf.onLiveStateChanged(active);
                    }
                }
                if (json[@"features"]) {
                    strongSelf.serverFeatures = json[@"features"];
                    if (strongSelf.onTokenRefreshed) strongSelf.onTokenRefreshed();
                }
            }
        });
    }];
    [task resume];
}

#pragma mark - Status Check

- (void)checkStatusWithCompletion:(MeoStatusCompletion)completion {
    if (!self.isAuthed) {
        if (completion) completion(NO);
        return;
    }

    NSString *urlStr = [NSString stringWithFormat:@"%@/api/status?device_id=%@", [MeoCore apiBaseURL], self.deviceId];
    NSURL *url = [NSURL URLWithString:urlStr];
    if (!url) {
        if (completion) completion(NO);
        return;
    }

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    request.timeoutInterval = 8;

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

#pragma mark - Container Resolution & Mod Config Engine

static NSString *meo_resolve_container(NSString *bundleID) {
    if (!bundleID || bundleID.length == 0) bundleID = @"com.dts.freefireth";

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

- (void)loadConfig {
    @try {
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *docsURL = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSString *configPath = [docsURL.path stringByAppendingPathComponent:@"localConfig.json"];
        if ([fm fileExistsAtPath:configPath]) {
            NSData *data = [NSData dataWithContentsOfFile:configPath];
            if (data) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
                if ([dict isKindOfClass:[NSDictionary class]]) {
                    if (dict[@"EspMaster"]) self.espMaster = [dict[@"EspMaster"] boolValue];
                    if (dict[@"EspBox"]) self.espBox = [dict[@"EspBox"] boolValue];
                    if (dict[@"EspLine"]) self.espLine = [dict[@"EspLine"] boolValue];
                    if (dict[@"EspName"]) self.espName = [dict[@"EspName"] boolValue];
                    if (dict[@"EspHealth"]) self.espHealth = [dict[@"EspHealth"] boolValue];
                    if (dict[@"EspDistance"]) self.espDistance = [dict[@"EspDistance"] boolValue];
                    if (dict[@"EspTracer"]) self.espTracer = [dict[@"EspTracer"] boolValue];
                    if (dict[@"EspSkeleton"]) self.espSkeleton = [dict[@"EspSkeleton"] boolValue];

                    if (dict[@"AimEnabled"]) self.aimEnabled = [dict[@"AimEnabled"] boolValue];
                    if (dict[@"AimSystemEnabled"]) self.aimSystemEnabled = [dict[@"AimSystemEnabled"] boolValue];
                    if (dict[@"EspFov"]) self.espFov = [dict[@"EspFov"] boolValue];
                    if (dict[@"NoRecoil"]) self.noRecoil = [dict[@"NoRecoil"] boolValue];
                    if (dict[@"AimTarget"]) self.aimTarget = [dict[@"AimTarget"] integerValue];
                    if (dict[@"FovSize"]) self.fovSize = [dict[@"FovSize"] floatValue];
                    if (dict[@"HeadshotRate"]) self.headshotRate = [dict[@"HeadshotRate"] floatValue];
                    if (dict[@"BuffDame"]) self.buffDame = [dict[@"BuffDame"] boolValue];
                    if (dict[@"SpeedHack"]) self.speedHack = [dict[@"SpeedHack"] integerValue];
                }
            }
        }
    } @catch (NSException *e) {}
}

- (void)saveAndSyncConfigForBundleID:(NSString *)bundleID {
    @try {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];

        // Encrypted Server Fields & Session Data
        dict[@"meomeo"] = _currentMeomeo ?: @"";
        dict[@"sig"] = _currentSig ?: @"";
        dict[@"token"] = _currentToken ?: @"";
        dict[@"ts"] = @(_currentTs);
        dict[@"system_active"] = @(self.systemActive);

        dict[@"server_esp"] = self.serverFeatures[@"server_esp"] ?: @YES;
        dict[@"server_aim"] = self.serverFeatures[@"server_aim"] ?: @YES;
        dict[@"server_box"] = self.serverFeatures[@"server_box"] ?: @YES;
        dict[@"server_line"] = self.serverFeatures[@"server_line"] ?: @YES;
        dict[@"server_skeleton"] = self.serverFeatures[@"server_skeleton"] ?: @YES;
        dict[@"server_name"] = self.serverFeatures[@"server_name"] ?: @YES;
        dict[@"server_distance"] = self.serverFeatures[@"server_distance"] ?: @YES;
        dict[@"server_health"] = self.serverFeatures[@"server_health"] ?: @YES;
        dict[@"server_headshot"] = self.serverFeatures[@"server_headshot"] ?: @YES;
        dict[@"testCodePatch"] = @YES;

        // User GUI Settings
        dict[@"EspMaster"] = @(self.espMaster);
        dict[@"EspBox"] = @(self.espBox);
        dict[@"EspLine"] = @(self.espLine);
        dict[@"EspName"] = @(self.espName);
        dict[@"EspHealth"] = @(self.espHealth);
        dict[@"EspDistance"] = @(self.espDistance);
        dict[@"EspTracer"] = @(self.espTracer);
        dict[@"EspSkeleton"] = @(self.espSkeleton);

        dict[@"AimEnabled"] = @(self.aimEnabled);
        dict[@"AimSystemEnabled"] = @(self.aimSystemEnabled);
        dict[@"EspFov"] = @(self.espFov);
        dict[@"NoRecoil"] = @(self.noRecoil);
        dict[@"AimTarget"] = @(self.aimTarget);
        dict[@"FovSize"] = @(self.fovSize);
        dict[@"HeadshotRate"] = @(self.headshotRate);
        dict[@"BuffDame"] = @(self.buffDame);
        dict[@"SpeedHack"] = @(self.speedHack);

        NSData *jsonData = [NSJSONSerialization dataWithJSONObject:dict options:NSJSONWritingPrettyPrinted error:nil];
        if (!jsonData) return;

        // 1. Write to App Documents
        NSFileManager *fm = [NSFileManager defaultManager];
        NSURL *docsURL = [fm URLsForDirectory:NSDocumentDirectory inDomains:NSUserDomainMask].firstObject;
        NSString *localConfigPath = [docsURL.path stringByAppendingPathComponent:@"localConfig.json"];
        [jsonData writeToFile:localConfigPath atomically:YES];

        // 2. Sync to Game Container Documents
        NSString *container = meo_resolve_container(bundleID);
        if (container) {
            NSString *gameDocs = [container stringByAppendingPathComponent:@"Documents"];
            if (![fm fileExistsAtPath:gameDocs]) {
                [fm createDirectoryAtPath:gameDocs withIntermediateDirectories:YES attributes:nil error:nil];
            }
            NSString *gameConfig = [gameDocs stringByAppendingPathComponent:@"localConfig.json"];
            [jsonData writeToFile:gameConfig atomically:YES];
        }
    } @catch (NSException *e) {}
}

- (void)resetAllFeatures {
    self.espMaster = NO;
    self.espBox = NO;
    self.espLine = NO;
    self.espName = NO;
    self.espHealth = NO;
    self.espDistance = NO;
    self.espTracer = NO;
    self.espSkeleton = NO;
    self.aimEnabled = NO;
    self.aimSystemEnabled = NO;
    self.espFov = NO;
    self.noRecoil = NO;
    self.buffDame = NO;
    self.speedHack = 1;
    self.systemActive = NO;
    [self saveAndSyncConfigForBundleID:nil];
}

#pragma mark - Game Patch & Injection

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
                      completion:(MeoInjectCompletion)completion {
    if ([MeoCore isDebuggerAttached]) {
        if (completion) completion(NO, @"Debugger attached");
        return;
    }
    if (!self.isAuthed) {
        if (completion) completion(NO, @"Please activate License before injecting");
        return;
    }

    [self saveAndSyncConfigForBundleID:bundleID];

    __weak typeof(self) weakSelf = self;
    [self checkStatusWithCompletion:^(BOOL ok) {
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if (!strongSelf) return;

        NSString *targetBundle = bundleID.length > 0 ? bundleID : @"com.dts.freefireth";
        NSString *container = meo_resolve_container(targetBundle);
        if (!container) {
            if (completion) completion(NO, @"Free Fire game directory not found");
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
            [patchData writeToFile:patchFile atomically:YES];
            [strongSelf saveAndSyncConfigForBundleID:targetBundle];
            [strongSelf startHeartbeat];
            if (completion) completion(YES, nil);
        };

        // Try downloading latest patch payload or fallback to bundled patch
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
                    dispatch_async(dispatch_get_main_queue(), ^{
                        NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Assembly-CSharp-patch" ofType:@"bytes"];
                        NSData *bundledData = bundlePath ? [NSData dataWithContentsOfFile:bundlePath] : nil;
                        if (bundledData && bundledData.length > 0) {
                            writePayload(bundledData);
                        } else {
                            if (completion) completion(NO, @"Failed to download patch data");
                        }
                    });
                }
            }];
            [dlTask resume];
        } else {
            NSString *bundlePath = [[NSBundle mainBundle] pathForResource:@"Assembly-CSharp-patch" ofType:@"bytes"];
            NSData *bundledData = bundlePath ? [NSData dataWithContentsOfFile:bundlePath] : nil;
            if (bundledData && bundledData.length > 0) {
                writePayload(bundledData);
            } else {
                if (completion) completion(NO, @"Patch file not found");
            }
        }
    }];
}

@end
