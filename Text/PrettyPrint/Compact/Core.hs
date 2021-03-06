{-# LANGUAGE ScopedTypeVariables, TypeSynonymInstances, FlexibleContexts, FlexibleInstances, GeneralizedNewtypeDeriving, ViewPatterns #-}
module Text.PrettyPrint.Compact.Core(Layout(..),Document(..),Doc) where

import Data.List (sort,groupBy,intercalate,minimumBy)
import Data.Function (on)
import Data.Monoid
import Data.Sequence (singleton, Seq, viewl, viewr, ViewL(..), ViewR(..), (|>))
import Data.String
import Data.Foldable (toList)

newtype L = L (Seq String) -- non-empty sequence
  deriving (Eq,Ord,Show)

instance Monoid L where
   mempty = L (singleton "")
   L (viewr -> xs :> x) `mappend` L (viewl -> y :< ys) = L (xs <> singleton (x ++ y) <> fmap (indent ++) ys)
      where n = length x
            indent = Prelude.replicate n ' '

instance Layout L where
   render (L xs) = intercalate "\n" $ toList xs
   text = L . singleton
   flush (L xs) = L (xs |> "")


class Monoid d => Layout d where
  text :: String -> d
  flush :: d -> d
  render :: d -> String

class Layout d => Document d where
  (<|>) :: d -> d -> d

data M = M {height    :: Int,
            lastWidth :: Int,
            maxWidth  :: Int
            }
  deriving (Show,Eq,Ord)

instance Monoid M where
  mempty = text ""
  a `mappend` b =
    M {maxWidth = max (maxWidth a) (maxWidth b + lastWidth a),
       height = height a + height b,
       lastWidth = lastWidth a + lastWidth b}

instance Layout M where
  text s = M {height = 0, maxWidth = length s, lastWidth = length s}
  flush a = M {maxWidth = maxWidth a,
               height = height a + 1,
               lastWidth = 0}
  render = error "don't use render for M type"

class Poset a where
  (≺) :: a -> a -> Bool


instance Poset M where
  M c1 l1 s1 ≺ M c2 l2 s2 = c1 <= c2 && l1 <= l2 && s1 <= s2

merge :: Ord a => [a] -> [a] -> [a]
merge [] xs = xs
merge xs [] = xs
merge (x:xs) (y:ys)
  | x <= y = x:merge xs (y:ys)
  | otherwise = y:merge (x:xs) ys


mergeAll :: Ord a => [[a]] -> [a]
mergeAll [] = []
mergeAll (x:xs) = merge x (mergeAll xs)

bests :: forall a. (Ord a, Poset a) => [[a]] -> [a]
bests = pareto' [] . mergeAll

pareto' :: Poset a => [a] -> [a] -> [a]
pareto' acc [] = Prelude.reverse acc
pareto' acc (x:xs) = if any (≺ x) acc
                       then pareto' acc xs
                       else pareto' (x:acc) xs
                            -- because of the ordering, we have that
                            -- for all y ∈ acc, y <= x, and thus x ≺ y
                            -- is false. No need to refilter acc.


newtype Doc = MkDoc [(M,L)] -- list sorted by lexicographic order for the first component
  deriving Show

instance Monoid Doc where
  mempty = text ""
  MkDoc xs `mappend` MkDoc ys = MkDoc $ bests [ quasifilter (fits . fst) [x <> y | y <- ys] | x <- xs]
    where quasifilter p xs = let fxs = filter p xs
                             in if null fxs
                                then [minimumBy (compare `on` (maxWidth . fst)) xs]
                                else fxs

fits :: M -> Bool
fits x = maxWidth x <= 80

instance Layout Doc where
  flush (MkDoc xs) = MkDoc $ bests $ map sort $ groupBy ((==) `on` (height . fst)) $ (map flush xs)
  -- flush xs = pareto' [] $ sort $ (map flush xs)
  text s = MkDoc [text s]
  render (MkDoc []) = error "No suitable layout found."
  render (MkDoc xs@(x:_)) | maxWidth (fst x) <= 80 = render x
                          | otherwise = render (minimumBy (compare `on` (maxWidth . fst)) xs)

instance Document Doc where
  MkDoc m1 <|> MkDoc m2 = MkDoc (bests [m1,m2])


instance (Layout a, Layout b) => Layout (a,b) where
  text s = (text s, text s)
  flush (a,b) = (flush a, flush b)
  render = render . snd

instance (Document a, Document b) => Document (a,b) where
  (a,b) <|> (c,d) = (a<|>c,b<|>d)

instance (Poset a) => Poset (a,b) where
  (a,_) ≺ (b,_) = a ≺ b

instance IsString Doc where
  fromString = text
