// Copyright (c) 2012 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#include "base/metrics/statistics_recorder.h"
#include "base/test/launcher/unit_test_launcher.h"
#include "build/build_config.h"
#include "crypto/nss_util.h"
#include "net/socket/client_socket_pool_base.h"
#include "net/socket/ssl_server_socket.h"
#include "net/spdy/spdy_session.h"
#include "net/test/net_test_suite.h"

#if defined(OS_ANDROID)
#include "base/android/jni_android.h"
#include "base/android/jni_registrar.h"
#include "base/test/test_file_util.h"
#include "net/android/net_jni_registrar.h"
#include "url/android/url_jni_registrar.h"
#endif

#if !defined(DISABLE_V8_IN_NET)
#include "net/proxy/proxy_resolver_v8.h"
#endif

using net::internal::ClientSocketPoolBaseHelper;
using net::SpdySession;

int main(int argc, char** argv) {
  // Record histograms, so we can get histograms data in tests.
  base::StatisticsRecorder::Initialize();

#if defined(OS_ANDROID)
  const base::android::RegistrationMethod kNetTestRegisteredMethods[] = {
    {"NetAndroid", net::android::RegisterJni},
    {"TestFileUtil", base::RegisterContentUriTestUtils},
    {"UrlAndroid", url::android::RegisterJni},
  };

  // Register JNI bindings for android. Doing it early as the test suite setup
  // may initiate a call to Java.
  base::android::RegisterNativeMethods(
      base::android::AttachCurrentThread(),
      kNetTestRegisteredMethods,
      arraysize(kNetTestRegisteredMethods));
#endif

  NetTestSuite test_suite(argc, argv);
  ClientSocketPoolBaseHelper::set_connect_backup_jobs_enabled(false);

#if defined(OS_WIN)
  // We want to be sure to init NSPR on the main thread.
  crypto::EnsureNSPRInit();
#endif

  // Enable support for SSL server sockets, which must be done while
  // single-threaded.
  net::EnableSSLServerSockets();

#if !defined(DISABLE_V8_IN_NET)
  net::ProxyResolverV8::EnsureIsolateCreated();
#endif

  return base::LaunchUnitTests(
      argc, argv, base::Bind(&NetTestSuite::Run,
                             base::Unretained(&test_suite)));
}
