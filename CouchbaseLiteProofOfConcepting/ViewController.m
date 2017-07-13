//
//  ViewController.m
//  CouchbaseLiteProofOfConcepting
//
//  Created by Michael Hudgins on 7/13/17.
//  Copyright © 2017 Michael Hudgins. All rights reserved.
//

#import "ViewController.h"
#import "TestingSpeeds.h"

@interface ViewController ()
@property TestingSpeeds *testing;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // Do any additional setup after loading the view.
    self.testing = [[TestingSpeeds alloc] init];
    [self.testing runTests];
    
}


- (void)setRepresentedObject:(id)representedObject {
    [super setRepresentedObject:representedObject];

    // Update the view, if already loaded.
}


@end
