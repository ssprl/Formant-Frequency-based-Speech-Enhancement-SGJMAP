//
//  ViewController.h
//  CoreAudio
//
//  Created by Shankar, Nikhil on 4/4/17.
//  Copyright © 2017 default. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>

@interface ViewController : UIViewController{

@public
float x,y;
}






@property (weak,nonatomic) IBOutlet UILabel *betaLabel;
@property (weak, nonatomic) IBOutlet UISwitch *EnhancedSwitch;
@property (weak, nonatomic) IBOutlet UISlider *betaSlider;
@property (strong, nonatomic) IBOutlet UILabel *formantsLabel;

@property (weak, nonatomic) IBOutlet UISlider *beta1Slider;
@property (weak,nonatomic) IBOutlet UILabel *beta1Label;
@property (strong, nonatomic) IBOutlet UIButton *formants;

- (IBAction)SwitchPressed:(id)sender;

- (IBAction)betaValue:(id)sender;
- (IBAction)buttonPressed:(id)sender;

- (IBAction)beta1Value:(id)sender;

@end

