{-# LANGUAGE RecordWildCards #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE DataKinds #-}
{-# LANGUAGE FlexibleContexts #-}
module Common.Util
( assertMatchedOrders )
where

import           OrderBook.Graph.Internal.Prelude
import qualified OrderBook.Graph                            as Lib
import qualified Data.Graph.Immutable                       as GI
import           Test.Hspec.Expectations.Pretty
import qualified System.Random.Shuffle                      as Shuffle


-- |
assertMatchedOrders
    :: ( KnownSymbol base
       , KnownSymbol quote
       )
    => [Lib.SomeSellOrder]          -- ^ Input sell orders
    -> Lib.BuyOrder base quote      -- ^ Buy order
    -> [Lib.SomeSellOrder]          -- ^ Expected matched orders
    -> IO ()
assertMatchedOrders sellOrders buyOrder expected = void $ do
    shuffledSellOrders <- Shuffle.shuffleM sellOrders
    GI.create $ \mGraph -> do
        Lib.build mGraph shuffledSellOrders
        matchedOrders <- Lib.match mGraph buyOrder
        matchedOrders `shouldBe` expected
