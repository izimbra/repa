
module Data.Repa.Flow.Chunked
        ( module Data.Repa.Flow.States

        , Sources, Sinks
        , Flow

          -- * Evaluation
        , drainS

          -- * Conversion
        , fromList
        , fromLists
        , toList1
        , toLists1

          -- * Finalizers
        , finalize_i,   finalize_o

          -- * Flow Operators
          -- ** Mapping
          -- | If you want to work on a chunk at a time then use 
          --   `Data.Repa.Flow.Generic.map_i` and
          --   `Data.Repa.Flow.Generic.map_o` from "Data.Repa.Flow.Generic".
        , smap_i,       smap_o
        , szipWith_ii

          -- ** Splitting
        , head_i

          -- ** Grouping
        , groupsBy_i,   GroupsDict

          -- ** Folding
        , foldlS,       foldlAllS
        , folds_i,      FoldsDict

          -- ** Watching
        , watch_i,      watch_o
        , trigger_o

          -- ** Ignorance
        , ignore_o
        , abandon_o)
where
import Data.Repa.Flow.Chunked.Base
import Data.Repa.Flow.Chunked.Map
import Data.Repa.Flow.Chunked.Fold
import Data.Repa.Flow.Chunked.Folds
import Data.Repa.Flow.Chunked.Generic
import Data.Repa.Flow.Chunked.Groups
import Data.Repa.Flow.States
import qualified Data.Repa.Flow.Generic         as G
#include "repa-flow.h"


-- | Pull all available values from the sources and push them to the sinks.
drainS   :: (Next i, Monad m)
        => Sources i m r a -> Sinks i m r a -> m ()
drainS = G.drainS
{-# INLINE drainS #-}
