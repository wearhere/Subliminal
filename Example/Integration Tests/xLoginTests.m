//
//  sLoginTests.m
//

#import <Subliminal/Subliminal.h>

@interface xLoginTests : SLTest

@end

@implementation xLoginTests {
    SLTextField *username;
    SLTextField *password;
}

- (void)setUpTest {
    username = [SLTextField elementWithAccessibilityLabel:@"User ID"];
    password = [SLTextField elementWithAccessibilityLabel:@"Password"];
}

- (void)tearDownTest {
}

- (void)testCase2LogInUsingEmptyUsernameEmptyPassword {

    [self wait:2.0];
    [[SLWindow mainWindow] logElementTree];
    
    [self wait:0.5];
    [username setText:@"asdf"];
    [password setText:@"asdf"];

    [self wait:3.0];
}
@end
