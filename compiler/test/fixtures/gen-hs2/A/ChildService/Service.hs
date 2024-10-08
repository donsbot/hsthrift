-----------------------------------------------------------------
-- Autogenerated by Thrift
--
-- DO NOT EDIT UNLESS YOU ARE SURE THAT YOU KNOW WHAT YOU ARE DOING
--  @generated
-----------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE BangPatterns #-}
{-# OPTIONS_GHC -fno-warn-unused-imports#-}
{-# OPTIONS_GHC -fno-warn-overlapping-patterns#-}
{-# OPTIONS_GHC -fno-warn-incomplete-patterns#-}
{-# OPTIONS_GHC -fno-warn-incomplete-uni-patterns#-}
{-# OPTIONS_GHC -fno-warn-incomplete-record-updates#-}
{-# LANGUAGE GADTs #-}
module A.ChildService.Service
       (ChildServiceCommand(..), reqName', reqParser', respWriter',
        methodsInfo')
       where
import qualified A.ParentService.Service as ParentService
import qualified A.Types as Types
import qualified B.Types as B
import qualified Control.Exception as Exception
import qualified Control.Monad.ST.Trans as ST
import qualified Control.Monad.Trans.Class as Trans
import qualified Data.ByteString.Builder as Builder
import qualified Data.Default as Default
import qualified Data.HashMap.Strict as HashMap
import qualified Data.Int as Int
import qualified Data.Map.Strict as Map
import qualified Data.Proxy as Proxy
import qualified Data.Text as Text
import qualified Prelude as Prelude
import qualified Thrift.Binary.Parser as Parser
import qualified Thrift.Codegen as Thrift
import qualified Thrift.Processor as Thrift
import qualified Thrift.Protocol.ApplicationException.Types
       as Thrift
import Control.Applicative ((<*), (*>))
import Data.Monoid ((<>))
import Prelude ((<$>), (<*>), (++), (.), (==))

data ChildServiceCommand a where
  Foo :: ChildServiceCommand Int.Int32
  SuperParentService ::
    ParentService.ParentServiceCommand a -> ChildServiceCommand a

instance Thrift.Processor ChildServiceCommand where
  reqName = reqName'
  reqParser = reqParser'
  respWriter = respWriter'
  methodsInfo _ = methodsInfo'

reqName' :: ChildServiceCommand a -> Text.Text
reqName' Foo = "foo"
reqName' (SuperParentService x) = ParentService.reqName' x

reqParser' ::
             Thrift.Protocol p =>
             Proxy.Proxy p ->
               Text.Text -> Parser.Parser (Thrift.Some ChildServiceCommand)
reqParser' _proxy "foo"
  = ST.runSTT
      (do Prelude.return ()
          let
            _parse _lastId
              = do _fieldBegin <- Trans.lift
                                    (Thrift.parseFieldBegin _proxy _lastId _idMap)
                   case _fieldBegin of
                     Thrift.FieldBegin _type _id _bool -> do case _id of
                                                               _ -> Trans.lift
                                                                      (Thrift.parseSkip _proxy _type
                                                                         (Prelude.Just _bool))
                                                             _parse _id
                     Thrift.FieldEnd -> do Prelude.pure (Thrift.Some Foo)
            _idMap = HashMap.fromList []
          _parse 0)
reqParser' _proxy funName
  = do Thrift.Some x <- ParentService.reqParser' _proxy funName
       Prelude.return (Thrift.Some (SuperParentService x))

respWriter' ::
              Thrift.Protocol p =>
              Proxy.Proxy p ->
                Int.Int32 ->
                  ChildServiceCommand a ->
                    Prelude.Either Exception.SomeException a ->
                      (Builder.Builder,
                       Prelude.Maybe (Exception.SomeException, Thrift.Blame))
respWriter' _proxy _seqNum Foo{} _r
  = (Thrift.genMsgBegin _proxy "foo" _msgType _seqNum <> _msgBody <>
       Thrift.genMsgEnd _proxy,
     _msgException)
  where
    (_msgType, _msgBody, _msgException)
      = case _r of
          Prelude.Left _ex | Prelude.Just
                               _e@Thrift.ApplicationException{} <- Exception.fromException _ex
                             ->
                             (3, Thrift.buildStruct _proxy _e,
                              Prelude.Just (_ex, Thrift.ServerError))
                           | Prelude.otherwise ->
                             let _e
                                   = Thrift.ApplicationException (Text.pack (Prelude.show _ex))
                                       Thrift.ApplicationExceptionType_InternalError
                               in
                               (3, Thrift.buildStruct _proxy _e,
                                Prelude.Just (Exception.toException _e, Thrift.ServerError))
          Prelude.Right _result -> (2,
                                    Thrift.genStruct _proxy
                                      [Thrift.genFieldPrim _proxy "" (Thrift.getI32Type _proxy) 0 0
                                         (Thrift.genI32Prim _proxy)
                                         _result],
                                    Prelude.Nothing)
respWriter' _proxy _seqNum (SuperParentService _x) _r
  = ParentService.respWriter' _proxy _seqNum _x _r

methodsInfo' :: Map.Map Text.Text Thrift.MethodInfo
methodsInfo'
  = Map.union
      (Map.fromList
         [("foo", Thrift.MethodInfo Thrift.NormalPriority Prelude.False)])
      ParentService.methodsInfo'