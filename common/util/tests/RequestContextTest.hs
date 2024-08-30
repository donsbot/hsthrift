{-
  Copyright (c) Meta Platforms, Inc. and affiliates.
  All rights reserved.

  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree.
-}

module RequestContextTest
  ( main
  ) where

import Test.HUnit
import TestRunner

import Control.Exception

import RequestContextTestHelper
import Util.RequestContext

shallowCopyRequestContextScopeGuardTest :: Test
shallowCopyRequestContextScopeGuardTest =
  TestLabel "shallowCopyRequestContextScopeGuardTest" $ TestCase $ do
    assertEqual "top:init" 0 =<< getCurrentTestValue
    setCurrentTestValue 1
    assertEqual "top:before" 1 =<< getCurrentTestValue
    withShallowCopyRequestContextScopeGuard $ do
      assertEqual "outer:init" 1 =<< getCurrentTestValue
      setCurrentTestValue 10
      assertEqual "outer:before1" 10 =<< getCurrentTestValue
      withShallowCopyRequestContextScopeGuard $ do
        setCurrentTestValue 101
        assertEqual "inner1" 101 =<< getCurrentTestValue
      assertEqual "outer:before2" 10 =<< getCurrentTestValue
      handle (\(ErrorCall s) -> assertEqual "exception" "test" s) $
        withShallowCopyRequestContextScopeGuard $ do
          setCurrentTestValue 102
          assertEqual "inner2" 102 =<< getCurrentTestValue
          throwIO $ ErrorCall "test"
      assertEqual "outer:after" 10 =<< getCurrentTestValue
    assertEqual "top:after" 1 =<< getCurrentTestValue

main :: IO ()
main = testRunner $ TestList
  [ shallowCopyRequestContextScopeGuardTest
  ]
