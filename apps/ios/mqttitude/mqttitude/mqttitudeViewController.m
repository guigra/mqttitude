//
//  mqttitudeViewController.m
//  mqttitude
//
//  Created by Christoph Krey on 17.08.13.
//  Copyright (c) 2013 Christoph Krey. All rights reserved.
//

#import "mqttitudeViewController.h"
#import "mqttitudeAppDelegate.h"
#import "mqttitudeStatusTVC.h"
#import "mqttitudeFriendAnnotationView.h"
#import "mqttitudeFriendTVC.h"
#import "mqttitudeLocationTVC.h"
#import "mqttitudeCoreData.h"
#import "Friend+Create.h"
#import "Location+Create.h"

@interface mqttitudeViewController ()
@property (weak, nonatomic) IBOutlet MKMapView *mapView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *connectionButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *locationButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *mapModeButton;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *friendsButton;
@property (weak, nonatomic) IBOutlet UIToolbar *toolbar;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *activity;

@property (strong, nonatomic) NSFetchedResultsController *frc;
@property (nonatomic) BOOL suspendAutomaticTrackingOfChangesInManagedObjectContext;

@property (nonatomic) NSInteger friends;
@end

@implementation mqttitudeViewController

#define KEEPALIVE 600.0

- (void)viewDidLoad
{

    [super viewDidLoad];

    self.mapView.delegate = self;
    
    // Tracking Mode
    self.friends = 2;
    
    // Map Mode
    self.mapView.mapType = MKMapTypeStandard;
}


- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *)[UIApplication sharedApplication].delegate;
    [self showState:delegate.connection.state];
    
    [self friends:nil];
    [self mapMode:nil];
    [self location:nil];
    
    if ([mqttitudeCoreData theManagedObjectContext]) {
        if (!self.frc) {
            NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Location"];
            request.sortDescriptors = @[[NSSortDescriptor sortDescriptorWithKey:@"timestamp" ascending:YES]];
            
            self.frc = [[NSFetchedResultsController alloc] initWithFetchRequest:request
                                                           managedObjectContext:[mqttitudeCoreData theManagedObjectContext]
                                                             sectionNameKeyPath:nil
                                                                      cacheName:nil];
            self.frc.delegate = self;
        }
    }
}

#pragma UI actions

- (IBAction)setCenter:(UIStoryboardSegue *)segue {
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(0, 0);
    
    if ([segue.sourceViewController isKindOfClass:[mqttitudeFriendTVC class]]) {
        mqttitudeFriendTVC *friendTVC = (mqttitudeFriendTVC *)segue.sourceViewController;
        coordinate = friendTVC.selectedLocation.coordinate;
    }
    if ([segue.sourceViewController isKindOfClass:[mqttitudeLocationTVC class]]) {
        mqttitudeLocationTVC *locationTVC = (mqttitudeLocationTVC *)segue.sourceViewController;
        coordinate = locationTVC.selectedLocation.coordinate;
    }
    
    [self.mapView setVisibleMapRect:[self centeredRect:coordinate] animated:YES];
    self.friends = 4; // this will set the move mode to follow when the map appeares again
}

- (IBAction)location:(UIBarButtonItem *)sender {
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *) [[UIApplication sharedApplication] delegate];
    if (sender) {
        delegate.monitoring = (delegate.monitoring + 3 - 1) % 3;
    }
    switch (delegate.monitoring) {
        case 2:
            self.locationButton.image = [UIImage imageNamed:@"Move.png"];
            break;
        case 1:
            self.locationButton.image = [UIImage imageNamed:@"LocationOn.png"];
            break;
        case 0:
        default:
            self.locationButton.image = [UIImage imageNamed:@"LocationOff.png"];
            break;
    }
}

- (IBAction)action:(UIBarButtonItem *)sender {
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *) [[UIApplication sharedApplication] delegate];
    [delegate sendNow];
}

- (IBAction)connection:(UIBarButtonItem *)sender {
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *) [[UIApplication sharedApplication] delegate];
    switch (delegate.connection.state) {
        case state_connected:
            [delegate connectionOff];
            break;
        case state_error:
        case state_starting:
        case state_connecting:
        case state_closing:
        default:
            [delegate reconnect];
            break;
    }
}

- (IBAction)friends:(UIBarButtonItem *)sender {
    if (sender) {
        self.friends = (self.friends + 4 - 1) % 4;
    }
    self.mapView.showsUserLocation = TRUE;
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *)[UIApplication sharedApplication].delegate;
    CLLocationCoordinate2D center = delegate.manager.location.coordinate;

    switch (self.friends) {
        case 3:
            self.mapView.userTrackingMode = MKUserTrackingModeFollowWithHeading;
            self.friendsButton.image = [UIImage imageNamed:@"UserTrackingFollowWithHeading.png"];
            break;
        case 2:
            self.mapView.userTrackingMode = MKUserTrackingModeFollow;
            self.friendsButton.image = [UIImage imageNamed:@"UserTrackingFollow.png"];
            break;
        case 1:
            self.mapView.userTrackingMode = MKUserTrackingModeNone;
            
            MKMapRect rect = [self centeredRect:center];
            
            for (Location *location in [Location allLocationsInManagedObjectContext:[mqttitudeCoreData theManagedObjectContext]])
            {
                MKMapPoint point = MKMapPointForCoordinate(location.coordinate);
                if (point.x < rect.origin.x) {
                    rect.size.width += rect.origin.x - point.x;
                    rect.origin.x = point.x;
                }
                if (point.x > rect.origin.x + rect.size.width) {
                    rect.size.width += point.x - rect.origin.x;
                }
                if (point.y < rect.origin.y) {
                    rect.size.height += rect.origin.y - point.y;
                    rect.origin.y = point.y;
                }
                if (point.y > rect.origin.y + rect.size.height) {
                    rect.size.height += point.y - rect.origin.y;
                }
            }
            
            rect.origin.x -= rect.size.width/10.0;
            rect.origin.y -= rect.size.height/10.0;
            rect.size.width *= 1.2;
            rect.size.height *= 1.2;
            
            [self.mapView setVisibleMapRect:rect animated:YES];
            self.friendsButton.image = [UIImage imageNamed:@"FriendsOn.png"];
            break;
        case 0:
            self.mapView.userTrackingMode = MKUserTrackingModeNone;
            [self.mapView setVisibleMapRect:[self centeredRect:center] animated:YES];
            self.friendsButton.image = [UIImage imageNamed:@"UserTrackingNone.png"];
            break;
        default:
            self.mapView.userTrackingMode = MKUserTrackingModeNone;
            self.friendsButton.image = [UIImage imageNamed:@"UserTrackingNone.png"];
            break;
    }
}

- (IBAction)mapMode:(UIBarButtonItem *)sender {
    if (sender) {
        switch (self.mapView.mapType) {
            case  MKMapTypeStandard:
                self.mapView.mapType = MKMapTypeSatellite;
                break;
            case MKMapTypeSatellite:
                self.mapView.mapType = MKMapTypeHybrid;
                break;
            case MKMapTypeHybrid:
            default:
                self.mapView.mapType = MKMapTypeStandard;
                break;
        }
    }
    switch (self.mapView.mapType) {
        case  MKMapTypeStandard:
            self.mapModeButton.image = [UIImage imageNamed:@"SatelliteOff.png"];
            break;
        case MKMapTypeSatellite:
            self.mapModeButton.image = [UIImage imageNamed:@"SatelliteOn.png"];
            break;
        case MKMapTypeHybrid:
            self.mapModeButton.image = [UIImage imageNamed:@"HybridOn.png"];
        default:
            break;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    /*
     * segue for connection status view
     */
    
    if ([segue.identifier isEqualToString:@"setConnection:"]) {
        if ([segue.destinationViewController respondsToSelector:@selector(setConnection:)]) {
            mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *)[UIApplication sharedApplication].delegate;
            [segue.destinationViewController performSelector:@selector(setConnection:) withObject:delegate.connection];
        }
    }
}

#pragma centeredRect

#define INITIAL_RADIUS 600.0

- (MKMapRect)centeredRect:(CLLocationCoordinate2D)center
{
    MKMapRect rect;
    
    double r = INITIAL_RADIUS * MKMapPointsPerMeterAtLatitude(center.latitude);
    
    rect.origin = MKMapPointForCoordinate(center);
    rect.origin.x -= r;
    rect.origin.y -= r;
    rect.size.width = 2*r;
    rect.size.height = 2*r;
    
    return rect;
}

#pragma ConnectionDelegate

- (void)showState:(NSInteger)state
{
    mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *) [[UIApplication sharedApplication] delegate];
    switch (delegate.connection.state) {
        case state_connected:
            self.connectionButton.tintColor = [UIColor greenColor];
            break;
        case state_error:
            self.connectionButton.tintColor = [UIColor redColor];
            break;
        case state_connecting:
        case state_closing:
            self.connectionButton.tintColor = [UIColor yellowColor];
            break;
        case state_starting:
        default:
            self.connectionButton.tintColor = [UIColor blueColor];
            break;
    }
}

- (void)fifoChanged:(NSNumber *)count
{
    if ([count integerValue]) {
        [self.activity startAnimating];
    } else {
        [self.activity stopAnimating];
    }
}

#pragma MKMapViewDelegate

#define REUSE_ID_SELF @"MQTTitude_Annotation_self"
#define REUSE_ID_OTHER @"MQTTitude_Annotation_other"
#define REUSE_ID_PICTURE @"MQTTitude_Annotation_picture"
#define OLD_TIME -12*60*60

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    if ([annotation isKindOfClass:[MKUserLocation class]]) {
        return nil;
    } else {
        if ([annotation isKindOfClass:[Location class]]) {
            Location *location = (Location *)annotation;
            mqttitudeAppDelegate *delegate = (mqttitudeAppDelegate *)[UIApplication sharedApplication].delegate;

            if ([location.belongsTo.topic isEqualToString:[delegate theGeneralTopic]]) {
                MKPinAnnotationView *pinAnnotationView = (MKPinAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_SELF];
                if (!pinAnnotationView) {
                    pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_SELF];
                    pinAnnotationView.canShowCallout = YES;
                }
                if ([location.automatic boolValue]) {
                    pinAnnotationView.pinColor = MKPinAnnotationColorRed;
                } else {
                    pinAnnotationView.pinColor = MKPinAnnotationColorPurple;
                }
                return pinAnnotationView;
            } else {
                Friend *friend = location.belongsTo;
                if (friend && [friend image]) {
                    UIColor *color;
                    if ([location.timestamp compare:[NSDate dateWithTimeIntervalSinceNow:OLD_TIME]] == NSOrderedAscending) {
                        color = [UIColor redColor];
                    } else {
                        color = [UIColor greenColor];
                    }

                    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_PICTURE];
                    mqttitudeFriendAnnotationView *friendAnnotationView;
                    if (annotationView) {
                        friendAnnotationView = (mqttitudeFriendAnnotationView *)annotationView;
                    } else {
                        friendAnnotationView = [[mqttitudeFriendAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_PICTURE];
                        friendAnnotationView.canShowCallout = YES;
                    }
                    friendAnnotationView.personImage = [UIImage imageWithData:[friend image]];
                    friendAnnotationView.circleColor = color;
                    [friendAnnotationView setNeedsDisplay];
                    return friendAnnotationView;
                } else {
                    MKAnnotationView *annotationView = [mapView dequeueReusableAnnotationViewWithIdentifier:REUSE_ID_OTHER];
                    if (annotationView) {
                        return annotationView;
                    } else {
                        MKPinAnnotationView *pinAnnotationView = [[MKPinAnnotationView alloc] initWithAnnotation:annotation reuseIdentifier:REUSE_ID_OTHER];
                        pinAnnotationView.pinColor = MKPinAnnotationColorGreen;
                        pinAnnotationView.canShowCallout = YES;
                        return pinAnnotationView;
                    }
                }
                
            }
        }
        return nil;
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
#ifdef DEBUG
    NSLog(@"didSelectAnnotationView");
#endif

    if ([view.annotation respondsToSelector:@selector(getReverseGeoCode)]) {
        [view.annotation performSelector:@selector(getReverseGeoCode)];
    }
}

- (void)mapView:(MKMapView *)mapView annotationView:(MKAnnotationView *)view calloutAccessoryControlTapped:(UIControl *)control
{
#ifdef DEBUG
    NSLog(@"calloutAccessoryControlTapped");
#endif
}

#pragma mark - NSFetchedResultsControllerDelegate

- (void)performFetch
{
    if (self.frc) {
        if (self.frc.fetchRequest.predicate) {
#ifdef DEBUG
            NSLog(@"[%@ %@] fetching %@ with predicate: %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.frc.fetchRequest.entityName, self.frc.fetchRequest.predicate);
#endif
        } else {
#ifdef DEBUG
            NSLog(@"[%@ %@] fetching all %@ (i.e., no predicate)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), self.frc.fetchRequest.entityName);
#endif
        }
        NSError *error;
        [self.frc performFetch:&error];
        if (error) NSLog(@"[%@ %@] %@ (%@)", NSStringFromClass([self class]), NSStringFromSelector(_cmd), [error localizedDescription], [error localizedFailureReason]);
    } else {
#ifdef DEBUG
        NSLog(@"[%@ %@] no NSFetchedResultsController (yet?)", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
#endif
    }
    [self.mapView addAnnotations:[Location allLocationsInManagedObjectContext:[mqttitudeCoreData theManagedObjectContext]]];
}

- (void)setFrc:(NSFetchedResultsController *)newfrc
{
    NSFetchedResultsController *oldfrc = _frc;
    if (newfrc != oldfrc) {
        _frc = newfrc;
        newfrc.delegate = self;
        if ((!self.title || [self.title isEqualToString:oldfrc.fetchRequest.entity.name]) && (!self.navigationController || !self.navigationItem.title)) {
            self.title = newfrc.fetchRequest.entity.name;
        }
        if (newfrc) {
#ifdef DEBUG
            NSLog(@"[%@ %@] %@", NSStringFromClass([self class]), NSStringFromSelector(_cmd), oldfrc ? @"updated" : @"set");
#endif
            [self performFetch];
        } else {
#ifdef DEBUG
            NSLog(@"[%@ %@] reset to nil", NSStringFromClass([self class]), NSStringFromSelector(_cmd));
#endif
            [self.mapView addAnnotations:[Location allLocationsInManagedObjectContext:[mqttitudeCoreData theManagedObjectContext]]];
        }
    }
}



- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
    //
}

- (void)controller:(NSFetchedResultsController *)controller
  didChangeSection:(id <NSFetchedResultsSectionInfo>)sectionInfo
		   atIndex:(NSUInteger)sectionIndex
	 forChangeType:(NSFetchedResultsChangeType)type
{
    if (!self.suspendAutomaticTrackingOfChangesInManagedObjectContext)
    {
        switch(type)
        {
            case NSFetchedResultsChangeInsert:
                //
                break;
                
            case NSFetchedResultsChangeDelete:
                //
                break;
        }
    }
}


- (void)controller:(NSFetchedResultsController *)controller
   didChangeObject:(id)anObject
	   atIndexPath:(NSIndexPath *)indexPath
	 forChangeType:(NSFetchedResultsChangeType)type
	  newIndexPath:(NSIndexPath *)newIndexPath
{
    if (!self.suspendAutomaticTrackingOfChangesInManagedObjectContext)
    {
        switch(type)
        {
            case NSFetchedResultsChangeInsert:
                [self.mapView addAnnotation:anObject];
                break;
                
            case NSFetchedResultsChangeDelete:
                [self.mapView removeAnnotation:anObject];
                break;
                
            case NSFetchedResultsChangeUpdate:
                [self.mapView removeAnnotation:anObject];
                [self.mapView addAnnotation:anObject];
                break;
                
            case NSFetchedResultsChangeMove:
                //
                break;
        }
    }
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
    //
}

- (void)endSuspensionOfUpdatesDueToContextChanges
{
    self.suspendAutomaticTrackingOfChangesInManagedObjectContext = NO;
}

- (void)setSuspendAutomaticTrackingOfChangesInManagedObjectContext:(BOOL)suspend
{
    if (suspend) {
        _suspendAutomaticTrackingOfChangesInManagedObjectContext = YES;
    } else {
        [self endSuspensionOfUpdatesDueToContextChanges];
    }
}




@end
