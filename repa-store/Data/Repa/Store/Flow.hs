
module Data.Repa.Store.Flow
        (sourceTableFormat)
where
import Data.Repa.Store.Object.Table             as Table
import Data.Repa.Store.Format                   as Format
import Data.Repa.Flow.Generic.IO                as G
import Data.Repa.Flow.Generic                   as F
import Data.Repa.Array.Generic                  as A
import Data.Repa.Array.Material                 as A
import Data.Repa.Convert.Format                 as C
import Data.Word
#include "repa-store.h"


-- | Read a the lines of a text file,
--   converting each line to values with the given format.
sourceTableFormat
        :: forall format
        .  (Packable (Sep format), Target A (Value format))
        => Integer                      -- ^ Chunk length.
        -> IO ()                        -- ^ Action if we find a line longer than the chunk length.
        -> IO (Array A Word8 -> IO ())  -- ^ Action if we can't convert a row.
        -> FilePath                     -- ^ Path to table directory.
        -> Delim                        -- ^ Row delimitor.
        -> format                       -- ^ Row format.
        -> IO (Sources Int IO (Array A (Value format)))

sourceTableFormat
        nChunk 
        aFailLong aFailConvert 
        pathTable  
        delim format

 | LinesSep c   <- delim
 = do  
        putStrLn pathTable
        Just parts   <- Table.listPartitions pathTable 

        ss      <- fromFiles parts 
                $  sourceLinesFormat nChunk 
                        aFailLong aFailConvert 
                        (C.Sep c format)

        return ss

 | otherwise
 = error "sourceTable: TODO finish me"
{-# INLINE_FLOW sourceTableFormat #-}
