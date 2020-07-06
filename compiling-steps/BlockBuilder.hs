{-# Language BlockArguments #-}
{-# Language EmptyCase #-}
module BlockBuilder where

import Data.Map(Map)
import qualified Data.Map as Map
import Data.Void(Void)
import Control.Monad(liftM,ap)

import VM


newtype BlockBuilder a = BlockBuilder ((a -> R) -> R)

type R = BuildInfo -> ([Instr], (CInstr, Int, [(BA,FV)]))


data BuildInfo = BuildInfo
  { nextLocal   :: Int
  , nextArg     :: Int
  , localDefs   :: Map FV E
  , externArgs  :: [(BA,FV)]
  }

data FV = FV String Int VMT
  deriving (Eq,Ord,Show)


instance HasType FV where getType (FV _ _ t) = t

instance Functor BlockBuilder where
  fmap = liftM

instance Applicative BlockBuilder where
  pure a = BlockBuilder \k -> k a
  (<*>)  = ap

instance Monad BlockBuilder where
  BlockBuilder m >>= f =
    BlockBuilder \k -> m \a ->
                       let BlockBuilder m2 = f a
                       in m2 k

getLocal :: FV -> BlockBuilder E
getLocal x = BlockBuilder \k info ->
                case Map.lookup x (localDefs info) of
                  Just e  -> k e info
                  Nothing ->
                    let a = nextArg info
                        arg = BA a (getType x)
                        e = EBlockArg arg
                        i1 = info { nextArg = a + 1
                                  , localDefs = Map.insert x e (localDefs info)
                                  , externArgs = (arg,x) : externArgs info
                                  }
                    in k e i1

setLocal :: FV -> E -> BlockBuilder ()
setLocal x e = BlockBuilder \k i ->
  let i1 = i { localDefs = Map.insert x e (localDefs i) }
  in k () i1

stmt :: VMT -> (BV -> Instr) -> BlockBuilder E
stmt ty s = BlockBuilder \k i ->
              let v = nextLocal i
                  x = BV v ty
                  i1 = i { nextLocal = v + 1 }
                  (is, r) = k (EVar x) i1
              in (s x : is, r)

stmt_ :: Instr -> BlockBuilder ()
stmt_ i = BlockBuilder \k info ->
                            let (is, r) = k () info
                            in (i : is, r)

term :: CInstr -> BlockBuilder Void
term c = BlockBuilder \_ i -> ([], (c, nextLocal i, reverse (externArgs i)))


buildBlock ::
  Label ->
  [VMT] ->
  ([E] -> BlockBuilder Void) ->
  (Block, [FV])
buildBlock nm tys f =
  let args = [ BA n t | (n,t) <- [0..] `zip` tys ]
      BlockBuilder m = f (map EBlockArg args)
      info = BuildInfo { nextLocal = 0
                       , nextArg = length args
                       , localDefs = Map.empty
                       , externArgs = []
                       }
      (is,(c,ln,ls)) = m (\v _ -> case v of {}) info
      (extra,free) = unzip ls
  in ( Block { blockName = nm
             , blockArgs = args ++ extra
             , blockLocalNum = ln
             , blockInstrs = is
             , blockTerm = c
             }
      , free
      )

-- | Jump without an argument
jump :: BlockBuilder JumpPoint -> BlockBuilder Void
jump jpb = do jp <- jpb
              term $ Jump jp

-- | Jump-if with no argument
jumpIf ::
  E ->
  BlockBuilder JumpPoint ->
  BlockBuilder JumpPoint ->
  BlockBuilder Void
jumpIf e l1 l2 =
  do jp1 <- l1
     jp2 <- l2
     term $ JumpIf e jp1 jp2


