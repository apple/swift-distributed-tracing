//
// Created by Konrad 'ktoso' Malawski on 3/23/23.
//

#ifndef SWIFT_DISTRIBUTED_TRACING_TRACING_TIME_SUPPORT_H
#define SWIFT_DISTRIBUTED_TRACING_TRACING_TIME_SUPPORT_H


typedef double SDTTimeInterval;
typedef SDTTimeInterval SDTAbsoluteTime;
/* absolute time is the time interval since the reference date */
/* the reference date (epoch) is 00:00:00 1 January 2001. */

SDTAbsoluteTime SDTAbsoluteTimeGetCurrent();

#endif //SWIFT_DISTRIBUTED_TRACING_TRACING_TIME_SUPPORT_H
