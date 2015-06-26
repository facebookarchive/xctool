//
// Copyright 2004-present Facebook. All Rights Reserved.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//    http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
//

#import <Foundation/Foundation.h>

typedef NS_ENUM(NSInteger, ReporterMessageLevel) {
  REPORTER_MESSAGE_DEBUG,
  REPORTER_MESSAGE_VERBOSE,
  REPORTER_MESSAGE_INFO,
  REPORTER_MESSAGE_WARNING,
  REPORTER_MESSAGE_ERROR,
} ;

NSString *ReporterMessageLevelToString(ReporterMessageLevel level);

/**
 Reports a status message to the reporters, meant to express the beginning of
 an operation.  The caller must call ReportStatusMessageEnd() when the operation
 has finished.
 */
void ReportStatusMessageBegin(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) NS_FORMAT_FUNCTION(3, 4);

/**
 Reports a status message to the reporters, meant to express the end of an
 operation.  StatusMessageBegin() must be called first.
 */
void ReportStatusMessageEnd(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) NS_FORMAT_FUNCTION(3, 4);

/**
 Reports a one-shot status message to the reporters that has no begin/end.
 */
void ReportStatusMessage(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) NS_FORMAT_FUNCTION(3, 4);
