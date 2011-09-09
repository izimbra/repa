

-- | TODO: Use local rules to rewrite these to use special versions
--         for specific representations, eg for partitioned arrays 
--         we want to map the regions separately.
module Data.Array.Repa.Operators.Mapping
        ( map
        , zipWith
        , (+^), (-^), (*^), (/^))
where
import Data.Array.Repa.Shape
import Data.Array.Repa.Base
import Data.Array.Repa.Repr.Delayed
import Prelude hiding (map, zipWith)


-- | Apply a worker function to each element of an array, yielding a new array with the same extent.
--
--   This is specialised for arrays of up to four regions, using more breaks fusion.
--
map     :: (Shape sh, Repr r a)
        => (a -> b) -> Array r sh a -> Array D sh b
{-# INLINE map #-}
map f arr
 = case load arr of
        Delayed sh g    -> Delayed sh (f . g)


-- | Combine two arrays, element-wise, with a binary operator.
--	If the extent of the two array arguments differ,
--	then the resulting array's extent is their intersection.
--
zipWith :: (Shape sh, Repr r1 a, Repr r2 b)
        => (a -> b -> c)
        -> Array r1 sh a -> Array r2 sh b
        -> Array D sh c
{-# INLINE zipWith #-}
zipWith f arr1 arr2
 = let  {-# INLINE getElem' #-}
	getElem' ix	= f (arr1 `unsafeIndex` ix) (arr2 `unsafeIndex` ix)
   in	fromFunction
		(intersectDim (extent arr1) (extent arr2))
		getElem'


{-# INLINE (+^) #-}
(+^)	= zipWith (+)

{-# INLINE (-^) #-}
(-^)	= zipWith (-)

{-# INLINE (*^) #-}
(*^)	= zipWith (*)

{-# INLINE (/^) #-}
(/^)	= zipWith (/)