//
//  XUnitReporter.h
//  xctool
//
//  Created by Justin Mutter on 2013-05-03.
//  Copyright (c) 2013 Fred Potter. All rights reserved.
//

#import "Reporter.h"

@interface XUnitReporter : Reporter

@property (nonatomic, retain) NSXMLDocument *xmlDocument;
@property (nonatomic, strong) NSFileHandle *outputHandle;

@end
