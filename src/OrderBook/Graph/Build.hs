{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE MultiParamTypeClasses #-}
{-# LANGUAGE ExistentialQuantification #-}
{-# LANGUAGE RankNTypes #-}
{-# LANGUAGE ScopedTypeVariables #-}
module OrderBook.Graph.Build
( module OrderBook.Graph.Types
, SellOrderGraph
, SortedOrders, first, rest, prepend, toList, replaceHead
, Tagged(..)
, build
, buildFromOrders
)
where

import           OrderBook.Graph.Internal.Prelude
import           OrderBook.Graph.Types
import           OrderBook.Graph.Types.SortedOrders
import qualified OrderBook.Graph.Types.Book                 as Book

import qualified Data.Graph.Digraph                         as DG
import           Data.List                                  (groupBy, sortOn, sortBy)
import qualified Data.List.NonEmpty                         as NE


type SellOrderGraph s g kind = DG.Digraph s g (Tagged kind SortedOrders) Currency

-- ^ build a graph where each edge is a list of sorted sell orders
build
    :: (PrimMonad m, Real numType)
    => SellOrderGraph (PrimState m) g "arb" -- ^ Empty graph
    -> [Book.OrderBook numType]            -- ^ Order books
    -> m ()
build mGraph orders = do
    forM_ (create orders) (DG.insertEdge mGraph . Tagged)

-- |
create
    :: Real numType
    => [Book.OrderBook numType]  -- ^ A bunch of order books
    -> [SortedOrders]
create =
        catMaybes . map (fmap SortedOrders . NE.nonEmpty . sortOn soPrice . doAssertions)
            . concat . map (concatListPairs . toOrders) . groupByMarket
  where
    concatListPairs :: ([[a]], [[a]]) -> [[a]]
    concatListPairs (listA, listB) = listA ++ listB
    toOrders :: Real numType
             => [Book.OrderBook numType]
             -> ([[SomeSellOrder]], [[SomeSellOrder]])
    toOrders aBookLst = foldl
        (\(accumSell, accumBuy) (sellOrders, buyOrders) ->
            (sellOrders : accumSell, buyOrders : accumBuy)
        )
        ([],[])
        (map Book.toSellBuyOrders aBookLst)
    doAssertions =
        assertSameBaseQuote . map assertPositivePrice
    assertSameBaseQuote lst =
        if all (sameBaseQuoteOrder (head lst)) lst
            then lst
            else error $ "SortedOrders with different base/quote: " ++ show lst
    sameBaseQuoteOrder o1 o2 =
        soBase o1 == soBase o2
        && soQuote o1 == soQuote o2
    assertPositivePrice order
        | soPrice order >= 0 = order
        | otherwise = error $ "negative-price order: " ++ show order
    groupByMarket :: [Book.OrderBook numType] -> [[Book.OrderBook numType]]
    groupByMarket = groupBy sameBaseQuote . sortOn Book.baseQuote
    sameBaseQuote :: Book.OrderBook numType -> Book.OrderBook numType -> Bool
    sameBaseQuote ob1 ob2 = Book.baseQuote ob1 == Book.baseQuote ob2

-- ^ Same as 'build' but take orders (instead of order books) as input.
-- Only present for backwards compatibility (slower than 'build').
buildFromOrders
    :: (PrimMonad m)
    => SellOrderGraph (PrimState m) g "arb" -- ^ Empty graph
    -> [SomeSellOrder]                      -- ^ Orders
    -> m ()
buildFromOrders mGraph orders = do
    forM_ (createFromOrders orders) (DG.insertEdge mGraph . Tagged)

-- |
createFromOrders
    :: [SomeSellOrder]  -- ^ A bunch of sell orders
    -> [SortedOrders]
createFromOrders =
    -- TODO: sort order books instead of orders
    fmap (SortedOrders . NE.fromList . sortOn soPrice) . groupByMarket
        . fmap assertPositivePrice
  where
    assertPositivePrice order
        | soPrice order >= 0 = order
        | otherwise = error $ "negative-price order: " ++ show order
    groupByMarket = groupBy sameSrcDst . sortBy orderSrcDst
    sameSrcDst oA oB =
        soBase oA == soBase oB &&
        soQuote oA == soQuote oB
    orderSrcDst oA oB =
        soBase oA `compare` soBase oB <>
        soQuote oA `compare` soQuote oB
