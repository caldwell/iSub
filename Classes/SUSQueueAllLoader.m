//
//  QueueAll.m
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSQueueAllLoader.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "ViewObjectsSingleton.h"
#import "QueueAlbumXMLParser.h"
#import "Album.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "SUSStreamSingleton.h"
#import "PlaylistSingleton.h"

@implementation SUSQueueAllLoader

@synthesize currentPlaylist, shufflePlaylist, myArtist, folderIds;

- (id)init
{
	if ((self = [super init]))
	{
		appDelegate = [iSubAppDelegate sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		
		myArtist = nil;
		folderIds = [[NSMutableArray alloc] initWithCapacity:10];
	}

	return self;
}

- (void)loadAlbumFolder
{	
	NSString *folderId = [folderIds objectAtIndex:0];
	//DLog(@"Loading folderid: %@", folderId);
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObject:folderId forKey:@"id"];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicDirectory" andParameters:parameters];
    
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	}
}

- (void)startLoad
{
	DLog(@"must use loadData:artist:");
}

- (void)cancelLoad
{
	[super cancelLoad];
	[viewObjects hideLoadingScreen];
}

- (void)finishLoad
{	
	// Continue the iteration
	if ([folderIds count] > 0)
	{
		[self loadAlbumFolder];
	}
	else 
	{
		//if (currentPlaylist.isShuffle)
		if (isShuffleButton)
		{
			// Perform the shuffle
			[databaseControls shufflePlaylist];
		}
		
		if (isQueue)
		{
			if ([SavedSettings sharedInstance].isJukeboxEnabled)
			{
				[musicControls jukeboxReplacePlaylistWithLocal];
			}
			else
			{
				[[SUSStreamSingleton sharedInstance] fillStreamQueue];
			}
		}
		
		[viewObjects hideLoadingScreen];
		
		if (doShowPlayer)
		{
			[musicControls showPlayer];
		}
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			[PlaylistSingleton sharedInstance].isShuffle = NO;
		}
	}
}

- (void)loadData:(NSString *)folderId artist:(Artist *)theArtist //isQueue:(BOOL)queue 
{	
	[folderIds addObject:folderId];
	self.myArtist = theArtist;
	
	//jukeboxSongIds = [[NSMutableArray alloc] init];
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		self.currentPlaylist = @"jukeboxCurrentPlaylist";
		self.shufflePlaylist = @"jukeboxShufflePlaylist";
	}
	else
	{
		self.currentPlaylist = @"currentPlaylist";
		self.shufflePlaylist = @"shufflePlaylist";
	}
	
	[self loadAlbumFolder];
}

- (void)queueData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = YES;
	isShuffleButton = NO;
	doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)cacheData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = NO;
	isShuffleButton = NO;
	doShowPlayer = NO;
	[self loadData:folderId artist:theArtist];
}

- (void)playAllData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = YES;
	isShuffleButton = NO;
	doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

- (void)shuffleData:(NSString *)folderId artist:(Artist *)theArtist
{
	isQueue = YES;
	isShuffleButton = YES;
	doShowPlayer = YES;
	[self loadData:folderId artist:theArtist];
}

#pragma mark Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
		
	self.receivedData = nil;
	self.connection = nil;
	
	// Remove the processed folder from array
	[folderIds removeObjectAtIndex:0];
	
	// Continue the iteration
	[self finishLoad];
	
	DLog(@"QueueAll CONNECTION FAILED!!!");
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
	QueueAlbumXMLParser *parser = (QueueAlbumXMLParser *)[[QueueAlbumXMLParser alloc] initXMLParser];
	parser.myArtist = myArtist;
	[xmlParser setDelegate:parser];
	[xmlParser parse];
		
	// Add each song to playlist
	for (Song *aSong in parser.listOfSongs)
	{
		NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
		
		if (isQueue)
		{
			[aSong addToCurrentPlaylist];
		}
		else
		{
			[aSong addToCacheQueue];
		}
		
		[pool release];
	}
	
	// Remove the processed folder from array
	if ([folderIds count] > 0)
		[folderIds removeObjectAtIndex:0];
	
	//DLog(@"parser.listOfSongs = %@", parser.listOfSongs);
	//DLog(@"Playlist count: %i", [databaseControls.currentPlaylistDb intForQuery:@"SELECT COUNT(*) FROM jukeboxCurrentPlaylist"]);
	
	NSUInteger maxIndex = [parser.listOfAlbums count] - 1;
	for (int i = maxIndex; i >= 0; i--)
	{
		NSString *albumId = [[parser.listOfAlbums objectAtIndex:i] albumId];
		[folderIds insertObject:albumId atIndex:0];
	}

	[parser release];
	[xmlParser release];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Continue the iteration
	[self finishLoad];
}


#pragma mark Memory Management

- (void)dealloc
{
	[currentPlaylist release]; currentPlaylist = nil;
	[shufflePlaylist release]; shufflePlaylist = nil;
	[myArtist release]; myArtist = nil;
	
	
	[super dealloc];
}


@end