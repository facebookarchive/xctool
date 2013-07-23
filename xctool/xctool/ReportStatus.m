//
// Copyright 2013 Facebook
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

static void ReportStatusMessageBeginWithTimestamp(NSArray *reporters, double timestamp, ReporterMessageLevel level, NSString *message) {
  NSDictionary *event = @{@"event": kReporter_Events_BeginStatus,
                          kReporter_BeginStatus_MessageKey: message,
                          kReporter_BeginStatus_TimestampKey: @(timestamp),
                          kReporter_BeginStatus_LevelKey: ReporterMessageLevelToString(level),
                          };
  PublishEventToReporters(reporters, event);
}

static void ReportStatusMessageEndWithTimestamp(NSArray *reporters, double timestamp, ReporterMessageLevel level, NSString *message) {
  NSDictionary *event = @{@"event": kReporter_Events_EndStatus,
                          kReporter_EndStatus_MessageKey: message,
                          kReporter_EndStatus_TimestampKey: @(timestamp),
                          kReporter_EndStatus_LevelKey: ReporterMessageLevelToString(level),
                          };
  PublishEventToReporters(reporters, event);
}

void ReportStatusMessage(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);

  // This is a one-shot status message that has no begin/end, so we send the
  // same timestamp for both.
  double now = [[NSDate date] timeIntervalSince1970];
  ReportStatusMessageBeginWithTimestamp(reporters, now, level, message);
  ReportStatusMessageEndWithTimestamp(reporters, now, level, message);
}

void ReportStatusMessageBegin(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);

  ReportStatusMessageBeginWithTimestamp(reporters, [[NSDate date] timeIntervalSince1970], level, message);
}

void ReportStatusMessageEnd(NSArray *reporters, ReporterMessageLevel level, NSString *format, ...) {
  va_list args;
  va_start(args, format);
  NSString *message = [[[NSString alloc] initWithFormat:format arguments:args] autorelease];
  va_end(args);

  ReportStatusMessageEndWithTimestamp(reporters, [[NSDate date] timeIntervalSince1970], level, message);
}
