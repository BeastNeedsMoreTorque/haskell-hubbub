module Network.Hubbub.SubscriptionDb.SqLite.Test
  ( subscriptionDbSqLiteSuite ) where

import Network.Hubbub.TestHelpers
  ( assertRightEitherT
  , callback
  , topic
  , subscription )
import Network.Hubbub.SubscriptionDb.SqLite
  ( withConnection
  , add
  , expireSubscriptions
  , getAllSubscriptions
  , getTopicSubscriptions )
import Control.Monad (return)
import Data.DateTime (addSeconds)
import Data.Function (($),const)
import Database.SQLite.Simple (Connection)
import System.IO (IO)
import Data.Time (getCurrentTime)
import Test.Tasty (TestTree,testGroup)
import Test.Tasty.HUnit (Assertion,testCase,(@?=))

--------------------------------------------------------------------------------
-- Define a Test.Tasty.TestTree for our tests ----------------------------------
--------------------------------------------------------------------------------

subscriptionDbSqLiteSuite :: TestTree
subscriptionDbSqLiteSuite = testGroup "SqLite"
  [ testCase "openDb"   testOpenDb
  , testCase "add"      testAdd
  , testCase "getAll"   testGetAll
  , testCase "getTopic" testGetTopic
  , testCase "expire"   testExpire    
  ]

--------------------------------------------------------------------------------
-- Below is all HUnit ----------------------------------------------------------
--------------------------------------------------------------------------------

-- Make sure opening the DB and applying the schema doesn't error.
testOpenDb :: Assertion
testOpenDb = withTempDbConn (const $ return ())

-- Make sure that adding a subscription doesn't throw an error.
testAdd :: Assertion
testAdd = withTempDbConn $ \ conn -> do
  tm <- getCurrentTime
  assertRightEitherT $ add conn (topic "a") (callback "1") $ subscription tm "u"

-- Make sure that getting all subscriptions returns what we added.
testGetAll :: Assertion
testGetAll = withTempDbConn $ \ conn -> do
  tm <- getCurrentTime
  assertRightEitherT $ add conn (topic "a") (callback "1") $ subscription tm "u"
  assertRightEitherT $ add conn (topic "a") (callback "2") $ subscription tm "v"
  subs <- assertRightEitherT $ getAllSubscriptions conn
  subs @?= [
    (topic "a",callback "1",subscription tm "u")
    , (topic "a",callback "2",subscription tm "v") ]

-- Ensure that getting topic subscriptions returns what was added to that topic.
testGetTopic :: Assertion
testGetTopic = withTempDbConn $ \ conn -> do
  tm <- getCurrentTime
  assertRightEitherT $ add conn (topic "a") (callback "1") $ subscription tm "u"
  assertRightEitherT $ add conn (topic "a") (callback "2") $ subscription tm "v"
  assertRightEitherT $ add conn (topic "b") (callback "3") $ subscription tm "x"
  subs <- assertRightEitherT $ getTopicSubscriptions conn (topic "a")
  subs @?= [
    (callback "1",subscription tm "u")
    , (callback "2",subscription tm "v") ]

-- Ensure that running expireSubscriptions kills subscription expired before
-- that time.
testExpire :: Assertion
testExpire = withTempDbConn $ \ con -> do
  tm    <- getCurrentTime
  let tm' = addSeconds (-3000) tm
  assertRightEitherT $ add con (topic "a") (callback "1") $ subscription tm  "u"
  assertRightEitherT $ add con (topic "a") (callback "2") $ subscription tm' "v"
  assertRightEitherT $ expireSubscriptions con tm
  subs <- assertRightEitherT $ getAllSubscriptions con
  subs @?= [(topic "a",callback "1",subscription tm "u")]

--------------------------------------------------------------------------------

withTempDbConn :: (Connection -> IO a) -> IO a
withTempDbConn = withConnection ":memory:" 
