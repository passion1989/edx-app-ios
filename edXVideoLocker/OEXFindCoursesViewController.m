//
//  OEXFindCoursesViewController.m
//  edXVideoLocker
//
//  Created by Abhradeep on 02/02/15.
//  Copyright (c) 2015 edX. All rights reserved.
//

#import "OEXFindCoursesViewController.h"
#import "OEXDownloadViewController.h"
#import "OEXCourseInfoViewController.h"
#import "OEXAppDelegate.h"
#import "OEXEnrollmentConfig.h"
#import "OEXConfig.h"
#import <MessageUI/MessageUI.h>
#import "OEXFindCourseInterstitialViewController.h"

#define kFindCoursesScreenName @"Find Courses"

@interface OEXFindCoursesViewController () <SWRevealViewControllerDelegate, MFMailComposeViewControllerDelegate, OEXFindCourseInterstitialViewControllerDelegate>

@property (strong, nonatomic) IBOutlet UIButton *overlayButton;
@property (strong, nonatomic) NSString *findCoursesURLString;

@end

@implementation OEXFindCoursesViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.findCoursesURLString = [[[OEXConfig sharedConfig] courseEnrollmentConfig] searchURL];
    
    if (self.revealViewController) {
        self.revealViewController.delegate = self;
        [self.view addGestureRecognizer:self.revealViewController.panGestureRecognizer];
    }
    
    self.overlayButton.alpha = 0.0f;
    
    if (![[[OEXConfig sharedConfig] courseEnrollmentConfig] enabled]) {
        OEXFindCourseInterstitialViewController *interstitialViewController = [[OEXFindCourseInterstitialViewController alloc] init];
        interstitialViewController.delegate = self;
        [self.view addSubview:interstitialViewController.view];
        [self.view bringSubviewToFront:self.overlayButton];
        [self addChildViewController:interstitialViewController];
    }
    else{
        if (self.dataInterface.reachable) {
            [self.webViewHelper loadWebViewWithURLString:self.findCoursesURLString];
        }
    }
}

-(void)reachabilityDidChange:(NSNotification *)notification{
    [super reachabilityDidChange:notification];
    if ([[[OEXConfig sharedConfig] courseEnrollmentConfig] enabled] && self.dataInterface.reachable && !self.webViewHelper.isWebViewLoaded) {
        [self.webViewHelper loadWebViewWithURLString:self.findCoursesURLString];
    }
}

-(void)setExclusiveTouches{
    [super setExclusiveTouches];
    self.overlayButton.exclusiveTouch=YES;
}

-(void)setNavigationBar{
    [super setNavigationBar];
    
    self.customNavView.lbl_TitleView.text = kFindCoursesScreenName;
    for (UIView *view in self.customNavView.subviews) {
        if ([view isKindOfClass:[UIButton class]]) {
            [((UIButton *)view) setImage:nil forState:UIControlStateNormal];
        }
    }
    [self.customNavView.btn_Back setImage:[UIImage imageNamed:@"ic_navigation.png"] forState:UIControlStateNormal ];
    [self.customNavView.btn_Back setFrame:CGRectMake(8, 31, 22, 22)];
    [self.customNavView.btn_Back addTarget:self action:@selector(backNavigationPressed) forControlEvents:UIControlEventTouchUpInside];
}

- (void)backNavigationPressed{
    self.view.userInteractionEnabled=NO;
    self.overlayButton.hidden = NO;
    [self.navigationController popToViewController:self animated:NO];
    [UIView animateWithDuration:0.9 animations:^{
        self.overlayButton.alpha = 0.5;
    }];
    [self performSelector:@selector(toggleReveal) withObject:nil afterDelay:0.2];
}

-(void)toggleReveal{
    [self.revealViewController revealToggle:self.customNavView.btn_Back];
}

- (IBAction)overlayButtonTapped:(id)sender {
    [self.revealViewController revealToggleAnimated:YES];
}

- (void)revealController:(SWRevealViewController *)revealController didMoveToPosition:(FrontViewPosition)position{
    self.view.userInteractionEnabled=YES;
    
    if (position == FrontViewPositionLeft){
        [UIView animateWithDuration:0.2 delay:0.0 options:0 animations:^{
            self.overlayButton.alpha = 0.0f;
        } completion:^(BOOL finished) {
            self.overlayButton.hidden = YES;
        }];

        OEXAppDelegate *appDelegate = (OEXAppDelegate *)[[UIApplication sharedApplication] delegate];
        if (appDelegate.pendingMailComposerLaunch) {
            appDelegate.pendingMailComposerLaunch = NO;
            if (![MFMailComposeViewController canSendMail]) {
                [[[UIAlertView alloc] initWithTitle:NSLocalizedString(@"EMAIL_ACCOUNT_NOT_SET_UP_TITLE", nil)
                                            message:NSLocalizedString(@"EMAIL_ACCOUNT_NOT_SET_UP_MESSAGE", nil)                                         delegate:nil
                                  cancelButtonTitle:NSLocalizedString(@"OK", nil)
                                  otherButtonTitles:nil] show];
            }
            else{
                MFMailComposeViewController * mailComposer = [[MFMailComposeViewController alloc] init];
                [mailComposer setMailComposeDelegate:self];
                [mailComposer setSubject:@"Customer Feedback"];
                [mailComposer setMessageBody:@"" isHTML:NO];
                NSString* feedbackAddress = [OEXConfig sharedConfig].feedbackEmailAddress;
                if(feedbackAddress != nil) {
                    [mailComposer setToRecipients:@[feedbackAddress]];
                }
                [self presentViewController:mailComposer animated:YES completion:nil];
            }
        }
    }
    else if (position == FrontViewPositionRight){
        self.overlayButton.hidden = NO;
        [self.navigationController popToViewController:self animated:NO];
        [UIView animateWithDuration:0.5 delay:0 options:0 animations:^{
            self.overlayButton.alpha = 0.5f;
        } completion:^(BOOL finished) {
            
        }];
    }
}

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError *)error{
    [self dismissViewControllerAnimated:YES completion:nil];
}

-(void)webViewHelper:(OEXFindCoursesWebViewHelper *)webViewHelper shouldOpenURLString:(NSString *)urlString{
    if ([self.navigationController topViewController]==self) {
        OEXCourseInfoViewController *courseInfoViewController = [[OEXCourseInfoViewController alloc] init];
        courseInfoViewController.initialURLString = urlString;
        [self.navigationController pushViewController:courseInfoViewController animated:YES];
    }
}

-(void)webViewHelper:(OEXFindCoursesWebViewHelper *)webViewHelper userEnrolledWithCourseID:(NSString *)courseID emailOptIn:(NSString *)emailOptIn{
    
}

-(void)interstitialViewControllerDidChooseToOpenInBrowser:(OEXFindCourseInterstitialViewController *)interstitialViewController{
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:[OEXConfig sharedConfig].courseSearchURL]];
}

-(void)interstitialViewControllerDidClose:(OEXFindCourseInterstitialViewController *)interstitialViewController{
    [self.revealViewController.rearViewController performSegueWithIdentifier:@"showCourse" sender:self];
}

@end
