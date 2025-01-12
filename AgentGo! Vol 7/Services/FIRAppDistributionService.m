#import "FIRAppDistributionService.h"
#import <UIKit/UIKit.h>
#import <FirebaseAppDistribution/FirebaseAppDistribution.h>

@implementation FIRAppDistributionService

- (void)initializeSafariViewController {
    dispatch_async(dispatch_get_main_queue(), ^{
        self.safariHostingViewController = [[UIViewController alloc] init];
    });
}

@end 