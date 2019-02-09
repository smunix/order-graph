{-# LANGUAGE FlexibleInstances #-}
{-# LANGUAGE UndecidableInstances #-}
module OrderBook.Graph.Internal.Prelude
( module Conv
, module TypeLits
, module Proxy
, module Maybe
, module Prim
, module Monad
, module MoreStuff
, justOrFail
, pp
, pprint
)

where

import Protolude.Conv                       as Conv
import GHC.TypeLits                         as TypeLits
import Data.Proxy                           as Proxy
import Data.Maybe                           as Maybe
import Control.Monad.Primitive              as Prim         (PrimMonad, PrimState)
import Control.Monad                        as Monad        (forM_, when)
import Data.List.NonEmpty                   as MoreStuff    (NonEmpty(..), cons)
import Data.String                          as MoreStuff    (fromString)
import GHC.Generics                         as MoreStuff    (Generic)
import Control.DeepSeq                      as MoreStuff    (NFData)
import Control.Monad.Fix                    as MoreStuff    (mfix)
import Text.Show.Pretty                     as MoreStuff    (PrettyVal(..), valToStr)

pp :: PrettyVal a => a -> String
pp = valToStr . prettyVal

pprint :: PrettyVal a => a -> IO ()
pprint = putStrLn . valToStr . prettyVal

justOrFail :: PrettyVal a => ([Char], a) -> Maybe b -> b
justOrFail (textMsg, a) =
    fromMaybe . error $ unlines
        [ textMsg ++ ":"
        , pp a
        ]

instance PrettyVal a => PrettyVal (NonEmpty a) where
    prettyVal (first :| lst) = prettyVal (first : lst)
