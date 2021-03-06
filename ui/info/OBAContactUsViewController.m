/**
 * Copyright (C) 2009 bdferris <bdferris@onebusaway.org>
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *         http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "OBAContactUsViewController.h"
#import "UITableViewController+oba_Additions.h"
#import "OBANavigationTargetAware.h"
#import <sys/utsname.h>
#import <MessageUI/MFMailComposeViewController.h>
#import "OBAAnalytics.h"
#import "UITableViewCell+oba_Additions.h"
#import <SafariServices/SafariServices.h>

#define kEmailRow    0
#define kTwitterRow  1
#define kFacebookRow 2
#define kRowCount    3 //including Facebook which is optional

static NSString *kOBADefaultContactEmail = @"contact@onebusaway.org";
static NSString *kOBADefaultTwitterURL = @"http://twitter.com/onebusaway";

@implementation OBAContactUsViewController


- (id)init {
    if (self = [super initWithStyle:UITableViewStylePlain]) {
        self.title = NSLocalizedString(@"Contact Us", @"Contact us tab title");
        self.appDelegate = APP_DELEGATE;
    }

    return self;
}

#pragma mark mail methods

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error;
{
    [self becomeFirstResponder];
    [self dismissViewControllerAnimated:YES completion:nil];
    [self.navigationController popViewControllerAnimated:YES];
}

- (void)cantSendEmail {
    UIAlertController *alert = [UIAlertController alertControllerWithTitle:NSLocalizedString(@"Please setup your Mail app before trying to send an email.", @"view.message")
                                                                   message:nil
                                                            preferredStyle:UIAlertControllerStyleAlert];

    [alert addAction:[UIAlertAction actionWithTitle:NSLocalizedString(@"Dismiss", @"Dismiss button for alert.") style:UIAlertActionStyleDefault handler:nil]];
    [self presentViewController:alert animated:YES completion:nil];
}

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self hideEmptySeparators];
    self.tableView.backgroundView = nil;
    self.tableView.backgroundColor = [UIColor whiteColor];
}

#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    OBARegionV2 *region = [OBAApplication sharedApplication].modelDao.region;

    if (region.facebookUrl && ![region.facebookUrl isEqualToString:@""]) {
        return kRowCount;
    }

    //if no facebook URL 1 less row
    return (kRowCount - 1);
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [UITableViewCell getOrCreateCellForTableView:tableView];

    switch (indexPath.row) {
        case kEmailRow:
            cell.textLabel.text = NSLocalizedString(@"Email", @"Email title");
            break;

        case kTwitterRow:
            cell.textLabel.text = NSLocalizedString(@"Twitter", @"Twitter title");
            break;

        case kFacebookRow:
            cell.textLabel.text = NSLocalizedString(@"Facebook", @"Facebook title");
            break;
    }
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    return cell;
}

- (void)sendFeedbackEmailForRegion:(OBARegionV2 *)region {
    [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"button_press" label:@"Clicked Email Link" value:nil];

    if (![MFMailComposeViewController canSendMail]) {
        [self cantSendEmail];
        return;
    }

    MFMailComposeViewController *controller = [[MFMailComposeViewController alloc] init];

    if (!controller) {
        [self cantSendEmail];
        return;
    }

    // Create and show composer
    NSString *contactEmail = kOBADefaultContactEmail;

    if (region) {
        contactEmail = region.contactEmail;
    }

    //device model, thanks to http://stackoverflow.com/a/11197770/1233435
    struct utsname systemInfo;
    uname(&systemInfo);

    NSString *appVersionString = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    CLLocation *location = [OBAApplication sharedApplication].locationManager.currentLocation;

    controller.mailComposeDelegate = self;
    [controller setToRecipients:@[contactEmail]];
    [controller setSubject:NSLocalizedString(@"OneBusAway iOS Feedback", @"feedback mail subject")];

    NSString *unformattedMessageBody = [NSString stringWithContentsOfFile:[[NSBundle mainBundle] pathForResource:@"feedback_message_body" ofType:@"html"] encoding:NSUTF8StringEncoding error:nil];

    NSString *messageBody = [NSString stringWithFormat:unformattedMessageBody,
                             appVersionString,
                             [NSString stringWithCString:systemInfo.machine
                                                encoding:NSUTF8StringEncoding],
                             [[UIDevice currentDevice] systemVersion],
                             OBAStringFromBool([OBAApplication sharedApplication].modelDao.readSetRegionAutomatically),
                             [OBAApplication sharedApplication].modelDao.region.regionName,
                             [OBAApplication sharedApplication].modelDao.readCustomApiUrl,
                             location.coordinate.latitude,
                             location.coordinate.longitude
        ];

    [controller setMessageBody:messageBody isHTML:YES];

    [self presentViewController:controller animated:YES completion:nil];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    OBARegionV2 *region = [OBAApplication sharedApplication].modelDao.region;

    switch (indexPath.row) {
        case kEmailRow: {
            [self sendFeedbackEmailForRegion:region];
        }
        break;

        case kTwitterRow: {
            [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"button_press" label:@"Clicked Twitter Link" value:nil];
            NSString *twitterUrl = kOBADefaultTwitterURL;

            if (region) {
                twitterUrl = region.twitterUrl;
            }

            NSString *twitterName = [[twitterUrl componentsSeparatedByString:@"/"] lastObject];

            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"twitter://"]]) {
                [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"app_switch" label:@"Loaded Twitter via App" value:nil];
                NSString *url = [NSString stringWithFormat:@"twitter://user?screen_name=%@", twitterName];
                // Appropriate use of -openURL:. Don't replace.
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            }
            else {
                [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"app_switch" label:@"Loaded Twitter via Web" value:nil];
                NSString *url = [NSString stringWithFormat:@"http://twitter.com/%@", twitterName];
                SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url]];
                safari.modalPresentationStyle = UIModalPresentationOverFullScreen;
                [self presentViewController:safari animated:YES completion:nil];
            }
        }
        break;

        case kFacebookRow:

            if (region.facebookUrl) {
                [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"button_press" label:@"Clicked Facebook Link" value:nil];
                NSString *facebookUrl = region.facebookUrl;
                NSString *facebookPage = [[facebookUrl componentsSeparatedByString:@"/"] lastObject];

                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:@"fb://"]]) {
                    [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"app_switch" label:@"Loaded Facebook via App" value:nil];
                    NSString *url = [NSString stringWithFormat:@"fb://profile/%@", facebookPage];

                    // Appropriate use of -openURL:. Don't replace.
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
                }
                else {
                    [OBAAnalytics reportEventWithCategory:OBAAnalyticsCategoryUIAction action:@"app_switch" label:@"Loaded Facebook via Web" value:nil];
                    NSString *url = [NSString stringWithFormat:@"http://facebook.com/%@", facebookPage];
                    SFSafariViewController *safari = [[SFSafariViewController alloc] initWithURL:[NSURL URLWithString:url]];
                    safari.modalPresentationStyle = UIModalPresentationOverFullScreen;
                    [self presentViewController:safari animated:YES completion:nil];
                }
            }

            break;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0.0;
}

#pragma mark OBANavigationTargetAware

- (OBANavigationTarget *)navigationTarget {
    return [OBANavigationTarget target:OBANavigationTargetTypeContactUs];
}

@end
