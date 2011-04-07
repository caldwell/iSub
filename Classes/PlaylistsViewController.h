//
//  PlaylistsViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BBSimpleConnectionQueue.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton, BBSimpleConnectionQueue;

@interface PlaylistsViewController : UITableViewController <BBSimpleConnectionQueueDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	UIView *headerView;
	UISegmentedControl *segmentedControl;
	UIImageView *noPlaylistsScreen;
	BOOL isNoPlaylistsScreenShowing;
	
	UILabel *savePlaylistLabel;
	UILabel *playlistCountLabel;
	UIButton *savePlaylistButton;
	UILabel *deleteSongsLabel;
	UILabel *spacerLabel;
	UILabel *editPlaylistLabel;
	UIButton *editPlaylistButton;
	BOOL isPlaylistSaveEditShowing;
	
	UITextField *playlistNameTextField;
	
	BOOL goToNextSong;
	
	UInt32 currentPlaylistCount;
	
	NSArray *listOfSongs;
	
	BBSimpleConnectionQueue *connectionQueue;
	
	//NSMutableData *receivedData;
}

@property (nonatomic, retain) NSArray *listOfSongs;

- (void)showDeleteButton;
- (void)hideDeleteButton;

- (void)segmentAction:(id)sender;
- (void)updateCurrentPlaylistCount;

@end
