
module Data.Array.Repa.Plugin.Convert.ToGHC.Prim
        ( convertPolyPrim
        , getPrim_add
        , getPrim_mul
        , getPrim_next
        , getPrim_writeByteArrayOpM
        , getPrim_readByteArrayOpM)
where
import Data.Array.Repa.Plugin.Convert.FatName
import Data.Array.Repa.Plugin.Convert.ToGHC.Type
import Data.Array.Repa.Plugin.Convert.ToGHC.Var
import Data.Array.Repa.Plugin.Convert.ToGHC.Env
import Control.Monad
import Data.Map                         (Map)

import qualified HscTypes                as G
import qualified CoreSyn                 as G
import qualified Type                    as G
import qualified Var                     as G
import qualified PrimOp                  as G
import qualified UniqSupply              as G

import qualified DDC.Core.Exp            as D
import qualified DDC.Core.Flow           as D
import qualified DDC.Core.Flow.Prim      as D
import qualified DDC.Core.Flow.Compounds as D

import qualified Data.Map                as Map


convertPolyPrim 
        :: Env
        -> D.Name -> D.Type D.Name 
        -> G.UniqSM (G.CoreExpr, G.Type)

convertPolyPrim env n tArg
 = case n of
        D.NamePrimArith D.PrimArithAdd
         -> do  Just gv <- getPrim_add (envGuts env) tArg
                return  (G.Var gv, G.varType gv)

        D.NamePrimArith D.PrimArithMul
         -> do  Just gv <- getPrim_mul (envGuts env) tArg
                return  (G.Var gv, G.varType gv)

        D.NameOpStore D.OpStoreNext 
         | Just  gv     <- getPrim_next (envGuts env) tArg
         ->     return  (G.Var gv, G.varType gv)

        D.NameOpStore D.OpStoreReadArray
         -> do  Just gv <- getPrim_readByteArrayOpM (envGuts env) tArg
                return  (G.Var gv, G.varType gv)

        D.NameOpFlow D.OpFlowLengthOfRate
         |  D.TVar (D.UName (D.NameVar str)) <- tArg
         , Just gv      <- findImportedPrimVar (envGuts env) "primLengthOfRate"
         , Just vk      <- lookup (D.NameVar $ str ++ "_val") (envVarsX env) 
                        -- HACKS!. Store a proper mapping between rate vars
                        --         and their singleton types.
         -> return ( G.App (G.Var gv) (G.Var vk)
                   , convertType (envNames env) D.tInt)

        _
         -> error $ "repa-plugin.toGHC.convertPolyPrim: no match for " ++ show n

getPrim_add _ t
 | t == D.tInt  = liftM Just $ getPrimOpVar G.IntAddOp
 | otherwise    = return Nothing

getPrim_mul _ t
 | t == D.tInt  = liftM Just $ getPrimOpVar G.IntMulOp
 | otherwise    = return Nothing

getPrim_next guts t
 | t == D.tInt  = findImportedPrimVar guts "primNext_Int"
 | otherwise    = Nothing

getPrim_writeByteArrayOpM _ t
 | t == D.tInt  = liftM Just $ getPrimOpVar G.WriteByteArrayOp_Int
 | otherwise    = return Nothing

getPrim_readByteArrayOpM _ t
 | t == D.tInt  = liftM Just $ getPrimOpVar G.ReadByteArrayOp_Int
 | otherwise    = return Nothing

