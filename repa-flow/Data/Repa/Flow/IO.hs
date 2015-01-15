
-- | Read and write files.
module Data.Repa.Flow.IO
        ( -- * Sourcing records
          sourceRecords
        , hSourceRecords

          -- * Sourcing lines
        , sourceLines
        , hSourceLines

          -- * Sourcing bytes
        , sourceBytes
        , hSourceBytes

          -- * Sinking bytes
        , sinkBytes
        , hSinkBytes)
where
import Data.Repa.Flow
import Data.Repa.Eval.Array                     as A
import Data.Repa.Array                          as A hiding (fromList, fromLists)
import qualified Data.Repa.Flow.Generic         as G hiding (next)
import System.IO
import Data.Word
import Data.Char


-- Source Records -------------------------------------------------------------
-- | Read complete records of data form a file, into chunks of the given length.
--   We read as many complete records as will fit into each chunk.
--
--   The records are separated by a special terminating character, which the 
--   given predicate detects. After reading a chunk of data we seek the file to 
--   just after the last complete record that was read, so we can continue to
--   read more complete records next time. 
--
--   If we cannot fit at least one complete record in the chunk then perform
--   the given failure action. Limiting the chunk length guards against the
--   case where a large input file is malformed, as we won't try to read the
--   whole file into memory.
-- 
--
--   * Data is read into foreign memory without copying it through the GHC heap.
--   * The provided file handle must support seeking, else you'll get an
--     exception.
--   * Each file is closed the first time the consumer tries to pull a
--     record from the associated stream when no more are available.
--
sourceRecords 
        :: [FilePath]           -- ^ File paths.
        -> Int                  -- ^ Size of chunk to read in bytes.
        -> (Word8 -> Bool)      -- ^ Detect the end of a record.        
        -> IO ()                -- ^ Action to perform if we can't get a
                                --   whole record.
        -> IO (Sources UN (Vector F Word8))
sourceRecords = G.fileSourcesRecords
{-# INLINE sourceRecords #-}


-- | Like `sourceRecords`, but take existing file handles.
--
--   * Files remain open once all data has been read.
--
hSourceRecords 
        :: [Handle]             --  File handles.
        -> Int                  --  Size of chunk to read in bytes.
        -> (Word8 -> Bool)      --  Detect the end of a record.        
        -> IO ()                --  Action to perform if we can't get a
                                --   whole record.
        -> IO (Sources UN (Vector F Word8))
hSourceRecords = G.hSourcesRecords
{-# INLINE hSourceRecords #-}


-- Source Lines ---------------------------------------------------------------
-- | Read complete lines of data from a text file, using the given chunk length.
--
--   * The trailing new-line characters are discarded.
--   * Data is read into foreign memory without copying it through the GHC heap.
--   * The provided file handle must support seeking, else you'll get an
--     exception.
--   * Each file is closed the first time the consumer tries to pull a line
--     from the associated stream when no more are available.
--
sourceLines 
        :: [FilePath]           -- ^ File paths.
        -> Int                  -- ^ Size of chunk to read in bytes.
        -> IO ()                -- ^ Action to perform if we can't get a
                                --   whole record.
        -> IO (Sources UN (Vector F Char))
sourceLines files nChunk fails
 =   mapChunks_i chopChunk
 =<< G.fileSourcesRecords files nChunk isNewLine fails
 where  
        isNewLine   :: Word8 -> Bool
        isNewLine x =  x == nl
        {-# INLINE isNewLine #-}
  
        chopChunk chunk
         = A.mapElems (A.computeS_ . A.map (chr . fromIntegral)) 
         $ A.trimEnds (== nl) chunk
        {-# INLINE chopChunk #-}

        nl :: Word8
        !nl = fromIntegral $ ord '\n'
{-# INLINE sourceLines #-}


-- | Like `sourceLines`, but take existing file handles.
--
--   * Files remain open once all data has been read.
--
hSourceLines
        :: [Handle]             --  File handles.
        -> Int                  --  Size of chunk to read in bytes.
        -> IO ()                --  Action to perform if we can't get a
                                --   whole record.
        -> IO (Sources UN (Vector F Char))
hSourceLines hs nChunk fails
 =   mapChunks_i chopChunk
 =<< G.hSourcesRecords hs nChunk isNewLine fails
 where
        isNewLine   :: Word8 -> Bool
        isNewLine x =  x == nl
        {-# INLINE isNewLine #-}
  
        chopChunk chunk
         = A.mapElems (A.computeS_ . A.map (chr . fromIntegral)) 
         $ A.trimEnds (== nl) chunk
        {-# INLINE chopChunk #-}

        nl :: Word8
        !nl = fromIntegral $ ord '\n'
{-# INLINE hSourceLines #-}


-- Source Bytes ---------------------------------------------------------------
-- | Read data from some files, using the given chunk length.
--
--   * Each file is closed the first time the consumer tries to pull a chunk
--     from the associated stream when no more are available.
--
sourceBytes
        :: [FilePath]  -> Int 
        -> IO (Sources F Word8)
sourceBytes = G.fileSourcesBytes
{-# INLINE sourceBytes #-}


-- | Like `sourceBytes`, but take existing file handles.
--
--   * Files remain open after all data has been read.
--
hSourceBytes 
        :: [Handle]   -> Int 
        -> IO (Sources F Word8)
hSourceBytes = G.hSourcesBytes
{-# INLINE hSourceBytes #-}


-- Sink Bytes -----------------------------------------------------------------
-- | Write data to the given files.
--
--   * Ejecting the sink closes the attached file.
--
sinkBytes :: [FilePath] -> IO (Sinks F Word8)
sinkBytes = G.fileSinksBytes
{-# INLINE sinkBytes #-}


-- | Like `sinkBytes` but take existing file handles.
--
--   * Ejecting the sink closes the attached file.
--
hSinkBytes    :: [Handle]   -> IO (Sinks F Word8)
hSinkBytes    = G.hSinksBytes
{-# INLINE hSinkBytes #-}
