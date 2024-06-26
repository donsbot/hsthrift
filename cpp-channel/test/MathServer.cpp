/*
 * Copyright (c) Meta Platforms, Inc. and affiliates.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree.
 */

#include <thrift/lib/cpp2/util/ScopedServerInterfaceThread.h>
#include "test/if/gen-cpp2/Calculator.h"

using namespace apache::thrift;
using namespace cpp2;
using namespace std;

class CalculatorServiceHandler : public CalculatorSvIf {
 public:
  CalculatorServiceHandler() : value(42) {}

  int64_t add(int64_t x, int64_t y) override {
    return x + y;
  }

  double divide(double dividend, double divisor) override {
    return dividend / divisor;
  }

  void put(int64_t val) override {
    value = val;
  }

  int64_t get() override {
    return value;
  }

  void unimplemented() override {}

 private:
  int64_t value;
};

ScopedServerInterfaceThread* createServer(int64_t& /*port*/) {
  return new ScopedServerInterfaceThread(
      make_shared<CalculatorServiceHandler>()
#ifdef IPV4
          ,
      "127.0.0.1"); // necessary to force IPV4 in e.g CI/docker
#else
          ,
      "::1");
#endif
}

extern "C" {

ScopedServerInterfaceThread* make_cpp_server(int64_t& port) noexcept {
  return createServer(port);
}

int64_t get_port_from_server(ScopedServerInterfaceThread* sit) noexcept {
  return sit->getPort();
}

void destroy_cpp_server(ScopedServerInterfaceThread* sit) noexcept {
  delete sit;
}
}
