//
//  DownloadManager.m
//  edXVideoLocker
//
//  Created by Abhishek Bhagat on 10/11/14.
//  Copyright (c) 2014 edX. All rights reserved.
//

#import "OEXDownloadManager.h"

#import "edX-Swift.h"
#import "Logger+OEXObjC.h"
#import <AVFoundation/AVFoundation.h>
#import <Crashlytics/Crashlytics.h>
#import "OEXAnalytics.h"
#import "OEXAppDelegate.h"
#import "OEXFileUtility.h"
#import "OEXInterface.h"
#import "OEXNetworkConstants.h"
#import "OEXSession.h"
#import "OEXStorageInterface.h"
#import "OEXStorageFactory.h"
#import "OEXUserDetails.h"

static OEXDownloadManager* _downloadManager = nil;

#define VIDEO_BACKGROUND_DOWNLOAD_SESSION_KEY @"com.edx.videoDownloadSession"

static AVAssetDownloadURLSession* videosBackgroundSession = nil;

@interface OEXDownloadManager () <AVAssetDownloadDelegate>
{
}
@property(nonatomic, weak) id <OEXStorageInterface>storage;
@property(nonatomic, strong) NSMutableDictionary* dictVideoData;
@property(nonatomic, assign) BOOL isActive;
@end
@implementation OEXDownloadManager

+ (OEXDownloadManager*)sharedManager {
    if(!_downloadManager || [_downloadManager isKindOfClass:[NSNull class]]) {
        _downloadManager = nil;
        _downloadManager = [[OEXDownloadManager alloc] init];
        [_downloadManager initializeSession];
    }
    return _downloadManager;
}

- (void)initializeSession {
    NSURLSessionConfiguration* backgroundConfiguration = [NSURLSessionConfiguration backgroundSessionConfigurationWithIdentifier:VIDEO_BACKGROUND_DOWNLOAD_SESSION_KEY];

    backgroundConfiguration.allowsCellularAccess = YES;

    //Session
    videosBackgroundSession = [AVAssetDownloadURLSession sessionWithConfiguration:backgroundConfiguration
                                                            assetDownloadDelegate:self
                                                                    delegateQueue:[NSOperationQueue mainQueue]];
    _dictVideoData = [[NSMutableDictionary alloc] init];
    _isActive = YES;
}

- (id <OEXStorageInterface>)storage {
    if(_isActive) {
        return [OEXStorageFactory getInstance];
    }
    else {
        return nil;
    }
}

- (void)activateDownloadManager {
    _isActive = YES;
}

- (void)deactivateWithCompletionHandler:(void (^)(void))completionHandler {
    [self.storage pausedAllDownloads];
    _isActive = NO;
    [self pauseAllDownloadsForUser:[OEXSession sharedSession].currentUser.username completionHandler:^{
        // [videosBackgroundSession invalidateAndCancel];
        // _downloadManager=nil;
        completionHandler();
    }];
}

- (void)resumePausedDownloads {
    // FIXME JV - does this still work?
    OEXLogInfo(@"DOWNLOADS", @"Resuming Paused downloads");
    CLS_LOG(@"resumePausedDownloads");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSArray* array = [self.storage getVideosForDownloadState:OEXDownloadStatePartial];
        CLS_LOG(@"resumePausedDownloads: videos get successfully");
        for(VideoData* data in array) {
            NSString* file = [OEXFileUtility filePathForVideo:data];
            if([[NSFileManager defaultManager] fileExistsAtPath:file]) {
                data.download_state = [NSNumber numberWithInt:OEXDownloadStateComplete];
                continue;
            }
            [self downloadVideoForObject:data withCompletionHandler:^(NSURLSessionTask* downloadTask) {
                    if(downloadTask) {
                        CLS_LOG(@"resumePausedDownloads: downloadTask");
                        data.dm_id = [NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier];
                        CLS_LOG(@"resumePausedDownloads: get data.dm_id successfully");
                    }
                    else {
                        data.dm_id = [NSNumber numberWithInt:0];
                    }
                }];
        }
        [self.storage saveCurrentStateToDB];
        CLS_LOG(@"resumePausedDownloads: saveCurrentStateToDB successfully");
    });
}

//Start Download for video
- (void)downloadVideoForObject:(VideoData*)video withCompletionHandler:(void (^)(NSURLSessionTask* downloadTask))completionHandler {
    CLS_LOG(@"downloadVideoForObject");
    [self checkIfVideoIsDownloading:video withCompletionHandler:completionHandler];
}

// Start Download for video Url
- (void)checkIfVideoIsDownloading:(VideoData*)video withCompletionHandler:(void (^)(NSURLSessionTask* downloadTask))completionHandler {
    CLS_LOG(@"checkIfVideoIsDownloading");
    //Check if null
    if(!video.video_url || [video.video_url isEqualToString:@""]) {
        OEXLogError(@"DOWNLOADS", @"Download Manager Empty/Corrupt URL, ignoring");
        video.download_state = [NSNumber numberWithInt: OEXDownloadStateNew];
        video.dm_id = [NSNumber numberWithInt:0];
        [self.storage saveCurrentStateToDB];
        CLS_LOG(@"checkIfVideoIsDownloading: saveCurrentStateToDB successfully");
        completionHandler(nil);
        return;
    }

    [videosBackgroundSession getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        CLS_LOG(@"checkIfVideoIsDownloading: getTasksWithCompletionHandler");
        //Check if already downloading
        BOOL alreadyInProgress = NO;
        __block NSInteger taskIndex = NSNotFound;
        for(int ii = 0; ii < [downloadTasks count]; ii++) {
            AVAssetDownloadTask* downloadTask = [downloadTasks objectAtIndex:ii];
            NSURL* existingURL = downloadTask.URLAsset.URL;
            if([video.video_url isEqualToString:[existingURL absoluteString]]) {
                alreadyInProgress = YES;
                taskIndex = ii;
                break;
            }
        }
        if(alreadyInProgress) {
            AVAssetDownloadTask* downloadTask = [downloadTasks objectAtIndex:taskIndex];
            video.download_state = [NSNumber numberWithInt:OEXDownloadStatePartial];
            video.dm_id = [NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier];
            [self.storage saveCurrentStateToDB];
            CLS_LOG(@"checkIfVideoIsDownloading: saveCurrentStateToDB successfully");
            completionHandler(downloadTask);
        }
        else {
            [self startDownloadForVideo:video WithCompletionHandler:completionHandler];
        }
    }];
}

- (void)saveDownloadTaskIdentifier:(NSInteger )taskIdentifier forVideo:(VideoData*)video {
    video.dm_id = [NSNumber numberWithUnsignedInteger:taskIdentifier];
    [self.storage saveCurrentStateToDB];
}

- (void)startDownloadForVideo:(VideoData*)video WithCompletionHandler:(void (^)(NSURLSessionTask* downloadTask))completionHandler {
    CLS_LOG(@"startDownloadForVideo");
    NSURLSessionTask* downloadTask = [self startBackgroundDownloadForVideo:video];
    CLS_LOG(@"startDownloadForVideo: downloadTask");
    completionHandler(downloadTask);
}

- (NSData*)resumeDataForURLString:(NSString*)URLString {
    // FIXME JV - still needed?
    NSString* filePath = [OEXFileUtility filePathForVideoURL:URLString];

    NSData* data = [NSData dataWithContentsOfFile:filePath];
    return data;
}

- (BOOL )writeData:(NSData*)data atFilePath:(NSString*)filePath {
    // FIXME JV - still needed?
    //check if file already exists, delete it
    if([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
        NSError* error;
        if([[NSFileManager defaultManager] isDeletableFileAtPath:filePath]) {
            BOOL success = [[NSFileManager defaultManager] removeItemAtPath:filePath error:&error];
            if(!success) {
                //NSLog(@"Error removing file at path: %@", error.localizedDescription);
            }
        }
    }

    //write new file
    if(![data writeToFile:filePath atomically:YES]) {
        OEXLogError(@"DOWNLOADS", @"There was a problem saving resume data to file ==>> %@", filePath);
        return NO;
    }

    return YES;
}

- (NSURLSessionTask*)startBackgroundDownloadForVideo:(VideoData*)video {

    //Asset url
    NSURL* url = [NSURL URLWithString:video.video_url];
    AVURLAsset* avAsset = [AVURLAsset assetWithURL:url];

    //Task
    AVAssetDownloadTask* downloadTask = nil;
    //Check if already exists

    /* JV FIXME: resume not working with iOS 10?
       cf https://stackoverflow.com/q/39346231/4302112
       Also unsure if this works with AVAssetDownloadTasks:
       cf https://forums.developer.apple.com/thread/66485
    OEXDownloadState state = [video.download_state intValue];
    if(state == OEXDownloadStatePartial) {
        if(video) {
            // Get resume data
            NSData* resumedata = [self resumeDataForURLString:video.video_url];
            if(resumedata && ![resumedata isKindOfClass:[NSNull class]]) {
                OEXLogError(@"DOWNLOADS", @"Download resume for video %@ with resume data", video.title);
                downloadTask = [videosBackgroundSession downloadTaskWithResumeData:resumedata];
            }
            else {
                downloadTask = [videosBackgroundSession assetDownloadTaskWithURLAsset:avAsset
                                                                           assetTitle:video.title
                                                                     assetArtworkData:nil
                                                                              options:nil];
            }
        }
        //If not, start a fresh download
        else {
            downloadTask = [videosBackgroundSession assetDownloadTaskWithURLAsset:avAsset
                                                                       assetTitle:video.title
                                                                 assetArtworkData:nil
                                                                          options:nil];
        }
    }
    else {
    */
        downloadTask = [videosBackgroundSession assetDownloadTaskWithURLAsset:avAsset
                                                                   assetTitle:video.title
                                                             assetArtworkData:nil
                                                                      options:nil];
    // }

    //Update DB
    video.download_state = [NSNumber numberWithInt: OEXDownloadStatePartial];
    video.dm_id = [NSNumber numberWithUnsignedInteger:downloadTask.taskIdentifier];
    [self.storage saveCurrentStateToDB];
    [downloadTask resume];
    return downloadTask;
}

- (void)cancelDownloadForVideo:(VideoData*)video completionHandler:(void (^)(BOOL success))completionHandler {
    //// Check if two downloading  video refer to same download task
    /// If YES then just change the  state for video that we wqnt to cancel download .

    NSArray* array = [self.storage getVideosForDownloadUrl:video.video_url];
    int refcount = 0;
    for(VideoData* objVideo in array) {
        if([objVideo.download_state intValue] == OEXDownloadStatePartial) {
            refcount++;
        }
    }
    if(refcount >= 2) {
        [self.storage cancelledDownloadForVideo:video];
        completionHandler(YES);
        return;
    }

    //Cancel downloading videos

    [videosBackgroundSession getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        BOOL found = NO;

        for(int ii = 0; ii < [downloadTasks count]; ii++) {
            AVAssetDownloadTask* downloadTask = [downloadTasks objectAtIndex:ii];
            NSURL* existingURL = downloadTask.URLAsset.URL;

            if([video.video_url isEqualToString:[existingURL absoluteString]]) {
                found = YES;
                [downloadTask cancel];
                [self.storage cancelledDownloadForVideo:video];
                completionHandler(YES);
                break;
            }
        }
        if(!found) {
            [self.storage cancelledDownloadForVideo:video];
            completionHandler(NO);
        }
    }];
}

- (void)cancelAllDownloadsForUser:(NSString*)user completionHandler:(void (^)(void))completionHandler {
    [videosBackgroundSession getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        for(int ii = 0; ii < [downloadTasks count]; ii++) {
            AVAssetDownloadTask* task = [downloadTasks objectAtIndex:ii];
            [task cancel];
        }
        NSArray* array = [self.storage getVideosForDownloadState:OEXDownloadStatePartial];
        for(VideoData * video in array) {
            video.download_state = [NSNumber numberWithInt: OEXDownloadStateNew];
            video.dm_id = [NSNumber numberWithInt:0];
        }
        [self.storage saveCurrentStateToDB];
        completionHandler();
    }];
}

- (void)pauseAllDownloadsForUser:(NSString*)user completionHandler:(void (^)(void))completionHandler {
    _delegate = nil;
    [videosBackgroundSession getTasksWithCompletionHandler:^(NSArray* dataTasks, NSArray* uploadTasks, NSArray* downloadTasks) {
        __block int cancelledCount = 0;
        __block void (^ handler)(void) = [completionHandler copy];
        __block int taskCount = (int)[downloadTasks count];

        for(int ii = 0; ii < [downloadTasks count]; ii++) {
            __block AVAssetDownloadTask* task = [downloadTasks objectAtIndex:ii];
            [task cancel];
            cancelledCount++;
            if(cancelledCount == taskCount) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    handler();
                });
            }
        }

        if([downloadTasks count] == 0) {
            completionHandler();
        }
    }];
}

+ (void)clearDownloadManager {
    [_downloadManager cancelAllDownloadsForUser:[OEXSession sharedSession].currentUser.username completionHandler:^{
        _downloadManager = nil;
    }];
    _downloadManager = nil;
}

#pragma Download Task Delegte

- (BOOL)isValidSession:(NSURLSession*)session {
    if(session == videosBackgroundSession) {
        return YES;
    }
    return NO;
}

#pragma NSURLSession Delegate

- (void)URLSession:(NSURLSession*)session didBecomeInvalidWithError:(NSError*)error {
}

- (void)URLSessionDidFinishEventsForBackgroundURLSession:(NSURLSession*)session {
    if(session.configuration.identifier) {
        [self invokeBackgroundSessionCompletionHandlerForSession:session];
    }
}

- (void)invokeBackgroundSessionCompletionHandlerForSession:(NSURLSession*)session {
    if(![self isValidSession:session]) {
        return;
    }
    dispatch_async(dispatch_get_main_queue(), ^{
        OEXAppDelegate* appDelegate = (OEXAppDelegate*)[[UIApplication sharedApplication] delegate];
        [appDelegate callCompletionHandlerForSession:session.configuration.identifier];
    });
}

#pragma mark AVAssetDownloadDelegate

- (void)           URLSession:(NSURLSession *)session
            assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask
    didFinishDownloadingToURL:(NSURL *)location {

    if(!session.configuration.identifier) {
        return;
    }

    OEXLogInfo(@"DOWNLOADS", @"Download complete delegate get called ");

    __block NSData* data = [NSData dataWithContentsOfURL:location];
    if(!data) {
        OEXLogInfo(@"DOWNLOADS", @"Data is Null for downloaded file. Location ==>> %@ ", location);
        // TODO JV - remove item(s) at location.relativePath?
    }

    OEXLogInfo(@"DOWNLOADS", @"Downloaded Video saved at ==>> %@", location.relativePath);

    __block NSString* downloadUrl = [assetDownloadTask.URLAsset.URL absoluteString];

    NSArray* videos = [self.storage getAllDownloadingVideosForURL:downloadUrl];
    for(VideoData* videoData in videos) {
        OEXLogInfo(@"DOWNLOADS", @"Updating record for Downloaded Video ==>> %@", videoData.title);

        // Store the downloaded asset location, because AVAssets cannot be moved once downloaded.
        videoData.asset_path = location.path;

        [[OEXAnalytics sharedAnalytics] trackDownloadComplete:videoData.video_id CourseID:videoData.enrollment_id UnitURL:videoData.unit_url];

        [self.storage completedDownloadForVideo:videoData];
    }

    //// Dont notify to ui if app is running in background
    if([[UIApplication sharedApplication] applicationState] == UIApplicationStateActive) {
        OEXLogInfo(@"DOWNLOADS", @"Sending download complete");

        //notify
        [[NSNotificationCenter defaultCenter] postNotificationName:OEXDownloadEndedNotification
                                                            object:self
                                                          userInfo:@{VIDEO_DL_COMPLETE_N_TASK: assetDownloadTask}];
    }
    [self invokeBackgroundSessionCompletionHandlerForSession:session];
}

- (void)         URLSession:(NSURLSession *)session
          assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask
           didLoadTimeRange:(CMTimeRange)timeRange
      totalTimeRangesLoaded:(NSArray<NSValue *> *)loadedTimeRanges
    timeRangeExpectedToLoad:(CMTimeRange)timeRangeExpectedToLoad {

    if(![self isValidSession:session]) {
        return;
    }

    double progress = 0;
    for (NSValue *value in loadedTimeRanges) {
        CMTimeRange timeRange = [value CMTimeRangeValue];
        progress += CMTimeGetSeconds(timeRange.duration) / CMTimeGetSeconds(timeRangeExpectedToLoad.duration);
    }
    OEXLogInfo(@"DOWNLOADS", @"Progress: %ld", (long)(progress*100));

    // TODO JV ???
    ///Update progress only when application is active

    //    if([[UIApplication sharedApplication] applicationState] ==UIApplicationStateActive){
    //
    NSDictionary* userInfo = @{DOWNLOAD_PROGRESS_NOTIFICATION_TASK_URL: [assetDownloadTask.URLAsset.URL absoluteString],
                               DOWNLOAD_PROGRESS_NOTIFICATION_TOTAL_COMPLETED: [NSNumber numberWithDouble:(double)progress]};
    dispatch_async(dispatch_get_main_queue(), ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:DOWNLOAD_PROGRESS_NOTIFICATION
                                                            object:nil
                                                          userInfo:userInfo];
    });
}

- (void)          URLSession:(NSURLSession *)session
           assetDownloadTask:(AVAssetDownloadTask *)assetDownloadTask
    didResolveMediaSelection:(AVMediaSelection *)resolvedMediaSelection {
    OEXLogInfo(@"DOWNLOADS", @"resolved media selection ==>> %@ ", [[[assetDownloadTask URLAsset] URL] absoluteString]);
}

- (void)      URLSession:(NSURLSession *)session
                    task:(NSURLSessionTask *)task
    didCompleteWithError:(NSError *)error {

    OEXLogInfo(@"DOWNLOADS", @" Download failed with error ==>>%@ ", [error localizedDescription]);
    if([task isKindOfClass:[AVAssetDownloadURLSession class]]) {
        if(error) {
            OEXLogInfo(@"DOWNLOADS", @"%@ download failed with error ==>> %@ ", [[[task originalRequest] URL] absoluteString], [error localizedDescription]);
            //  if([self.delegate respondsToSelector:@selector(downloadTask:didCompleteWithError:)]){
            //      [self.delegate downloadTask:task didCompleteWithError:error];
            //  }
        }
    }
}

@end

