//
//  DetailViewController.h
//  MKDocumentSync
//
//  Created by Mugunth Kumar on 6/2/12.
//  Copyright (c) 2012 Steinlogic. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface DetailViewController : UIViewController

@property (strong, nonatomic) id detailItem;

@property (strong, nonatomic) IBOutlet UILabel *detailDescriptionLabel;

@end
