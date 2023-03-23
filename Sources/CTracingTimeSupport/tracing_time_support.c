//
// Created by Konrad 'ktoso' Malawski on 3/23/23.
//

#include "include/tracing_time_support.h"

#if __HAS_DISPATCH__
#include <dispatch/dispatch.h>
#else
  #ifndef NSEC_PER_SEC
  #define NSEC_PER_SEC 1000000000UL
  #endif
#endif

//#if TARGET_OS_MAC || TARGET_OS_LINUX || TARGET_OS_BSD || TARGET_OS_WASI
#include <sys/time.h>
//#endif

const SDTTimeInterval kCFAbsoluteTimeIntervalSince1970 = 978307200.0L;
const SDTTimeInterval kCFAbsoluteTimeIntervalSince1904 = 3061152000.0L;


//#if TARGET_OS_WIN32
//CFAbsoluteTime CFAbsoluteTimeGetCurrent(void) {
//  SYSTEMTIME stTime;
//  FILETIME ftTime;
//
//  GetSystemTime(&stTime);
//  SystemTimeToFileTime(&stTime, &ftTime);
//
//  // 100ns intervals since NT Epoch
//  uint64_t result = ((uint64_t)ftTime.dwHighDateTime << 32)
//                    | ((uint64_t)ftTime.dwLowDateTime << 0);
//  return result * 1.0e-7 - kCFAbsoluteTimeIntervalSince1601;
//}
//#else
SDTAbsoluteTime SDTAbsoluteTimeGetCurrent() {
  SDTAbsoluteTime ret;
  struct timeval tv;
  gettimeofday(&tv, NULL);
  ret = (SDTTimeInterval)tv.tv_sec - kCFAbsoluteTimeIntervalSince1970;
  ret += (1.0E-6 * (SDTTimeInterval)tv.tv_usec);
  return ret;
}

//#endif