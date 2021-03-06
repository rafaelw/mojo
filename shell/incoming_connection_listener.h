// Copyright 2014 The Chromium Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

#ifndef SHELL_INCOMING_CONNECTION_LISTENER_H_
#define SHELL_INCOMING_CONNECTION_LISTENER_H_

#include "base/files/file_path.h"
#include "base/memory/weak_ptr.h"
#include "base/threading/thread_checker.h"
#include "shell/domain_socket/socket_descriptor.h"
#include "shell/domain_socket/unix_domain_server_socket_posix.h"

namespace mojo {
namespace shell {

// Asynchronously listens for incoming connections on a unix domain
// socket at the provided path. Expects the parent directory in the
// path to exist.  Must be run on an IO thread.
class IncomingConnectionListener {
 public:
  class Delegate {
   public:
    virtual ~Delegate() {}  // Abstract base class, so this is safe.

    // Called when listening has started. rv is from
    // shell/domain_socket/net_error_list.h
    virtual void OnListening(int rv) = 0;

    // Called every time an incoming connection is accepted. The delegate
    // takes ownership of incoming.
    virtual void OnConnection(SocketDescriptor incoming) = 0;
  };

  IncomingConnectionListener(const base::FilePath& socket_path,
                             Delegate* delegate);
  virtual ~IncomingConnectionListener();

  // Attempts to bind a unix domain socket, set up for listening, at
  // socket_path_.
  // Regardless of success or failure, calls delegate->OnListening() with a
  // status code. If the socket was successfully created, begins asynchronously
  // waiting to accept incoming connections.
  void StartListening();

 private:
  // Tells listen_socket_ to perform a non-blocking accept(). It may succeed
  // or fail immediately, or asynchronously wait for a later connection attempt.
  // Regardless, when it returns a definitive result (OK or a failing error),
  // calls OnAccept().
  void Accept();

  // If rv indicates success, incoming_socket_ should be populated with a
  // connected FD. Hands this off to delegate->OnConnection() and goes
  // back to non-blocking accept().
  // Upon error, logs the error and goes back to non-blocking accept().
  void OnAccept(int rv);

  Delegate* const delegate_;

  const base::FilePath socket_path_;
  UnixDomainServerSocket listen_socket_;
  base::ThreadChecker listen_thread_checker_;

  SocketDescriptor incoming_socket_;

  base::WeakPtrFactory<IncomingConnectionListener> weak_ptr_factory_;
};

}  // namespace shell
}  // namespace mojo

#endif  // SHELL_INCOMING_CONNECTION_LISTENER_H_
