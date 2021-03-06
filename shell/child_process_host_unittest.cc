// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Note: This file also tests child_process.*.

#include "shell/child_process_host.h"

#include "base/logging.h"
#include "base/macros.h"
#include "base/message_loop/message_loop.h"
#include "mojo/common/message_pump_mojo.h"
#include "shell/context.h"
#include "testing/gtest/include/gtest/gtest.h"

namespace mojo {
namespace shell {
namespace test {
namespace {

class TestChildProcessHostDelegate : public ChildProcessHost::Delegate {
 public:
  TestChildProcessHostDelegate() {}
  ~TestChildProcessHostDelegate() {}
  void WillStart() override {
    VLOG(2) << "TestChildProcessHostDelegate::WillStart()";
  }
  void DidStart(bool success) override {
    VLOG(2) << "TestChildProcessHostDelegate::DidStart(" << success << ")";
    base::MessageLoop::current()->QuitWhenIdle();
  }
};

typedef testing::Test ChildProcessHostTest;

#if defined(OS_ANDROID)
// TODO(qsr): Multiprocess shell tests are not supported on android.
#define MAYBE_Basic DISABLED_Basic
#else
#define MAYBE_Basic Basic
#endif  // defined(OS_ANDROID)
TEST_F(ChildProcessHostTest, MAYBE_Basic) {
  Context context;
  base::MessageLoop message_loop(
      scoped_ptr<base::MessagePump>(new common::MessagePumpMojo()));
  context.Init();
  TestChildProcessHostDelegate child_process_host_delegate;
  ChildProcessHost child_process_host(&context, &child_process_host_delegate,
                                      ChildProcess::TYPE_TEST);
  child_process_host.Start();
  message_loop.Run();
  int exit_code = child_process_host.Join();
  VLOG(2) << "Joined child: exit_code = " << exit_code;
  EXPECT_EQ(0, exit_code);
}

}  // namespace
}  // namespace test
}  // namespace shell
}  // namespace mojo
