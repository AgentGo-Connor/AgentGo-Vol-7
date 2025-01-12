#import <Foundation/Foundation.h>
@import UIKit;

NS_ASSUME_NONNULL_BEGIN

@interface FIRAppDistributionService : NSObject

@property (nonatomic, strong) UIViewController *safariHostingViewController;

- (void)initializeSafariViewController;

@end

NS_ASSUME_NONNULL_END 