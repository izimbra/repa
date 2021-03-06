
-- | Array IO
module Data.Repa.Array.Auto.IO
        ( -- * Raw Array IO
          hGetArray,   hGetArrayPre
        , hPutArray

          -- * XSV files
          -- ** Reading
        , getArrayFromXSV,      hGetArrayFromXSV

          -- ** Writing
        , putArrayAsXSV,        hPutArrayAsXSV)
where
import Data.Repa.Array.Auto.Base
import Data.Repa.Array.Generic.Convert
import System.IO
import Data.Word
import Data.Char
import qualified Data.Repa.Array.Material.Auto          as A
import qualified Data.Repa.Array.Material.Foreign       as A
import qualified Data.Repa.Array.Material.Nested        as A
import qualified Data.Repa.Array.Meta                   as A
import qualified Data.Repa.Array.Generic                as A
import qualified Foreign.Ptr                            as F
import qualified Foreign.ForeignPtr                     as F
import qualified Foreign.Marshal.Alloc                  as F
import qualified Foreign.Marshal.Utils                  as F


-- | Get data from a file, up to the given number of bytes.
hGetArray :: Handle -> Int -> IO (Array Word8)
hGetArray h len
 = do   buf :: F.Ptr Word8 <- F.mallocBytes len
        bytesRead          <- hGetBuf h buf len
        fptr               <- F.newForeignPtr F.finalizerFree buf
        return  $! convert $! A.fromForeignPtr bytesRead fptr
{-# NOINLINE hGetArray #-}


-- | Get data from a file, up to the given number of bytes, also
--   copying the given data to the front of the new buffer.
hGetArrayPre :: Handle -> Int -> Array Word8 -> IO (Array Word8)
hGetArrayPre h len arr
 | (offset, lenPre, fptrPre :: F.ForeignPtr Word8)   
        <- A.toForeignPtr $ convert arr
 = F.withForeignPtr fptrPre
 $ \ptrPre' -> do
        let ptrPre      = F.plusPtr ptrPre' offset
        ptrBuf :: F.Ptr Word8 <- F.mallocBytes (lenPre + len)
        F.copyBytes ptrBuf ptrPre lenPre
        lenRead         <- hGetBuf h (F.plusPtr ptrBuf lenPre) len
        let bytesTotal  = lenPre + lenRead
        fptrBuf         <- F.newForeignPtr F.finalizerFree ptrBuf
        return  $ convert $! A.fromForeignPtr bytesTotal fptrBuf
{-# NOINLINE hGetArrayPre #-}


-- | Write data into a file.
hPutArray :: Handle -> Array Word8 -> IO ()
hPutArray h arr
 | (offset, lenPre, fptrPre :: F.ForeignPtr Word8)     
        <- A.toForeignPtr $ convert arr
 = F.withForeignPtr fptrPre
 $ \ptr' -> do
        let ptr         = F.plusPtr ptr' offset
        hPutBuf h ptr lenPre
{-# NOINLINE hPutArray #-}


---------------------------------------------------------------------------------------------------
-- | Read a XSV file as a nested array.
--   We get an array of rows:fields:characters.
getArrayFromXSV
        :: Char                 -- ^ Field separator character, eg '|', ',' or '\t'.
        -> FilePath             -- ^ Source file handle.
        -> IO (Array (Array (Array Char)))

getArrayFromXSV !cSep !filePath
 = do   h       <- openFile filePath ReadMode
        arr     <- hGetArrayFromXSV cSep h
        hClose h
        return arr


-- | Read an XSV file as a nested array.
--   We get an array of rows:fields:characters.
hGetArrayFromXSV 
        :: Char                 -- ^ Field separator character, eg '|', ',' or '\t'.
        -> Handle               -- ^ Source file handle.
        -> IO (Array (Array (Array Char)))

hGetArrayFromXSV !cSep !hIn
 = do   
        -- Find out how much data there is remaining in the file.
        start     <- hTell hIn
        hSeek hIn SeekFromEnd 0
        end       <- hTell hIn
        let !len  =  end - start
        hSeek hIn AbsoluteSeek start

        -- Read array as Word8s.
        !arr8   <- hGetArray hIn (fromIntegral len)

        -- Rows are separated by new lines,
        -- fields are separated by the given separator character.
        let !nl = fromIntegral $ ord '\n'
        let !nc = fromIntegral $ ord cSep

        -- Split XSV file into rows and fields.
        -- Convert element data from Word8 to Char.
        -- Chars take 4 bytes each, but are standard Haskell and pretty
        -- print properly. We've done the dicing on the smaller Word8
        -- version, and now map across the elements vector in the array
        -- to do the conversion.
        let !arrChar 
                = A.mapElems 
                        (A.mapElems (A.computeS A.F . A.map (chr . fromIntegral))) 
                        (A.diceSep nc nl arr8)

        return $ convert arrChar


--------------------------------------------------------------------------------------------------
-- | Write a nested array as an XSV file.
--
--   The array contains rows:fields:characters.
putArrayAsXSV
        :: Char                         -- ^ Separator character, eg '|', ',' or '\t'
        -> FilePath                     -- ^ Source file handle.
        -> Array (Array (Array Char))   -- ^ Array of row, field, character.
        -> IO ()

putArrayAsXSV !cSep !filePath !arrChar
 = do   h       <- openFile filePath WriteMode
        hPutArrayAsXSV cSep h arrChar
        hClose h


-- | Write a nested array as an XSV file.
--
--   The array contains rows:fields:characters.
hPutArrayAsXSV
        :: Char                         -- ^ Separator character, eg '|', ',' or '\t'
        -> Handle                       -- ^ Source file handle.
        -> Array (Array (Array Char))   -- ^ Array of row, field, character.
        -> IO ()

hPutArrayAsXSV !cSep !hOut !arrChar
 = do
        -- Concat result back into Word8s
        let !arrC       = A.fromList A.U [cSep]
        let !arrNL      = A.fromList A.U ['\n']

        let !arrOut     
                = A.mapS A.A (fromIntegral . ord) 
                $ A.concat A.U 
                $ A.mapS A.B (\arrFields
                                -> A.concat A.U $ A.fromList A.B
                                        [ A.intercalate A.U arrC arrFields, arrNL])
                $ arrChar

        hPutArray hOut arrOut
{-# INLINE hPutArrayAsXSV #-}

