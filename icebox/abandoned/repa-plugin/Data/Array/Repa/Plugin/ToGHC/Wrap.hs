
module Data.Array.Repa.Plugin.ToGHC.Wrap
        ( wrapLowered
        , repackExp )
where
import Data.Array.Repa.Plugin.ToGHC.Var
import Data.Array.Repa.Plugin.Primitives
import Data.Array.Repa.Plugin.GHC.Pretty ()

import qualified BasicTypes             as G
import qualified CoreSyn                as G
import qualified DataCon                as G
import qualified Type                   as G
import qualified TypeRep                as G
import qualified TysPrim                as G
import qualified TysWiredIn             as G
import qualified UniqSupply             as G


-- | Make a wrapper to call a lowered version of a function from the original
--   binding. We need to unsafely pass it the world token, as well as marshall
--   between boxed and unboxed types.
wrapLowered 
        :: Primitives                   -- ^ Primitive table.
        -> G.Type                       -- ^ Type of original version.
        -> G.Type                       -- ^ Type of lowered  version.
        -> [Either G.Var G.CoreExpr]    -- ^ Lambda bound variables in wrapper.
        -> G.Var                        -- ^ Name of lowered version.
        -> G.UniqSM G.CoreExpr

wrapLowered prims tOrig tLowered vsParam vLowered
        -- Decend into foralls.
        --  Bind the type argument with a new var so we can pass it to 
        --  the lowered function.
        | G.ForAllTy vOrig tOrig'       <- tOrig
        , G.ForAllTy _     tLowered'    <- tLowered
        = do    let vsParam'    = Left vOrig : vsParam
                xBody   <- wrapLowered prims tOrig' tLowered' vsParam' vLowered
                return  $  G.Lam vOrig xBody

        -- When we get to the (World -> World) functional result then wrap it
        --   back up as a series process. We're done.
        | G.FunTy    tLowered1  _       <- tLowered
        , G.TyConApp tcState _          <- tLowered1
        , tcState == G.statePrimTyCon
        = do    
                -- Arguments to pass to the lowered function.
                let xsArg       = map   (either (G.Type . G.TyVarTy) id) 
                                        vsParam

                -- Actual call to the lowered function.
                let xLowered    = foldl G.App (G.Var vLowered) $ reverse xsArg

                return $ G.App (fst $ prim_makeProcess prims) xLowered 

        -- Decend into functions.
        --  Bind the argument with a new var so we can pass it to the lowered
        --  function.
        | G.FunTy tOrig1      tOrig2    <- tOrig
        , G.FunTy tLowered1  tLowered2 <- tLowered
        = do    v'              <- newDummyVar "arg" tOrig1
                -- Convert from type 'tOrig1' to 'tLowered1'
                arg'            <- repackExp prims tLowered1 tOrig1 (G.Var v')
                let vsParam'    = Right arg' : vsParam
                xBody           <- wrapLowered prims tOrig2 tLowered2 vsParam' vLowered
                return  $  G.Lam v' xBody

        -- We've decended though all the foralls and lambdas and now need
        -- to call the actual lowered function, and marshall its result.
        | otherwise
        = error "wrapLowered: didn't find the IO action"


-- Repack ---------------------------------------------------------------------
-- | Convert representation of an expression between types.
--   The source code is written in terms of GHC boxed values but the lowered
--   code works on primitives. 
repackExp 
        :: Primitives
        -> G.Type               -- ^ Type of result for original unlowered version.
        -> G.Type               -- ^ Type of result for lowered version.
        -> G.CoreExpr           -- ^ Expression for result value.
        -> G.UniqSM G.CoreExpr

repackExp prims tOrig tResult xOrig

        -- Unboxed -> Boxed ---------------------
        -- Wrap Ints
        | G.TyConApp tcInt  []    <- tOrig,     tcInt  == G.intTyCon
        , G.TyConApp tcIntU []    <- tResult,   tcIntU == G.intPrimTyCon
        = return $ G.App (G.Var (G.dataConWorkId G.intDataCon)) xOrig

        -- Wrap Words
        | G.TyConApp tcWord  []   <- tOrig,     tcWord  == G.wordTyCon
        , G.TyConApp tcWordU []   <- tResult,   tcWordU == G.wordPrimTyCon
        = return $ G.App (G.Var (G.dataConWorkId G.wordDataCon)) xOrig

        -- Wrap Floats
        | G.TyConApp tcFloat  []  <- tOrig,     tcFloat  == G.floatTyCon
        , G.TyConApp tcFloatU []  <- tResult,   tcFloatU == G.floatPrimTyCon
        = return $ G.App (G.Var (G.dataConWorkId G.floatDataCon)) xOrig

        -- Wrap Doubles
        | G.TyConApp tcDouble  [] <- tOrig,     tcDouble  == G.doubleTyCon
        , G.TyConApp tcDoubleU [] <- tResult,   tcDoubleU == G.doublePrimTyCon
        = return $ G.App (G.Var (G.dataConWorkId G.doubleDataCon)) xOrig


        -- Boxed -> Unboxed ---------------------
        -- Unwrap Ints
        | G.TyConApp tcIntU []   <- tOrig,      tcIntU == G.intPrimTyCon
        , G.TyConApp tcInt  []   <- tResult,    tcInt  == G.intTyCon
        = do    vScrut  <- newDummyVar "scrut" tResult
                v       <- newDummyVar "v"     tOrig
                return  $ G.Case xOrig vScrut tOrig
                        [ (G.DataAlt G.intDataCon, [v], G.Var v)]

        -- Unwrap Words
        | G.TyConApp tcWordU []   <- tOrig,     tcWordU == G.wordPrimTyCon
        , G.TyConApp tcWord  []   <- tResult,   tcWord  == G.wordTyCon
        = do    vScrut  <- newDummyVar "scrut" tResult
                v       <- newDummyVar "v"     tOrig
                return  $ G.Case xOrig vScrut tOrig
                        [ (G.DataAlt G.wordDataCon, [v], G.Var v)]

        -- Unwrap Floats
        | G.TyConApp tcFloatU []  <- tOrig,      tcFloatU == G.floatPrimTyCon
        , G.TyConApp tcFloat  []  <- tResult,    tcFloat  == G.floatTyCon
        = do    vScrut  <- newDummyVar "scrut" tResult
                v       <- newDummyVar "v"     tOrig
                return  $ G.Case xOrig vScrut tOrig
                        [ (G.DataAlt G.floatDataCon, [v], G.Var v)]

        -- Unwrap Doubles
        | G.TyConApp tcDoubleU []  <- tOrig,      tcDoubleU == G.doublePrimTyCon
        , G.TyConApp tcDouble  []  <- tResult,    tcDouble  == G.doubleTyCon
        = do    vScrut  <- newDummyVar "scrut" tResult
                v       <- newDummyVar "v"     tOrig
                return  $ G.Case xOrig vScrut tOrig
                        [ (G.DataAlt G.doubleDataCon, [v], G.Var v)]


        -- Boxed Tuples -> Unboxed Tuples -------
        | G.TyConApp tcTup tins          <- tOrig
        , G.TyConApp tcUnb touts         <- tResult
        , n                              <- length tins
        , G.tupleTyCon G.BoxedTuple   n  == tcTup
        , G.tupleTyCon G.UnboxedTuple n  == tcUnb
        = do
            -- Case on the unboxed tuple, raise the elements, then create a boxed tuple
            vScrut <- newDummyVar "scrut" tResult
            vs     <- mapM (newDummyVar "v") touts

            let unwrap (t,t',v)
                    = repackExp prims t t' (G.Var v)

            xs     <- mapM unwrap (zip3 tins touts vs)
            return (G.Case xOrig vScrut tOrig
                    [ ( G.DataAlt  (G.tupleCon G.UnboxedTuple n), vs
                      , G.mkConApp (G.tupleCon G.BoxedTuple n)
                                   (map G.Type tins ++ xs))])


        -- Unboxed Tuples -> Boxed Tuples -------
        | G.TyConApp tcUnb tins         <- tOrig
        , G.TyConApp tcTup touts        <- tResult
        , n                             <- length tins
        , G.tupleTyCon G.UnboxedTuple n == tcUnb
        , G.tupleTyCon G.BoxedTuple   n == tcTup
        = do
            -- Case on the unboxed tuple, raise the elements, then create a boxed tuple
            vScrut <- newDummyVar "scrut" tResult
            vs     <- mapM (newDummyVar "v") touts

            let unwrap (t,t',v)
                    = repackExp prims t t' (G.Var v)

            xs     <- mapM unwrap (zip3 tins touts vs)
            return (G.Case xOrig vScrut tOrig
                    [ ( G.DataAlt  (G.tupleCon G.BoxedTuple n), vs
                      , G.mkConApp (G.tupleCon G.UnboxedTuple n)
                                   (map G.Type tins ++ xs))])

        -- Expression doesn't need any repacking.
        | G.eqType tOrig tResult
        = return xOrig


        -- Expression needs repacking but we don't know how to do it.
        | otherwise
        = return xOrig

        -- = error $ unlines
        --        [ "repa-plugin.repackExp: type mismatch"
        --        , "  Argument or return type of lowered function does not have the"
        --        , "  same type as the original and we don't know how to coerce it."
        --        , "  original = " ++ (renderIndent $ ppr tOrig) 
        --        , "  result   = " ++ (renderIndent $ ppr tResult) ]

