#import "EventJSONGenerator.h"

NSMutableDictionary *EventDictionaryWithNameAndContent(NSString *name, NSDictionary *content)
{
    NSMutableDictionary *eventJSON = [NSMutableDictionary dictionaryWithDictionary:@{@"event" : name,
                                                                                     kReporter_Timestamp_Key : kReporter_Timestamp_Time}];
    [eventJSON addEntriesFromDictionary:content];
    return eventJSON;
}
