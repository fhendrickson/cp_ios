//
//  ProfileNotificationsViewController.m
//  candpiosapp
//
//  Created by Stojce Slavkovski on 05.5.12.
//  Copyright (c) 2012 Coffee and Power Inc. All rights reserved.
//

#import "ProfileNotificationsViewController.h"
#import "ActionSheetDatePicker.h"
#import "PushModalViewControllerFromLeftSegue.h"
#import "CPVenue.h"
#import "AutoCheckinCell.h"
#import "FlurryAnalytics.h"

#define kInVenueText @"in venue"
#define kInCityText @"in city"

@interface ProfileNotificationsViewController () <UIActionSheetDelegate>
@property (weak, nonatomic) IBOutlet UIButton *venueButton;
@property (weak, nonatomic) IBOutlet UISwitch *checkedInOnlySwitch;
@property (weak, nonatomic) IBOutlet UISwitch *quietTimeSwitch;
@property (weak, nonatomic) IBOutlet UIView *anyoneChatView;
@property (weak, nonatomic) IBOutlet UIButton *quietFromButton;
@property (weak, nonatomic) IBOutlet UIButton *quietToButton;
@property (weak, nonatomic) IBOutlet UISwitch *contactsOnlyChatSwitch;
@property (weak, nonatomic) IBOutlet UILabel *chatNotificationLabel;
@property (weak, nonatomic) IBOutlet UISwitch *globalCheckinSwitch;
@property (nonatomic, strong) NSMutableArray *placesArray;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (weak, nonatomic) IBOutlet UIView *headerView;



- (IBAction)selectVenueCity:(UIButton *)sender;
- (IBAction)quietFromClicked:(UIButton *)sender;
- (IBAction)quietToClicked:(UIButton *)sender;
- (IBAction)quietTimeValueChanged:(UISwitch *)sender;
- (IBAction)anyoneChatSwitchChanged:(id)sender;
- (IBAction)globalCheckinChanged:(id)sender;


@property(strong) NSDate *quietTimeFromDate;
@property(strong) NSDate *quietTimeToDate;

@end

@implementation ProfileNotificationsViewController

@synthesize venueButton = _venueButton;
@synthesize checkedInOnlySwitch = _checkedInOnlySwitch;
@synthesize quietTimeSwitch = _quietTimeSwitch;
@synthesize anyoneChatView = anyoneChatView;
@synthesize quietFromButton = _quietFromButton;
@synthesize quietToButton = _quietToButton;
@synthesize contactsOnlyChatSwitch = _contactsOnlyChatSwitch;
@synthesize chatNotificationLabel = _chatNotificationLabel;
@synthesize quietTimeFromDate = _quietTimeFromDate;
@synthesize quietTimeToDate = _quietTimeToDate;
@synthesize globalCheckinSwitch = _globalCheckinSwitch;
@synthesize placesArray = _placesArray;
@synthesize locationManager = _locationManager;
@synthesize headerView = _headerView;

#pragma mark - View lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	// Do any additional setup after loading the view.
    [self venueButton].titleEdgeInsets = UIEdgeInsetsMake(0, 10, 0, 10);
    
    // If automaticCheckins is disabled, hide the table view unless changed
    BOOL automaticCheckins = [DEFAULTS(object, kAutomaticCheckins) boolValue];
    
    self.globalCheckinSwitch.on = automaticCheckins;
    
    if (automaticCheckins) {    
        [self setupPlacesArray];
    }
}

-(void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];    
    [self loadNotificationSettings];
}

- (void)viewDidUnload
{
    [self setVenueButton:nil];
    [self setCheckedInOnlySwitch:nil];
    [self setQuietTimeSwitch:nil];
    [self setAnyoneChatView:nil];
    [self setQuietFromButton:nil];
    [self setQuietToButton:nil];
    [self setContactsOnlyChatSwitch:nil];
    [self setQuietTimeFromDate:nil];
    [self setQuietTimeToDate:nil];
    [self setChatNotificationLabel:nil];
    [self setGlobalCheckinSwitch:nil];
    [self setHeaderView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
}

-(void)viewDidDisappear:(BOOL)animated
{
    [self saveNotificationSettings];
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}


#pragma mark - Api calls
- (void)loadNotificationSettings
{
    [SVProgressHUD show];
    [CPapi getNotificationSettingsWithCompletition:^(NSDictionary *json, NSError *err) {
        BOOL error = [[json objectForKey:@"error"] boolValue];
        if (error) {
            [self dismissModalViewControllerAnimated:YES];
            NSString *message = @"There was a problem getting your data!\nPlease logout and login again.";
            [SVProgressHUD dismissWithError:message
                                 afterDelay:kDefaultDimissDelay];
        } else {
            NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
            [dateFormat setDateFormat:@"HH:mm:ss"];
            [dateFormat setTimeZone:[NSTimeZone localTimeZone]];
            
            NSDictionary *dict = [json objectForKey:@"payload"];

            NSString *venue = (NSString *)[dict objectForKey:@"push_distance"];
            [self setVenue:[venue isEqualToString:@"venue"]];

            NSString *checkInOnly = (NSString *)[dict objectForKey:@"checked_in_only"];
            [[self checkedInOnlySwitch] setOn:[checkInOnly isEqualToString:@"1"]];

            NSString *quietTime = (NSString *)[dict objectForKey:@"quiet_time"];
            [[self quietTimeSwitch] setOn:[quietTime isEqualToString:@"1"]];
            [self setQuietTime:self.quietTimeSwitch.on];
            
            NSString *quietTimeFrom = (NSString *)[dict objectForKey:@"quiet_time_from"];
            if ([quietTimeFrom isKindOfClass:[NSNull class]]) {
                quietTimeFrom = @"20:00:00";
            }
            
            @try {
                self.quietTimeFromDate = [dateFormat dateFromString:quietTimeFrom];
            }
            @catch (NSException* ex) {
                self.quietTimeFromDate = [dateFormat dateFromString:@"7:00"];
            }
            
            [[self quietFromButton] setTitle:[self setTimeText:self.quietTimeFromDate]
                                    forState:UIControlStateNormal];

            
            NSString *quietTimeTo = (NSString *)[dict objectForKey:@"quiet_time_to"];
            if ([quietTimeTo isKindOfClass:[NSNull class]]) {
                quietTimeTo = @"07:00:00";
            }
            
            @try {
                self.quietTimeToDate = [dateFormat dateFromString:quietTimeTo];
            }
            @catch (NSException* ex) {
                self.quietTimeToDate = [dateFormat dateFromString:@"19:00"];
            }
            
            [[self quietToButton] setTitle:[self setTimeText:self.quietTimeToDate]
                                  forState:UIControlStateNormal];

            NSString *contactsOnlyChat = (NSString *)[dict objectForKey:@"contacts_only_chat"];
            [[self contactsOnlyChatSwitch] setOn:[contactsOnlyChat isEqualToString:@"0"]];

            [[self chatNotificationLabel] setHidden:self.contactsOnlyChatSwitch.on];
            [SVProgressHUD dismiss];
        }
    }];
}

- (void)saveNotificationSettings
{
    BOOL notifyInVenue = [self.venueButton.currentTitle isEqualToString:kInVenueText];
    NSString *distance = notifyInVenue ? @"venue" : @"city";
    
    [CPapi setNotificationSettingsForDistance:distance
                                 andCheckedId:self.checkedInOnlySwitch.on
                                    quietTime:self.quietTimeSwitch.on
                                quietTimeFrom:[self quietTimeFromDate]
                                  quietTimeTo:[self quietTimeToDate]
                      timezoneOffsetInSeconds:[[NSTimeZone defaultTimeZone] secondsFromGMT]
                         chatFromContactsOnly:!self.contactsOnlyChatSwitch.on];
}

#pragma mark - UI Events
-(IBAction)gearPressed:(id)sender
{
    [self saveNotificationSettings];
    [self dismissPushModalViewControllerFromLeftSegue];
}

- (IBAction)quietFromClicked:(UITextField *)sender 
{
    [ActionSheetDatePicker showPickerWithTitle:@"Select Quiet Time From"
                                datePickerMode:UIDatePickerModeTime
                                  selectedDate:[self quietTimeFromDate]
                                        target:self
                                        action:@selector(timeWasSelected:element:)
                                        origin:sender];
}

- (IBAction)quietToClicked:(UIButton *)sender
{
    [ActionSheetDatePicker showPickerWithTitle:@"Select Quiet Time To"
                                datePickerMode:UIDatePickerModeTime
                                  selectedDate:[self quietTimeToDate]
                                        target:self
                                        action:@selector(timeWasSelected:element:)
                                        origin:sender];
}

- (void)timeWasSelected:(NSDate *)selectedTime element:(id)element
{
    UIButton *button = (UIButton *)element;
    [button setTitle:[self setTimeText:selectedTime] forState:UIControlStateNormal];
    if (button.tag == 1) {
        self.quietTimeFromDate = selectedTime;
    } else {
        self.quietTimeToDate = selectedTime;
    }
}

- (IBAction)quietTimeValueChanged:(UISwitch *)sender
{
    [self setQuietTime:sender.on];
}

- (IBAction)anyoneChatSwitchChanged:(id)sender 
{
    [[self chatNotificationLabel] setHidden:self.contactsOnlyChatSwitch.on];
}

- (IBAction)selectVenueCity:(UIButton *)sender 
{
    UIActionSheet *actionSheet = [[UIActionSheet alloc]
                                  initWithTitle:@"Show me new check-ins from:"
                                  delegate:self
                                  cancelButtonTitle:@"Cancel"
                                  destructiveButtonTitle:nil
                                  otherButtonTitles:@"City", @"Venue", nil
                                  ];
    [actionSheet showInView:self.view];
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    [self setVenue:buttonIndex == 1];
}

- (void)setVenue:(BOOL)inVenue
{
    [[self venueButton] setTitle: inVenue ? kInVenueText : kInCityText
                        forState:UIControlStateNormal];
}

- (void)setQuietTime:(BOOL)quietTime
{   
    
    [UIView animateWithDuration:0.3 animations:^ {
        self.anyoneChatView.frame = CGRectMake(self.anyoneChatView.frame.origin.x, 
                                               quietTime ? 210 : 170,
                                               self.anyoneChatView.frame.size.width,
                                               self.anyoneChatView.frame.size.height);
        
        self.headerView.frame = CGRectMake(0,0, 
                                            self.headerView.frame.size.width,
                                            quietTime ? 330 : 290);
    }];
    
    
    
}

- (NSString *)setTimeText:(NSDate *)timeValue
{
    NSDateFormatter *timeFormatter = [[NSDateFormatter alloc]init];
    timeFormatter.dateFormat = @"HH:mm";
    timeFormatter.timeStyle = NSDateFormatterShortStyle;
    NSString *dateString = [timeFormatter stringFromDate: timeValue];
    
    return dateString;
}

- (void)setupPlacesArray {
    if (!self.placesArray) {
        self.placesArray = [[NSMutableArray alloc] init];
    }
    
    NSArray *pastVenues = DEFAULTS(object, kUDPastVenues);
    
    for (NSData *encodedObject in pastVenues) {
        CPVenue *venue = (CPVenue *)[NSKeyedUnarchiver unarchiveObjectWithData:encodedObject];
        
        if (venue && venue.name) {
            //            NSLog(@"venue found: %@", venue.name);
            [self.placesArray addObject:venue];
        }
    }
    
    NSArray *sortedArray;
    
    sortedArray = [self.placesArray sortedArrayUsingComparator:^(id a, id b) {
        NSString *first = [(CPVenue *)a name];
        NSString *second = [(CPVenue *)b name];
        return [first compare:second];
    }];
    
    self.placesArray = [sortedArray mutableCopy];
}

- (IBAction)globalCheckinChanged:(UISwitch *)sender {
    // Store the choice in NSUserDefaults
    SET_DEFAULTS(Object, kAutomaticCheckins, [NSNumber numberWithBool:sender.on]);
    
    if (!sender.on) {
        // Disable auto checkins
        
        for (CPVenue *venue in self.placesArray) {
            [CPAppDelegate stopMonitoringVenue:venue];
        }
        
        [self.placesArray removeAllObjects];
        
        // Clear out all currently monitored regions in order to stop using geofencing altogether
        for (CLRegion *reg in [[CPAppDelegate locationManager] monitoredRegions]) {
            [[CPAppDelegate locationManager] stopMonitoringForRegion:reg];
        }
        
        [FlurryAnalytics logEvent:@"automaticCheckinsDisabled"];
    }
    else {
        [self setupPlacesArray];
        
        // Iterate over all past venues to start monitoring those with autoCheckin enabled        
        for (CPVenue *venue in self.placesArray) {
            NSLog(@"auto: %i, venue: %@", venue.autoCheckin, venue.name);
            if (venue.autoCheckin) {
                [CPAppDelegate startMonitoringVenue:venue];
            }
        }
        
        [FlurryAnalytics logEvent:@"automaticCheckinsEnabled"];
    }
    
    [self.tableView reloadData];
}


#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    if (self.placesArray.count > 0) {
        return 1;
    }
    else {
        return 0;
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (self.placesArray.count > 0) {
        return self.placesArray.count;
    }
    else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"AutoCheckinCell";
    AutoCheckinCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    CPVenue *venue = [self.placesArray objectAtIndex:indexPath.row];
    
    if (venue) {
        cell.venueName.text = venue.name;
        cell.venueAddress.text = venue.address;
        cell.venue = venue;
        
        cell.venueSwitch.on = venue.autoCheckin;
    }
    
    return cell;
}

@end
