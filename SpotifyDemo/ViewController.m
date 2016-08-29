//
//  ViewController.m
//  SpotifyDemo
//
//  Created by Arthur Tonelli on 7/21/16.
//  Copyright © 2016 Arthur Tonelli. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *albumLabel;
@property (weak, nonatomic) IBOutlet UILabel *artistLabel;
@property (weak, nonatomic) IBOutlet UIImageView *coverView;
@property (weak, nonatomic) IBOutlet UIImageView *coverView2;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@property (nonatomic, strong) SPTAudioStreamingController *player;


@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    self.titleLabel.text = @"Nothing Playing";
    self.albumLabel.text = @"";
    self.artistLabel.text = @"";
    
}

-(BOOL)prefersStatusBarHidden{
    return YES;
}

#pragma mark - Actions

- (IBAction)rewind:(id)sender {
    [self.player skipPrevious:nil];
}

- (IBAction)playPause:(id)sender {
    [self.player setIsPlaying:!self.player.isPlaying callback:nil];
}

- (IBAction)fastForward:(id)sender {
    [self.player skipNext:nil];
}

- (IBAction)logoutClicked:(id)sender {
    if (self.player){
        [self.player logout];
    } else {
        [self.navigationController popViewControllerAnimated:YES];
    }
}

#pragma mark - Logic

-(UIImage *)applyBlurOnImage: (UIImage *)imageToBlur
                  withRadius: (CGFloat)blurRadius{
    
    CIImage *originalImage = [CIImage imageWithCGImage:imageToBlur.CGImage];
    CIFilter *filter = [CIFilter filterWithName:@"CIGaussianBlur" keysAndValues:kCIInputImageKey, originalImage, @"inputRadius",@(blurRadius),nil];
    CIImage *outputImage = filter.outputImage;
    CIContext *context = [CIContext contextWithOptions:nil];
    
    CGImageRef outImage = [context createCGImage: outputImage fromRect:[outputImage extent]];
    
    UIImage *ret = [UIImage imageWithCGImage:outImage];
    
    CGImageRelease(outImage);
    
    return ret;
    
}

-(void)updateUI {
    
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    if(self.player.currentTrackURI == nil){
        self.coverView.image = nil;
        self.coverView2.image = nil;
        return;
    }
    
    [self.spinner startAnimating];
    
    [SPTTrack trackWithURI:self.player.currentTrackURI session:auth.session callback:^(NSError *error, SPTTrack *track) {
        
        self.titleLabel.text = track.name;
        self.albumLabel.text = track.album.name;
        
        SPTPartialArtist *artist = [track.artists objectAtIndex:0];
        self.artistLabel.text = artist.name;
        
        NSURL *imageURL = track.album.largestCover.imageURL;
        if(imageURL == nil) {
            NSLog(@"Album %@ doesn't have any images!", track.album);
            self.coverView.image = nil;
            self.coverView2.image = nil;
            return;
        }
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            NSError *error = nil;
            UIImage *image = nil;
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL options:0 error:&error];
            
            if (imageData != nil) {
                image = [UIImage imageWithData:imageData];
            }
            
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.spinner stopAnimating];
                self.coverView.image = image;
                if(image == nil){
                    NSLog(@"Couldn't load cover image with error: %@", error);
                    return;
                }
            });
            
            UIImage *blurred = [self applyBlurOnImage:image withRadius:10.0f];
            dispatch_async(dispatch_get_main_queue(), ^{
                self.coverView2.image = blurred;
            });
            
        });
        
        
        
    }];
    
}

-(void)viewDidAppear:(BOOL)animated{
    [super viewDidAppear:animated];
    [self handleNewSession];
}

-(void)handleNewSession {
    SPTAuth *auth = [SPTAuth defaultInstance];
    
    if (self.player == nil){
        NSError *error = nil;
        self.player = [SPTAudioStreamingController sharedInstance];
        if([self.player startWithClientId:auth.clientID error:&error]){
            self.player.delegate = self;
            self.player.playbackDelegate = self;
            self.player.diskCache = [[SPTDiskCache alloc]initWithCapacity:1024 * 1024 * 64];
            [self.player loginWithAccessToken:auth.session.accessToken];
        } else {
            self.player = nil;
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"Error init" message:[error description] preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"Ok" style:UIAlertActionStyleDefault handler:nil]];
            [self presentViewController:alert animated:YES completion:nil];
            [self audioStreamingDidLogout:nil];
            
        }
    }
}

#pragma mark - Track Player Delegates

-(void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didReceiveMessage:(NSString *)message{
    UIAlertView *alertView = [[UIAlertView alloc]initWithTitle:@"Message from Spotify" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alertView show];
}

-(void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didFailToPlayTrack:(NSURL *)trackUri {
    NSLog(@"failed to play track: %@", trackUri);
}

-(void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didChangeToTrack:(NSDictionary *)trackMetadata{
    NSLog(@"track changed = %@", [trackMetadata valueForKey:SPTAudioStreamingMetadataTrackURI]);
    [self updateUI];
}

-(void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didChangePlaybackStatus:(BOOL)isPlaying {
    NSLog(@"is playing = %d", isPlaying);
}

-(void)audioStreaming:(SPTAudioStreamingController *)audioStreaming didEncounterError:(NSError *)error{
    if(error != nil){
        NSLog(@"*** Playback got error: %@",error);
        return;
    }
}

-(void)audioStreamingDidLogin:(SPTAudioStreamingController *)audioStreaming {
    [self updateUI];
    NSString *accessToken = [SPTAuth defaultInstance].session.accessToken;
    NSURL *url = [NSURL URLWithString:@"spotify:user:cariboutheband:playlist:4Dg0J0ICj9kKTGDyFu0Cv4"];
    NSURLRequest *playlistReq = [SPTPlaylistSnapshot createRequestForPlaylistWithURI:url accessToken:accessToken error:nil];
    
    [[SPTRequest sharedHandler]performRequest:playlistReq callback:^(NSError *error, NSURLResponse *response, NSData *data) {
        if (error !=nil) {
            NSLog(@"*** Failed to get playlist %@",error);
            return;
        }
        
        SPTPlaylistSnapshot *playlistSnapshot = [SPTPlaylistSnapshot playlistSnapshotFromData:data withResponse:response error:nil];
        [self.player playURIs:playlistSnapshot.firstTrackPage.items fromIndex:0 callback:nil];
    }];
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
