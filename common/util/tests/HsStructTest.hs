{-
  Copyright (c) Meta Platforms, Inc. and affiliates.
  All rights reserved.

  This source code is licensed under the BSD-style license found in the
  LICENSE file in the root directory of this source tree.
-}

module HsStructTest (main) where

import Test.HUnit
import TestRunner

import Control.Exception
import qualified Data.Aeson as Aeson
import Data.ByteString (ByteString, useAsCStringLen)
import Data.ByteString.Unsafe (unsafeUseAsCStringLen)
import qualified Data.HashMap.Strict as HashMap
import qualified Data.HashSet as HashSet
import Data.IntMap.Strict (IntMap)
import qualified Data.IntMap.Strict as IntMap
import qualified Data.Map.Strict as Map
import Data.Scientific (Scientific, fromFloatDigits)
import Data.Text (Text)
import qualified Data.Text.Encoding as Text (encodeUtf8)
import Data.Tuple.Extra ((***))
import qualified Data.Vector as Vector
import qualified Data.Vector.Storable as VectorStorable
import Foreign
import Foreign.C.Types (CBool (..), CChar)

import Foreign.CPP.HsStruct
import Foreign.CPP.Marshallable
import Util.Aeson

import qualified HsStructTestTypes as TT

foreign import ccall unsafe "fillCppTuple"
  c_fillCppTuple :: Ptr (HsStdTuple (Int32, HsJSON, TT.OnlyMovable, HsEither HsText Int)) -> IO ()

stdTupleTest :: Test
stdTupleTest = TestLabel "stdTupleTest" $ TestCase $ do
  withCxxObject (HsStdTuple t_val) (testTuple "tuple roundtrip")

  withDefaultCxxObject $ \ptr -> do
    c_fillCppTuple ptr
    testTuple "peeked" ptr

  where
    i_val = 42 :: Int32
    j_val = Aeson.Bool True
    n_val = TT.OnlyMovable 8
    e_val = Left (HsText "wut") :: Either HsText Int
    t_val = (i_val, HsJSON j_val, n_val, HsEither e_val)

    testTuple pref ptr = do
      (HsStdTuple (peeked_i, HsJSON peeked_j, peeked_n, HsEither peeked_e)) <-
        peek ptr
      assertEqual (pref ++ " int") i_val peeked_i
      assertEqual (pref ++ " json") j_val peeked_j
      assertEqual (pref ++ " OnlyMovable") n_val peeked_n
      case (e_val, peeked_e) of
        (Left (HsText a), Left (HsText b)) ->
          assertEqual (pref ++ " Either") a b
        _ -> assertFailure (pref ++ " Either peeking failed")

stdVariantTest :: Test
stdVariantTest = TestLabel "stdVariantTest" $
  TestCase $ do
    let i_val = 1337
    withCxxObject (TT.I i_val) $ \i_p -> do
      peeked_i <- peek i_p :: IO TT.MyVariant
      case peeked_i of
        TT.I peeked_i_val -> assertEqual "int roundtrip" i_val peeked_i_val
        _ -> assertFailure "Didn't get int back from roundtrip"

    let s_val = "WUT"
    withCxxObject (TT.S (HsByteString s_val)) $ \s_p -> do
      peeked_s <- peek s_p :: IO TT.MyVariant
      case peeked_s of
        TT.S (HsByteString peeked_s_val) ->
          assertEqual "string roundtrip" s_val peeked_s_val
        _ -> assertFailure "Didn't get string back from roundtrip"

    let opt_val = TT.J (HsOption (Just (HsJSON (Aeson.Bool True))))
    withCxxObject (HsOption (Just opt_val)) $ \j_p -> do
      HsOption peeked_j <- peek j_p :: IO (HsOption TT.MyVariant)
      case peeked_j of
        Just (TT.J (HsOption (Just (HsJSON (Aeson.Bool v))))) ->
          assertBool "Json bool roundtrip" v
        _ -> assertFailure "Didn't get option of Json back"

arrayCxxTest :: Test
arrayCxxTest = TestLabel "arrayCxxTest" $
  TestCase $ do
    withDefaultCxxObject $ \p -> do
      HsList v <- peek p :: IO (HsList HsText)
      assertEqual "default is empty" [] (map hsText v)

    let pokey = ["1", "2", "3"]
    withCxxObject (HsList (map HsText pokey)) $ \p -> do
      HsList v <- peek p
      assertEqual "list of strings" pokey (map hsText v)

    withDefaultCxxObject $ \p -> do
      HsArray v <- peek p :: IO (HsArray HsText)
      assertEqual "default is empty" [] (map hsText (Vector.toList v))

    withCxxObject (HsArray (Vector.fromList (map HsText pokey))) $ \p -> do
      HsArray v <- peek p
      assertEqual "array of strings" pokey (Vector.toList (Vector.map hsText v))

    let booley = fmap toCBool [False, True, True, False, False, True]
    withCxxObject (HsArray (Vector.fromList booley)) $ \p -> do
      HsArray v <- peek p
      assertEqual "array of bool" booley (Vector.toList v)

setCxxTest :: Test
setCxxTest = TestLabel "setCxxTest" $
  TestCase $ do
    withDefaultCxxObject $ \p -> do
      HsHashSet s <- peek p :: IO (HsHashSet HsText)
      assertEqual
        "default is empty"
        HashSet.empty
        (HashSet.map hsText s)

    let pokey = ["1", "2", "3", "2"]
    let pokeySet = HashSet.fromList pokey
    withCxxObject (HsHashSet $ HashSet.map HsText pokeySet) $ \p -> do
      HsHashSet s <- peek p
      assertEqual
        "set of strings"
        pokeySet
        (HashSet.map hsText s)

    let pokeyInt :: [Int] = [1, 2, 3, 2]
    let pokeyIntSet = HashSet.fromList pokeyInt
    withCxxObject (HsHashSet pokeyIntSet) $ \p -> do
      HsHashSet s <- peek p
      assertEqual "set of ints" pokeyIntSet s

    let pokeyDouble :: [Double] = [1.0, 2.0, 3.0, 2.0]
    let pokeyDoubleSet = HashSet.fromList pokeyDouble
    withCxxObject (HsHashSet pokeyDoubleSet) $ \p -> do
      HsHashSet s <- peek p
      assertEqual
        "set of doubles"
        pokeyDoubleSet
        s

mapCxxTest :: Test
mapCxxTest = TestLabel "mapCxxTest" $
  TestCase $ do
    let map_kv = \kf vf -> HashMap.fromList . map (kf *** vf) . HashMap.toList
    withDefaultCxxObject $ \p -> do
      HsHashMap s <- peek p :: IO (HsHashMap HsText HsText)
      assertEqual
        "default is empty"
        HashMap.empty
        (map_kv hsText hsText s)

    let pokey :: [(Text, Text)] =
          [("1", "a"), ("2", "b"), ("3", "c")]
    let pokeyMap = HashMap.fromList pokey
    withCxxObject (HsHashMap $ map_kv HsText HsText pokeyMap) $ \p -> do
      HsHashMap s <- peek p
      assertEqual
        "map from strings to strings"
        pokeyMap
        (map_kv hsText hsText s)

    let pokeyDuplicate :: [(Text, Text)] =
          [("1", "a"), ("2", "b"), ("3", "c"), ("2", "d")]
    let pokeyDuplicateMap = HashMap.fromList pokeyDuplicate
    withCxxObject (HsHashMap $ map_kv HsText HsText pokeyDuplicateMap) $ \p ->
      do
        HsHashMap s <- peek p
        assertEqual
          "map from strings to strings with duplicates"
          pokeyDuplicateMap
          (map_kv hsText hsText s)

    let pokeyInt :: [(Int32, Text)] = [(1, "a"), (2, "b"), (3, "c"), (2, "d")]
    let pokeyIntMap = HashMap.fromList pokeyInt
    withCxxObject (HsHashMap $ map_kv id HsText pokeyIntMap) $ \p -> do
      HsHashMap s <- peek p
      assertEqual
        "map from ints to strings with duplicates"
        pokeyIntMap
        (map_kv id hsText s)

    let pokeyDouble :: [(Double, Int32)] =
          [(1.0, 19), (2.0, 29), (3.0, 39), (2.0, 9)]
    let pokeyDoubleMap = HashMap.fromList pokeyDouble
    withCxxObject (HsHashMap pokeyDoubleMap) $ \p -> do
      HsHashMap s <- peek p
      assertEqual
        "map from doubles to ints with duplicates"
        pokeyDoubleMap
        s

toCBool :: Bool -> CBool
toCBool = fromBool

stringPieceCxxTest :: Test
stringPieceCxxTest = TestLabel "stringPieceCxxTest" $
  TestCase $ do
    withDefaultCxxObject $ \p -> do
      HsRange ptr len <- peek p :: IO HsStringPiece
      assertEqual "ptr" nullPtr ptr
      assertEqual "len" 0 len

    let pokeString = "pokey" :: ByteString
    useAsCStringLen pokeString $ \(pPtr, pLen) ->
      withCxxObject (HsRange pPtr pLen) $ \p -> do
        HsRange rPtr rLen <- peek p
        assertEqual "rPtr" pPtr rPtr
        assertEqual "rLen" pLen rLen

optionTest :: Test
optionTest = TestLabel "optionTest" $
  TestCase $ do
    withDefaultCxxObject $ \p -> do
      HsOption v <- peek p
      case v of
        Just (HsText _) -> assertFailure "Should not have received anything"
        Nothing -> return ()

    let pokeString = "pokey"
    withCxxObject (HsOption (Just $ HsText pokeString)) $ \p -> do
      HsOption o <- peek p
      case o of
        Just (HsText v) -> assertEqual "alloc text was set" pokeString v
        Nothing -> assertFailure "Should have received something"

    let pokeVal = 5 :: Int64
    withCxxObject (HsOption (Just pokeVal)) $ \p -> do
      HsOption o <- peek p
      case o of
        Just v -> assertEqual "alloc int was set" pokeVal v
        Nothing -> assertFailure "Should have received something"

allocUtilsTest :: Test
allocUtilsTest = TestLabel "allocUtilsTest" $
  TestCase $ do
    let pokeString = "pokey"
    withDefaultCxxObject $ \p -> do
      assign p (HsText pokeString)
      HsText v <- peek p
      assertEqual "poked string was set" pokeString v

    withCxxObject (HsText pokeString) $ \p -> do
      HsText v <- peek p
      assertEqual "alloc string was set" pokeString v

foreign import ccall unsafe "checkHsText"
  c_checkHsText :: Ptr HsText -> Ptr CChar -> Word -> IO CBool

pokeHsTextTest :: Test
pokeHsTextTest = TestLabel "pokeHsTextTest" $
  TestCase $ do
    let ctorString = "constructed string"
        pokeString = "poked string"
    withCxxObject (HsText ctorString) $ \p -> do
      check_1 <- unsafeUseAsCStringLen (Text.encodeUtf8 ctorString) $
        \(str, len) -> c_checkHsText p str (fromIntegral len)
      assertBool "constructed string not matches" (toBool check_1)

      assign p (HsText pokeString)
      check_2 <- unsafeUseAsCStringLen (Text.encodeUtf8 pokeString) $
        \(str, len) -> c_checkHsText p str (fromIntegral len)
      assertBool "poked string not matches" (toBool check_2)

maybeTest :: Test
maybeTest = TestLabel "Maybe" $
  TestCase $ do
    (nothing :: Maybe String) <- coerce $ peek =<< getNothing
    assertEqual "Nothing" Nothing nothing
    (just :: Maybe String) <- coerce $ peek =<< getJust
    assertEqual "Just Text" (Just "just") just

foreign import ccall unsafe "getNothing"
  getNothing :: IO (Ptr (HsMaybe HsString))

foreign import ccall unsafe "getJust"
  getJust :: IO (Ptr (HsMaybe HsString))

maybeNonmovableTest :: Test
maybeNonmovableTest = TestLabel "HsMaybeNonmovable" $
  TestCase $ do
    HsMaybe got <- peek =<< getHsMaybeNonmovable
    assertEqual "get" (Just $ TT.Nonmovable 9 "Crino") got
    p <- unsafeUseAsCStringLen descritpion $ \(str, len) ->
      mask_ $ toSharedPtr =<< createHsMaybeNonmovable 101 str len
    HsMaybe created <- withForeignPtr p peek
    assertEqual "created" (Just $ TT.Nonmovable 101 descritpion) created
  where
    descritpion = "descritpion"

foreign import ccall unsafe "getHsMaybeNonmovable"
  getHsMaybeNonmovable :: IO (Ptr (HsMaybe TT.Nonmovable))

foreign import ccall unsafe "createHsMaybeNonmovable"
  createHsMaybeNonmovable ::
    Int -> Ptr CChar -> Int -> IO (Ptr (HsMaybe TT.Nonmovable))

peekHsEitherTest :: Test
peekHsEitherTest = TestLabel "peekHsEitherTest" $
  TestCase $ do
    (left :: Either String Int) <- coerce $ peek =<< getLeft
    assertEqual "Left" (Left "error") left
    (right :: Either String Int) <- coerce $ peek =<< getRight
    assertEqual "Right" (Right 42) right

foreign import ccall unsafe "getLeft"
  getLeft :: IO (Ptr (HsEither HsString Int))

foreign import ccall unsafe "getRight"
  getRight :: IO (Ptr (HsEither HsString Int))

pokeHsEitherTest :: Test
pokeHsEitherTest = TestLabel "pokeHsEitherTest" $
  TestCase $ do
    let initialValue :: HsEither HsText Int
        initialValue = HsEither (Left (HsText "string from haskell"))
        updatedValue :: HsEither HsText Int
        updatedValue = HsEither (Right 42)
    withCxxObject initialValue $ \p -> do
      check_1 <- c_checkHsEither p 1
      assertBool "Left value not matches" (toBool check_1)
      assign p updatedValue
      check_2 <- c_checkHsEither p 2
      assertBool "Right value not matches" (toBool check_2)

foreign import ccall unsafe "checkHsEither"
  c_checkHsEither :: Ptr (HsEither HsText Int) -> Int -> IO CBool

arrayTest :: Test
arrayTest = TestLabel "Array" $
  TestCase $ do
    s <- fmap (fmap hsString . hsArray) $ peek =<< getArray
    assertEqual "Vector String" (Vector.fromList ["foo", "bar"]) s
    bs <- fmap (map hsByteString . hsList) $ peek =<< getArray
    assertEqual "[ByteString]" ["foo", "bar"] bs
    t <- fmap (map hsText . hsList) $ peek =<< getArray
    assertEqual "[Text]" ["foo", "bar"] t
    v <- fmap hsArrayStorable $ peek =<< getArrayInt64
    assertEqual "VectorStorable Int64" (VectorStorable.fromList [1 :: Int64, 2, 3]) v
    bv <- fmap hsArray $ peek =<< getArrayCBool
    assertEqual "CBool Size" 1 (sizeOf (CBool 0))
    assertEqual "CBool Align" 1 (alignment (CBool 1))
    let expected = fmap toCBool [True, False, True, True, True, False]
    assertEqual "Vector Bool" (Vector.fromList expected) bv

foreign import ccall unsafe "getArray"
  getArray :: IO (Ptr a)

foreign import ccall unsafe "getArrayInt64"
  getArrayInt64 :: IO (Ptr a)

foreign import ccall unsafe "getArrayCBool"
  getArrayCBool :: IO (Ptr a)

setTest :: Test
setTest = TestLabel "Set" $
  TestCase $ do
    s :: HsHashSet HsText <- peek =<< getSet
    assertEqual
      "HashSet String"
      (HashSet.fromList ["foo", "bar"])
      (HashSet.map hsText $ hsHashSet s)

    si :: HsHashSet Int64 <- peek =<< getSetInt64
    assertEqual
      "HashSet Int64"
      (HashSet.fromList [1, 2, 3])
      (hsHashSet si)

foreign import ccall unsafe "getSet"
  getSet :: IO (Ptr a)

foreign import ccall unsafe "getSetInt64"
  getSetInt64 :: IO (Ptr a)

mapTest :: Test
mapTest = TestLabel "Map" $
  TestCase $ do
    HsMap m <- peek =<< getIntMap
    assertEqual "Map Int Int" (Map.fromList assocs) m
    HsIntMap im <- peek =<< getIntMap
    assertEqual "IntMap Int" (IntMap.fromList assocs) im
    HsHashMap hm <- peek =<< getIntHashMap
    assertEqual
      "HashMap Int Int"
      (HashMap.fromList assocs)
      hm
  where
    assocs = [(2, 4), (3, 9), (5, 25), (7, 49)] :: [(Int, Int)]

foreign import ccall unsafe "getIntMap"
  getIntMap :: IO (Ptr a)

foreign import ccall unsafe "getIntHashMap"
  getIntHashMap :: IO (Ptr a)

pairTest :: Test
pairTest = TestLabel "Pair" $
  TestCase $ do
    HsPair (HsText f, s) :: HsPair HsText Int <- peek =<< getPair
    assertEqual "Pair" ("foo", 3) (f, s)

foreign import ccall unsafe "getPair"
  getPair :: IO (Ptr a)

type Nested = KeyMap (IntMap [Maybe Text])
type HsNested = HsObject (HsIntMap (HsList (HsMaybe HsText)))

nestedTest :: Test
nestedTest = TestLabel "nested" $
  TestCase $ do
    actual :: Nested <- coerce $ bracket createNested destroyNested peek
    assertEqual "Nested" expected actual
  where
    expected =
      objectFromList
        [ (keyFromText "zero", IntMap.empty)
        , (keyFromText "one", IntMap.singleton 1 [])
        , (keyFromText "two", IntMap.singleton 2 [Nothing])
        ,
          ( keyFromText "more"
          , IntMap.fromList
              [ (3, [Nothing])
              , (4, [Just "two"])
              , (5, [Nothing, Just ""])
              , (6, [Just "two", Just "three"])
              ]
          )
        ]

foreign import ccall unsafe "createNested"
  createNested :: IO (Ptr HsNested)

foreign import ccall unsafe "destroyNested"
  destroyNested :: Ptr HsNested -> IO ()

jsonRoundTrip :: Test
jsonRoundTrip = TestLabel "json" $
  TestCase $ do
    roundTrip Aeson.Null
    roundTrip (Aeson.Bool True)
    roundTrip (Aeson.Bool False)
    roundTrip (Aeson.Number (read "42" :: Scientific))
    roundTrip (Aeson.Number (read "-42" :: Scientific))
    roundTrip (Aeson.Number (fromFloatDigits (3.14159 :: Double)))
    roundTrip (Aeson.String "Data.Aeson")
    roundTrip
      ( Aeson.Array $
          Vector.fromList
            [Aeson.Null, Aeson.Bool True, Aeson.String "VectorVector"]
      )
    roundTrip
      ( Aeson.Object $
          objectFromList
            [(keyFromText "foo", Aeson.Bool True), (keyFromText "bar", Aeson.Bool False)]
      )
  where
    roundTrip j = withCxxObject (HsJSON j) $ \p -> do
      HsJSON v <- peek p
      assertEqual "json round trip" j v

main :: IO ()
main =
  testRunner $
    TestList
      [ pokeHsTextTest
      , maybeTest
      , maybeNonmovableTest
      , peekHsEitherTest
      , pokeHsEitherTest
      , arrayTest
      , mapCxxTest
      , mapTest
      , pairTest
      , nestedTest
      , allocUtilsTest
      , optionTest
      , arrayCxxTest
      , setCxxTest
      , setTest
      , stringPieceCxxTest
      , jsonRoundTrip
      , stdVariantTest
      , stdTupleTest
      ]
