#include "Tweak.h"
// PowerBeatsPro PID is 8203 - adding in actual support after battery issues are fixed

%group AirPortAnimFix
%hook SFDeviceAssetTask
-(id)bundleAtURL:(id)arg1 error:(id*)arg2 {
	NSString *originalBundlePath = [arg1 lastPathComponent];
	// intercept the bundle url and replace it with our own that actually contains all the proper files
	if ([originalBundlePath isEqual:@"AirPods1_1-CL_0.devicebundle"]) {
		// only replace it with our bundle if it's for Airpods1,1
		arg1 = [[NSURL alloc] initWithString:@"file:///Library/Application%20Support/AirPort/AirPods1_1-CL_0.devicebundle" relativeToURL:nil];
	}
	if ([originalBundlePath isEqual:@"AirPods1_2-CL_0.devicebundle"]) {
		// only replace it with our bundle if it's for Airpods1,2 (Wireless case)
		arg1 = [[NSURL alloc] initWithString:@"file:///Library/Application%20Support/AirPort/AirPods1_2-CL_0.devicebundle" relativeToURL:nil];
	}
	return %orig;
}
%end
%end

%group AirPortSupport
%hook BCBatteryDevice
+ (id)batteryDeviceWithIdentifier:(id)arg1 vendor:(long long)arg2 productIdentifier:(long long)arg3 parts:(unsigned long long)arg4 matchIdentifier:(id)arg5 {
	%orig;
	// Change PID everywhere we can (even though it's not 100% neccessary)
	if (arg3 == 8207) arg3 = 8194;
	
	// Hide the extra entry that gets added for the 2nd gen airpods (Part 0 isn't needed for airpods)
	if (arg3 == 8194 && arg4 == 0) {
		return nil;
	}

	else return %orig;
}
-(id)initWithIdentifier:(id)arg1 vendor:(long long)arg2 productIdentifier:(long long)arg3 parts:(unsigned long long)arg4 matchIdentifier:(id)arg5 {
	%orig;
	// Change PID everywhere we can (even though it's not 100% neccessary)
	if (arg3 == 8207) arg3 = 8194;

	// Hide the extra entry that gets added for the 2nd gen airpods (Part 0 isn't needed for airpods)
	if (arg3 == 8194 && arg4 == 0) {
		return nil;
	}
	else return %orig;
}
%end

%hook SFPowerSource
-(void)updateWithPowerSource:(id)arg1 {
	%orig;
	//NSLog(@"UpdatePowerSource: %@", arg1);
}
-(unsigned)updateWithPowerSourceDescription:(id)arg1 {
	//NSLog(@"UpdatePSDescription: %@", arg1);
	return %orig;
}
-(id)init {
	//SFPowerSource *test = %orig;
	//NSLog(@"Init: %@, Part ID: %@", test, test.partID);
	return %orig;
}
%end

%hook SFPowerSourceMonitor
-(long long)productID {
	long long pid = %orig;
	if (pid == 8207) pid = 8194;
	return pid;
}

-(void)_updatePowerSource:(id)arg1 desc:(id)arg2 adapterDesc:(id)arg3 {
	SFPowerSource *powerSource = arg1;
	if (![powerSource.partID isEqualToString:@"Single"]) %orig;
}
-(void)_foundPowerSource:(id)arg1 desc:(id)arg2 adapterDesc:(id)arg3 {
	%orig;
	//NSLog(@"Found PowerSource: %@, Description: %@, Adapter: %@", arg1, arg2, arg3);
}
-(id)powerSourcesFoundHandler {
	//NSLog(@"FoundHandler: %@", %orig);
	return %orig;
}
%end

%hook SFBLEScanner
-(id)modelWithProductID:(unsigned short)arg1 {
	// Set PID once again
	if (arg1 == 8207) arg1 = 8194;
	return %orig;
}
%end

%hook SFBLEDevice
- (unsigned int)productID2 {
	// get the pid
	unsigned int pid = %orig;

	// if it's 2nd gen airpod - set it to 1st gen's pid
	if (pid == 8207) pid = 8194;

	return pid;
}
-(id)initWithCoder:(id)arg1 {
	self = %orig;
	// get the original advert fields
	NSDictionary *advertFields = self.advertisementFields;

	// check if device pid is airpods 2 (and 1)
	if ([[advertFields objectForKey:@"pid"] longLongValue] == 8207 || [[advertFields objectForKey:@"pid"] longLongValue] == 8194) {
		// make a mutable copy of the data so we can modify it
		NSMutableDictionary *newAdvertFields = [advertFields mutableCopy];
		// set the model & pid to 1st gen airpods
		[newAdvertFields setObject:@"AirPods1,1" forKey:@"model"];
		[newAdvertFields setObject:@"8194" forKey:@"pid"];
		// set the original advert field data as ours
		self.advertisementFields = newAdvertFields;
	}
	return self;
}
// doing the same thing here as above, just want to make sure the fields get modified
-(NSDictionary *)advertisementFields {
	NSDictionary *advertFields = %orig;

	if ([[advertFields objectForKey:@"pid"] longLongValue] == 8207 || [[advertFields objectForKey:@"pid"] longLongValue] == 8194) {

		NSMutableDictionary *newAdvertFields = [advertFields mutableCopy];
		[newAdvertFields setObject:@"AirPods1,1" forKey:@"model"];
		[newAdvertFields setObject:@"8194" forKey:@"pid"];
		return newAdvertFields;
	}

	else return advertFields;
}
%end
// Set the battery field UI as 100% for each device first
%hook ProximityStatusViewControllerProxy
- (_Bool)updateViewForLevelLeft:(double)arg1 levelRight:(double)arg2 levelCase:(double)arg3 {
	return %orig(1, 1, 1);
}
%end

%hook ProximityStatusViewController
%property(nonatomic, assign) double caseCharge;
%property(nonatomic, assign) BOOL caseCharging;

%property(nonatomic, assign) double leftCharge;
%property(nonatomic, assign) BOOL leftCharging;

%property(nonatomic, assign) double rightCharge;
%property(nonatomic, assign) BOOL rightCharging;
%property(nonatomic, assign) BOOL bothCharging;
- (void)_updateBatteryLevelLeft:(double)arg1 levelRight:(double)arg2 levelCase:(double)arg3 {
	// get the battery levels for each device part
	[self getBatteryValues];
	// change the given arguments to our new battery data
	arg1 = self.leftCharge;
	arg2 = self.rightCharge;
	arg3 = self.caseCharge;

	// are the airpods/case charging? we have to manually hide/unhide the charging image as of now
	// actually the case needs improvements - so we're just going to hide the charge icon for now
	if (self.caseCharging) MSHookIvar<UIImageView*>(self, "caseBatteryChargeImageView").alpha = 0;
	else MSHookIvar<UIImageView*>(self, "caseBatteryChargeImageView").alpha = 0;

	if (self.bothCharging) MSHookIvar<UIImageView*>(self, "bothBatteryChargeImageView").alpha = 1;
	else MSHookIvar<UIImageView*>(self, "bothBatteryChargeImageView").alpha = 0;
	%orig;
}
%new
-(void)getBatteryValues {
	// Get an instance of BCBatteryController
	BCBatteryDeviceController *bcb = [%c(BCBatteryDeviceController) sharedInstance];
	// Cycle through the connected devices
	for (BCBatteryDevice *device in bcb.connectedDevices) {
		long long percentCharge = device.percentCharge;
		NSLog(@"%llu", percentCharge);
		// check to see if pid is airpods1,1
		if (device.productIdentifier == 8194) {
			// Part 0 is the default for any bluetooth device, so we ignore it
			// Part 1 is the left airpod
			if (device.parts == 1) {
				if (device.percentCharge != 0) self.leftCharge = ((double)device.percentCharge / 100);
				if (device.charging) self.leftCharging = YES;
			}
			// Part 2 is the right airpod
			else if (device.parts == 2) {
				if (device.percentCharge != 0) self.rightCharge = ((double)device.percentCharge / 100);
				if (device.charging) self.rightCharging = YES;
			}
			// Part 3 is both airpods (this is used when they both have the same charge)
			else if (device.parts == 3) {
				if (device.percentCharge != 0) self.leftCharge = ((double)device.percentCharge / 100);;
				if (device.percentCharge != 0) self.rightCharge = ((double)device.percentCharge / 100);;
				if (device.charging) self.bothCharging = YES;
			}
			// Part 4 is the case
			else if (device.parts == 4) {
				if (device.percentCharge != 0) self.caseCharge = ((double)device.percentCharge / 100);
				if (device.charging) self.caseCharging = YES;
			}
		}
	}
}
%end

%hook ProximityPairingViewController
%property(nonatomic, assign) double caseCharge;
%property(nonatomic, assign) BOOL caseCharging;

%property(nonatomic, assign) double leftCharge;
%property(nonatomic, assign) BOOL leftCharging;

%property(nonatomic, assign) double rightCharge;
%property(nonatomic, assign) BOOL rightCharging;
%property(nonatomic, assign) BOOL bothCharging;
-(void)viewDidDisappear:(BOOL)arg1 {
	%orig;
	postPair = NO;
}
- (void)_updateBatteryUIForDevice:(id)arg1 {
	%orig;
	/* This isn't actually working properly yet, this method originally gets the battery levels via SFBatteryInfo 
	(but 2nd gen airpods don't advertise their battery levels properly to SFBatteryInfo)
	I'll have to go back and see if I can just change all the battery data in SFBatteryInfo so it's a much more streamlined process*/
	NSMutableDictionary *newUserInfo = [self.userInfo mutableCopy];
	long long pid = [[newUserInfo objectForKey:@"pid"] longLongValue];
	if (pid == 8194) {
		// Get a copy of the user info
		// make sure pid is airpods1,1
		if (postPair) {
			// get the proper battery values
			[self getBatteryValues];
			// set the proper value for each battery
			NSString *caseStr = [NSString stringWithFormat:@"%.2f", self.caseCharge];
			NSString *leftStr = [NSString stringWithFormat:@"%.2f", self.leftCharge];
			NSString *rightStr = [NSString stringWithFormat:@"%.2f", self.rightCharge];
			
			[newUserInfo setObject:rightStr forKey:@"batteryLevelRight"];
			[newUserInfo setObject:leftStr forKey:@"batteryLevelLeft"];
			[newUserInfo setObject:caseStr forKey:@"batteryLevelCase"];
		} else {
			// Set these values as 100%, since we don't have the proper battery value until after post pair
			[newUserInfo setObject:@"-1.0" forKey:@"batteryLevelRight"];
			[newUserInfo setObject:@"-1.0" forKey:@"batteryLevelLeft"];
			[newUserInfo setObject:@"-1.0" forKey:@"batteryLevelCase"];
		}
		self.userInfo = newUserInfo;
	}
}
- (void)_transitionToStatusFadeInSplit {
	// are the airpods/case charging? we have to manually hide/unhide the charging image as of now
	// actually the case needs improvements - so we're just going to hide the charge icon for now
	if (self.caseCharging) MSHookIvar<UIImageView*>(self, "_caseBatteryChargeImageView").hidden = YES;
	else MSHookIvar<UIImageView*>(self, "_caseBatteryChargeImageView").hidden = YES;

	if (self.bothCharging) MSHookIvar<UIImageView*>(self, "_budsBatteryChargeImageView").hidden = YES;
	else MSHookIvar<UIImageView*>(self, "_budsBatteryChargeImageView").hidden = NO;

	// Only update the battery value once the device is paired
	postPair = YES;
	%orig;
}
%new
-(void)getBatteryValues {
	// Get an instance of BCBatteryController
	BCBatteryDeviceController *bcb = [%c(BCBatteryDeviceController) sharedInstance];
	// Cycle through the connected devices
	for (BCBatteryDevice *device in bcb.connectedDevices) {
		// check to see if pid is airpods1,1
		if (device.productIdentifier == 8194) {
			// Part 0 is the default for any bluetooth device, so we ignore it
			// Part 1 is the left airpod
			if (device.parts == 1) {
				// The pairing view needs these to be negative
				if (device.percentCharge != 0) self.leftCharge = -((double)device.percentCharge / 100);
				if (device.charging) self.leftCharging = YES;
			}
			// Part 2 is the right airpod
			else if (device.parts == 2) {
				if (device.percentCharge != 0) self.rightCharge = -((double)device.percentCharge / 100);
				if (device.charging) self.rightCharging = YES;
			}
			// Part 3 is both airpods (this is used when they both have the same charge)
			else if (device.parts == 3) {
				if (device.percentCharge != 0) self.leftCharge = -((double)device.percentCharge / 100);
				if (device.percentCharge) self.rightCharge = -((double)device.percentCharge / 100);
				if (device.charging) self.bothCharging = YES;
			}
			// Part 4 is the case
			else if (device.parts == 4) {
				if (device.percentCharge != 0) self.caseCharge = -((double)device.percentCharge / 100);
				if (device.charging) self.caseCharging = YES;
			}
		}
	}
}
%end
%end

%group AirPortCustomAnim11
%hook ProximityStatusViewController
-(void)viewWillAppear:(id)arg1 {
	%orig;
	// Get our prefs data
	HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"com.boo.airport"];
	// Get the path of selected custom anim, defaults to the original anim
	NSString *customAnimPath = [([prefs objectForKey:@"customAnimPath"] ?: @"file:///Library/AirPortAnims/Default/") stringValue];
	// Initial darkmode support
	bool useDarkMode = [([prefs objectForKey:@"useDarkMode"] ?: @(NO)) boolValue];
	if (useDarkMode) {
		// set the path to our custom anim
		customAnimPath = @"file:///Library/Application%20Support/AirPort/DarkMode/";
		// loop through all the subviews to make sure everything is black
		for (UIView *subview in self.view.subviews) {
			subview.backgroundColor = [UIColor blackColor];
			for (UIView *sub in subview.subviews) {
				sub.backgroundColor = [UIColor blackColor];
			}
		}
	}

	// Change the path to our new path
	MSHookIvar<NSString *>(self, "_movieStatusLoopName") = [customAnimPath stringByAppendingString:@"/ProxCard_loop.mov"];
	// Change the asset to our new movie asset
	AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:MSHookIvar<NSString *>(self, "_movieStatusLoopName")]];
	// Done!
	MSHookIvar<AVPlayerItem *>(self, "_avItemLoop") = [[AVPlayerItem alloc] initWithAsset:asset];
}
%end
%end

%group AirPortCustomAnim12
%hook ProximityStatusViewController
- (void)viewWillAppear:(_Bool)arg1 {	
	%orig;

	// Get our prefs data
	HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"com.boo.airport"];
	// Get the path of selected custom anim, defaults to the original anim
	NSString *customAnimPath = [([prefs objectForKey:@"customAnimPath"] ?: @"file:///Library/AirPortAnims/Default/") stringValue];
	// Initial darkmode support
	bool useDarkMode = [([prefs objectForKey:@"useDarkMode"] ?: @(NO)) boolValue];
	if (useDarkMode) {
		// set the path to our custom anim
		customAnimPath = @"file:///Library/Application%20Support/AirPort/DarkMode/";
		// loop through all the subviews to make sure everything is black
		for (UIView *subview in self.view.subviews) {
			subview.backgroundColor = [UIColor blackColor];
			for (UIView *sub in subview.subviews) {
				sub.backgroundColor = [UIColor blackColor];
			}
		}
	}

	// Change the path to our new path
	MSHookIvar<NSString *>(self, "_movieStatusLoopName") = [customAnimPath stringByAppendingString:@"/ProxCard_loop.mov"];
	// Change the asset to our new movie asset
	AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:MSHookIvar<NSString *>(self, "_movieStatusLoopName")]];
	// Done!
	MSHookIvar<AVPlayerItem *>(self, "_avItemLoop") = [[AVPlayerItem alloc] initWithAsset:asset];
}
%end
//This isn't working fully yet, we'll fix it later, pairing view is a bitch compared to the status view
/*
%hook ProximityPairingViewController
- (void)viewDidAppear:(BOOL)arg1 {
	%orig;
	// Get our prefs data
	HBPreferences *prefs = [[HBPreferences alloc] initWithIdentifier:@"com.boo.airport"];
	// Get the path of selected custom anim, defaults to the original
	NSString *customAnimPath = [([prefs objectForKey:@"customAnimPath"] ?: @"/Library/AirPortAnims/Default/") stringValue];
	// Change the path to our new path
	MSHookIvar<NSString *>(self, "_movieStatusLoopName") = 	[customAnimPath stringByAppendingString:@"/ProxCard_loop.mov"];
	// Change the asset to our new movie asset
	AVAsset *asset = [AVAsset assetWithURL:[NSURL URLWithString:MSHookIvar<NSString *>(self, "_movieStatusLoopName")]];
	// Done!
	MSHookIvar<AVPlayerItem *>(self, "_avItemStatusLoop") = [[AVPlayerItem alloc] initWithAsset:asset];
}
%end*/

%end

// ty @nepetadev for the ez piracy detection
%group AirPortPiracyWarning

%hook SpringBoard

-(void)applicationDidFinishLaunching:(id)arg1 {
    %orig;
	if (!dpkgInvalid) return;
    UIAlertController *alertController = [UIAlertController
        alertControllerWithTitle:@"Uh-Oh!"
        message:@"This version of AirPort has been downloaded from an untrusted source.\nPlease download AirPort from:\nhttps://repo.packix.com/"
        preferredStyle:UIAlertControllerStyleAlert
    ];

    [alertController addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
        [((UIApplication*)self).keyWindow.rootViewController dismissViewControllerAnimated:YES completion:NULL];
    }]];

    [((UIApplication*)self).keyWindow.rootViewController presentViewController:alertController animated:YES completion:NULL];
}

%end
%end

%ctor {
	// ty @nepetadev
	dpkgInvalid = ![[NSFileManager defaultManager] fileExistsAtPath:@"/var/lib/dpkg/info/com.boo.airport.list"];
	if (dpkgInvalid) %init(AirPortPiracyWarning);
	bool enabled;
	bool airpod2Support;
	NSString *ver = [[UIDevice currentDevice] systemVersion];
	float ver_float = [ver floatValue];

    NSString *processName = [NSProcessInfo processInfo].processName;
	// we have to check the process because for some reason sharingd does not play nicely with Cephei
	if ([processName isEqualToString:@"sharingd"] && ver_float < 12.2) {
		// as stated above, we have to 'manually' load the data into a dictionary
		NSMutableDictionary *prefs = [[NSMutableDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.boo.airport.plist"];
  		enabled = [([prefs objectForKey:@"Enabled"] ?: @(YES)) boolValue];
		airpod2Support = [([prefs objectForKey:@"airpod2Support"] ?: @(YES)) boolValue];
	} else {
		HBPreferences *prefs = [[HBPreferences 
		alloc] initWithIdentifier:@"com.boo.airport"];
  		enabled = [([prefs objectForKey:@"Enabled"] ?: @(YES)) boolValue];
		airpod2Support = [([prefs objectForKey:@"airpod2Support"] ?: @(YES)) boolValue];
		if (enabled) {
			bool customAnim = [([prefs objectForKey:@"useCustomAnim"] ?: @(NO)) boolValue];
			bool useAnimFix = [([prefs objectForKey:@"useAnimFix"] ?: @(YES)) boolValue];
			bool useDarkMode = [([prefs objectForKey:@"useDarkMode"] ?: @(NO)) boolValue];
			if (customAnim || useDarkMode) {
				if ( ver_float > 12.0 ) %init(AirPortCustomAnim12);
				else if ( ver_float > 11.0 ) %init(AirPortCustomAnim11);
			}
			if (useAnimFix) %init(AirPortAnimFix);
		}
	}
	if (enabled) {
		if (airpod2Support) %init(AirPortSupport);
	}
}