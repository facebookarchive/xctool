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

#import "ReportStatus.h"

#import "EventGenerator.h"
#import "ReporterEvents.h"
#import "XCToolUtil.h"

NSString *ReporterMessageLevelToString(ReporterMessageLevel level) {
  switch (level) {
    case REPORTER_MESSAGE_DEBUG:
      return @"Debug";
    case REPORTER_MESSAGE_VERBOSE:
      return @"Verbose";
    case REPORTER_MESSAGE_INFO:
      return @"Info";
    case REPORTER_MESSAGE_WARNING:
      return @"Warning";
    case REPORTER_MESSAGE_ERROR:
      return @"Error";
  }
}

static void ReportStatusMessageBeginWithTimestamp(NSArray *reporters, ReporterMessageLevel level, NSString *message) {
  NSDictionary *event = EventDictionaryWithNameAndContent(
    kReporter_Events_BeginStatus, @{
      kReporter_BeginStatus_MessageKey: message,
      kReporter_BeginStatus_LevelKey: ReporterMessageLevelToString(level),
      });
  PublishEventToReporters(reporters, event);
}

static void ReportStatusMessageEndWithTimestamp(NSArray *reporters, ReporterMessageLevel level, NSString *message) {
  NSDictionary *event = EventDictionaryWithNameAndContent(
    kReporter_Events_EndStatus, @{
      kReporter_EndStatus_MessageKey: message,
      kReporter_EndStatus_LevelKey: ReporterMessageLevelToString(level),
      });
  PublishEventToReporters(reporters, event);
}

void ReportStatusMessage(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  // This is a one-shot status message that has no begin/end, so we send the
  // same timestamp for both.
  ReportStatusMessageBeginWithTimestamp(reporters, level, message);
  ReportStatusMessageEndWithTimestamp(reporters, level, message);
}

void ReportStatusMessageBegin(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  ReportStatusMessageBeginWithTimestamp(reporters, level, message);
}

void ReportStatusMessageEnd(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[NSString alloc] initWithFormat:format arguments:args];
  va_end(args);

  ReportStatusMessageEndWithTimestamp(reporters, level, message);
}
