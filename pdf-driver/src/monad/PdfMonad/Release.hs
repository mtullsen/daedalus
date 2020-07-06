{-# Language GeneralizedNewtypeDeriving, ConstraintKinds, KindSignatures #-}
{-# Language RankNTypes #-}
module PdfMonad.Release (Parser, runParser, DbgMode, pdfMain) where

import Data.ByteString(ByteString)
import Data.Foldable(toList)
import Data.Kind(Constraint)

import PdfMonad.Transformer as T
import qualified RTS.Parser as RTS


type DbgMode = () :: Constraint

newtype Parser a = P (PdfT RTS.Parser a)
  deriving (Functor, Applicative, Monad, BasicParser, PdfParser)

runParser ::
  DbgMode =>
  ByteString ->
  ObjIndex ->
  Parser a -> Input -> IO (PdfResult a)
runParser allBs objMap (P m) i =
  pure $! case res of
            NoResults err -> ParseErr err
            Results ans ->
              case toList ans of
                [a] -> ParseOk a
                xs  -> ParseAmbig xs
  where
  res = RTS.runParser (runPdfT allBs objMap m) i

pdfMain :: (DbgMode => IO ()) -> IO ()
pdfMain io = io
