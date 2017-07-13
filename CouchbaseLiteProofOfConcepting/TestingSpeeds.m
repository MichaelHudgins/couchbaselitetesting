//
//  TestingSpeeds.m
//  CouchbaseLiteProofOfConcepting
//
//  Created by Michael Hudgins on 7/13/17.
//  Copyright © 2017 Michael Hudgins. All rights reserved.
//

#import "TestingSpeeds.h"
#import <Cocoa/Cocoa.h>

@import CouchbaseLite;
@interface TestingSpeeds ()

@property NSMutableArray *allDocs;
@property dispatch_queue_t queue;
@property NSThread *thread;
@property NSString *currentDBName;

@end

@implementation TestingSpeeds

- (id)init{
    self = [super init];
    if(self){
        self.queue = dispatch_queue_create("com.testingCouchbase", nil);
        self.allDocs = [[NSMutableArray alloc] init];
    }
    return self;
}

//Run tests to create to emulate a file structure where folders are represented as documents that may link to one another and where files are embedded in their folder's document
-(void)runTests{
    self.thread = [[NSThread alloc] initWithBlock:^{
        
        //We run our creation 3 times to make sure the memory footprint stays low
        for(int i = 0; i < 3; i++){
            @autoreleasepool {
                NSDate *creationTime = [NSDate date];
                
                //We generate a sperate database for each one of our tests
                self.currentDBName = [NSString stringWithFormat:@"memorytesting%i",i];
                @autoreleasepool {
                    [self createSimulatedFileSystem];
                }
                
                NSLog(@"Creation time for strcuture : %f",[[NSDate date] timeIntervalSinceDate:creationTime]);
                //[self.allDocs removeAllObjects];
                
                //Test memory when all documents are read 10 times, we then average those times to get an average read per entire data set
                //Test if they are read in the order they were created
                NSTimeInterval ordered = 0;
                for(int i = 0;i < 10; i++)
                {
                    NSDate *date = [NSDate date];
                    @autoreleasepool {
                        [self accessAllDocumentsInOrder];
                    }
                    
                    
                    ordered += [[NSDate date] timeIntervalSinceDate:date];
                }
                ordered /= 10;
                
                
                //Now test if they are read in any order
                NSTimeInterval random = 0;
                for(int i = 0;i < 10; i++)
                {
                    NSDate *date = [NSDate date];
                    @autoreleasepool {
                        [self accessAllDocumentsInOrder];
                    }
                    
                    random += [[NSDate date] timeIntervalSinceDate:date];
                }
                random /= 10;
                
                //Clear our docs for the next test
                [self.allDocs removeAllObjects];
                
                NSLog(@"Reads for test %i were: Ordered read time per set was %f.  Random read time per set was %f",i,ordered,random);
            }
            
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            NSAlert *alert = [[NSAlert alloc] init];
            alert.messageText = @"Done";
            alert.informativeText = @"Done";
            [alert runModal];
            
        });
        
        [NSThread exit];
    }];
    self.thread.name = @"Testing";
    [self.thread start];
}


//Create our simulated FileSystem
- (void)createSimulatedFileSystem{
    
    //we are going to create a document with what appears to be a file system
    CBLDatabase *db = [[CBLDatabase alloc] initWithName:self.currentDBName config:nil error:nil];
    
    //We test the following.  Create 200 documents, with links to 200 documents each.  Acting like 40,200 folders.  Each folder on the second level will have 25 "File Data" embeded in them to act like 1,000,000 files.
    
    for(int i = 0; i < 200; i++){
        @autoreleasepool {
            [db inBatch:nil do:^{
                //Create a document, the base path is 25 characters long (A-Y)
                CBLDocument *doc = [self randomDocumentWithBasePath:@"ABCDEFGHIJKLMNOPQRSTUVWXY"];
                [self.allDocs addObject:doc.documentID];
                
                //The children of this level
                NSMutableArray *children = [[NSMutableArray alloc] init];
                
                //Create the inner folders
                for(int j = 0; j< 200; j++){
                    
                    //Paths are dependent on their parent path
                    CBLDocument *doc2 = [self randomDocumentWithBasePath:[doc objectForKey:@"Path"]];
                    [doc2 setObject:doc.documentID forKey:@"Parent"];
                    [self.allDocs addObject:doc2.documentID];
                    [children addObject:doc2.documentID];
                    
                    //Create the embbeded files
                    NSMutableArray *embbededChildren = [[NSMutableArray alloc] init];
                    for(int k = 0; k < 25; k++){
                        CBLDictionary *doc3 = [self randomEmbededFileWithBasePath:[doc2 objectForKey:@"Path"]];
                        [doc2 setObject:doc3 forKey:[NSString stringWithFormat:@"File_%i",k]];
                        
                    }
                    [doc2 setObject:embbededChildren forKey:@"Children"];
                    
                    NSError *error = nil;
                    [db saveDocument:doc2 error:&error];
                    if(error)
                    {
                        error = nil;
                        [db saveDocument:doc2 error:&error];
                        assert(error == nil);
                    }
                    
                }
                
                [doc setObject:children forKey:@"Children"];
                NSError *error2 = nil;
                [db saveDocument:doc error:&error2];
                if(error2)
                {
                    error2 = nil;
                    [db saveDocument:doc error:&error2];
                    assert(error2 == nil);
                }
            }];
            
        }
    }
    
    //We close the db after every test
    [db close:nil];
    
}


///Pull all documents in the order they were created
- (void)accessAllDocumentsInOrder{
    CBLDatabase *db = [[CBLDatabase alloc] initWithName:self.currentDBName config:nil error:nil];
    for (NSString *docId in self.allDocs) {
        CBLDocument *document = [db documentWithID:docId];
        assert(document != nil);
    }
    
    //We close the db after every test
    [db close:nil];
}

///Pull all documents in any order
- (void)accessAllDocumentsRandom{
    CBLDatabase *db = [[CBLDatabase alloc] initWithName:self.currentDBName config:nil error:nil];
    NSMutableArray *docs = [NSMutableArray arrayWithArray:self.allDocs];
    
    while([docs count] > 0){
        int index = arc4random_uniform((int)docs.count);
        NSString *docId = [docs objectAtIndex:index];
        CBLDocument *document = [db documentWithID:docId];
        assert(document != nil);
        [docs removeObjectAtIndex:index];
        
    }
    
    //We close the db after every test
    [db close:nil];
}

//Create a random document with some fake data so that we dont have records with the exact same info
- (CBLDocument *)randomDocumentWithBasePath:(NSString *)basePath{
    
    CBLDocument *document = [[CBLDocument alloc]init];
    //Our path is a base path plus two random numbers just to keep paths unique and long
    NSString *newPath = [NSString stringWithFormat:@"%@/%u%u",basePath,arc4random(),arc4random()];
    [document setObject:newPath forKey:@"Path"];
    [document setObject:[NSDate date] forKey:@"DateCreated"];
    [document setObject:[NSDate dateWithTimeInterval:-30 sinceDate:[NSDate date]] forKey:@"DateModified"];
    [document setObject:[NSNumber numberWithBool:arc4random() % 10 == 0] forKey:@"isDirectory"];
    return document;
    
}

//Create a random cbl dictionary that will be embbeded in a document
- (CBLDictionary *)randomEmbededFileWithBasePath:(NSString *)basePath{
    
    CBLDictionary *document = [[CBLDictionary alloc]init];
    NSString *newPath = [NSString stringWithFormat:@"%@/%u",basePath,arc4random()];
    [document setObject:newPath forKey:@"Path"];
    [document setObject:[NSDate date] forKey:@"DateCreated"];
    [document setObject:[NSNumber numberWithBool:arc4random() % 10 == 0] forKey:@"isDirectory"];
    return document;
    
}

@end
