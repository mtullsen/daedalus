{-# LANGUAGE ScopedTypeVariables  #-}

module Daedalus.ParserGen.ClassInterval where

--import Data.Char
--import GHC.Enum

import Data.Word

data IntervalEndpoint =
    PlusInfinity
  | MinusInfinity
  | CValue Word8
  deriving(Eq)

instance Ord IntervalEndpoint where
  (<=) MinusInfinity _ = True
  (<=) (CValue _) MinusInfinity = False
  (<=) (CValue x) (CValue y) = x <= y
  (<=) (CValue _) PlusInfinity = True
  (<=) PlusInfinity PlusInfinity = True
  (<=) PlusInfinity _ = False

instance Show IntervalEndpoint where
  show PlusInfinity = "+inf"
  show MinusInfinity = "-inf"
  show (CValue i) = show (toEnum (fromIntegral i) :: Char)

incrItv :: IntervalEndpoint -> IntervalEndpoint
incrItv i =
  case i of
    PlusInfinity -> error "cannot increment plus infinity"
    MinusInfinity -> error "cannot increment minis infinity"
    CValue n -> CValue (n+1)

decrItv :: IntervalEndpoint -> IntervalEndpoint
decrItv i =
  case i of
    PlusInfinity -> error "cannot decrement plus infinity"
    MinusInfinity -> error "cannot decrement minis infinity"
    CValue n -> CValue (n-1)


data ClassInterval =
    ClassBtw IntervalEndpoint IntervalEndpoint

instance Show ClassInterval where
  show (ClassBtw i j) = if i == j then "[" ++ show i ++ "]" else "[" ++ show i ++ "," ++ show j ++ "]"


data Who = A1 | A2 | A12
  deriving(Eq)

combineInterval :: ClassInterval -> ClassInterval -> [(ClassInterval, Who)]
combineInterval itv1 itv2 =
  case (itv1, itv2) of
    (ClassBtw i1 j1, ClassBtw i2 j2) ->
      case (compare i2 i1, compare i2 j1) of
        (LT, LT) -> -- i2 < i1 <= j1
          case (compare j2 i1, compare j2 j1) of
            (LT, LT) -> [(itv2, A2), (itv1, A1)]
            (LT, _ ) -> error "impossible"
            (EQ, LT) -> [ (ClassBtw i2 (decrItv j2), A2), (ClassBtw j2 j2, A12), (ClassBtw (incrItv j2) j1, A1) ]
            (EQ, EQ) -> [ (ClassBtw i2 (decrItv j2), A2), (ClassBtw j2 j2, A12)]
            (EQ, GT) -> error "impossible"
            (GT, LT) -> [ (ClassBtw i2 (decrItv i1), A2), (ClassBtw i1 j2, A12), (ClassBtw (incrItv j2) j1, A1) ]
            (GT, EQ) -> [ (ClassBtw i2 (decrItv i1), A2), (ClassBtw i1 j2, A12)]
            (GT, GT) -> [ (ClassBtw i2 (decrItv i1), A2), (ClassBtw i1 j1, A12), (ClassBtw (incrItv j1) j2, A2) ]
        (LT, EQ) -> error "impossible"
        (LT, GT) -> error "impossible"
        (EQ, EQ) -> -- i1 == j1 == i2
          case (compare j2 i1, compare j2 j1) of
            (LT, _) -> error "impossible"
            (EQ, EQ) -> -- i2 == j2 == *
              [(ClassBtw i1 i1, A12)]
            (EQ, _ ) -> error "impossible"
            (GT, LT) -> error "impossible"
            (GT, EQ) -> error "impossible"
            (GT, GT) -> [(ClassBtw i1 i1, A12), (ClassBtw (incrItv i1) j2, A2)]
        (EQ, LT) -> -- i1 == i2 and i1 < j1
          case (compare j2 i1, compare j2 j1) of
            (LT, _) -> error "impossible"
            (EQ, LT) -> [(ClassBtw i1 i1, A12), (ClassBtw (incrItv i1) j1, A1)]
            (EQ, _) -> error "impossible"
            (GT, LT) -> [(ClassBtw i1 j2, A12), (ClassBtw (incrItv j2) j1, A1)]
            (GT, EQ) -> [(ClassBtw i1 j1, A12)]
            (GT, GT) -> [(ClassBtw i1 j1, A12), (ClassBtw (incrItv j1) j2, A2)]
        (EQ, GT) -> error "impossible"
        (GT, LT) -> -- i1 < i2 < j1
          case (compare j2 i1, compare j2 j1) of
            (LT, _ ) -> error "impossible"
            (EQ, _ ) -> error "impossible"
            (GT, LT) -> [(ClassBtw i1 (decrItv i2), A1), (ClassBtw i2 j2, A12), (ClassBtw (incrItv j2) j1, A1)]
            (GT, EQ) -> [(ClassBtw i1 (decrItv i2), A1), (ClassBtw i2 j2, A12)]
            (GT, GT) -> [(ClassBtw i1 (decrItv i2), A1), (ClassBtw i2 j1, A12), (ClassBtw (incrItv j1) j2, A2)]
        (GT, EQ) -> -- i1 < i2 == j1
          case (compare j2 i1, compare j2 j1) of
            (LT, _ ) -> error "impossible"
            (EQ, _ ) -> error "impossible"
            (GT, LT) -> error "impossible"
            (GT, EQ) -> [(ClassBtw i1 (decrItv i2), A1), (ClassBtw i2 i2, A12)]
            (GT, GT) -> [(ClassBtw i1 (decrItv i2), A1), (ClassBtw i2 i2, A12), (ClassBtw (incrItv i2) j2, A2)]
        (GT, GT) -> -- i1 <= j1 < i2
          case (compare j2 i1, compare j2 j1) of
            (LT, _ ) -> error "impossible"
            (EQ, _ ) -> error "impossible"
            (GT, LT) -> error "impossible"
            (GT, EQ) -> error "impossible"
            (GT, GT) -> [(itv1, A1), (itv2, A2)]


insertItvInOrderedList :: forall a. (ClassInterval, a) -> [(ClassInterval, a)] -> (a -> a -> a) -> [(ClassInterval,a)]
insertItvInOrderedList (itv, a) lstItv merge =
  step [] (itv,a) lstItv
  where
    step :: [(ClassInterval, a)] -> (ClassInterval, a) -> [(ClassInterval, a)] -> [(ClassInterval, a)]
    step acc (itv1, a1) lst =
      case lst of
        [] -> reverse acc ++ [(itv1, a1)]
        (itv2, a2) : rest ->
          let comb = combineInterval itv1 itv2 in
            insertComb a1 a2 acc (reverse comb) rest

    insertComb :: a -> a -> [(ClassInterval, a)] -> [(ClassInterval, Who)] -> [(ClassInterval, a)] -> [(ClassInterval, a)]
    insertComb a1 a2 acc revComb rest =
      case revComb of
        [] -> error "nothing"
        (itv3, w) : xs ->
          case w of
            A1 ->
              let newAcc = applyAdd a1 a2 xs ++ acc
              in step newAcc (itv3, a1) rest
            _ -> reverse acc ++ reverse (applyAdd a1 a2 revComb) ++ rest


    applyAdd :: a -> a -> [(ClassInterval, Who)] -> [(ClassInterval, a)]
    applyAdd a1 a2 lst = map (expandAdd a1 a2) lst

    expandAdd :: a -> a -> (ClassInterval, Who) -> (ClassInterval, a)
    expandAdd a1 a2 (i,w) =
      case w of
        A1 -> (i, a1)
        A2 -> (i, a2)
        A12 -> (i, merge a1 a2)
