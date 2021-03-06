module Check (checkSyntax) where

import Bag
import Control.Applicative
import Data.IORef
import ErrUtils
import Exception
import FastString
import GHC
import HscTypes
import Outputable hiding (showSDoc)
import Pretty
import Types
import Prelude hiding (catch)

----------------------------------------------------------------

checkSyntax :: Options -> String -> IO String
checkSyntax _ file = unlines <$> check file

----------------------------------------------------------------

check :: String -> IO [String]
check fileName = withGHC $ do
    ref <- newRef []
    initSession ["-Wall","-fno-warn-unused-do-bind"]
    setTargetFile fileName
    loadWithLogger (refLogger ref) LoadAllTargets `gcatch` handleParseError ref
    clearWarnings
    readRef ref
  where
    handleParseError ref e = do
        liftIO . writeIORef ref $ errBagToStrList . srcErrorMessages $ e
        return Succeeded
    newRef  = liftIO . newIORef
    readRef = liftIO . readIORef

----------------------------------------------------------------

refLogger :: IORef [String] -> WarnErrLogger
refLogger ref Nothing =
    (errBagToStrList <$> getWarnings) >>= liftIO . writeIORef ref
refLogger ref (Just e) =
    liftIO . writeIORef ref $ errBagToStrList . srcErrorMessages $ e

errBagToStrList :: Bag ErrMsg -> [String]
errBagToStrList = map showErrMsg . reverse . bagToList

----------------------------------------------------------------

showErrMsg :: ErrMsg -> String
showErrMsg err = file ++ ":" ++ line ++ ":" ++ col ++ ":" ++ msg ++ "\0" ++ ext
   where
     spn = head (errMsgSpans err)
     file = unpackFS (srcSpanFile spn)
     line = show (srcSpanStartLine spn)
     col  = show (srcSpanStartCol spn)
     msg = showSDoc (errMsgShortDoc err)
     ext = showSDoc (errMsgExtraInfo err)

style :: PprStyle
style = mkUserStyle neverQualify AllTheWay

showSDoc :: SDoc -> String
--showSDoc d = map toNull . Pretty.showDocWith ZigZagMode $ d style
showSDoc d = map toNull . Pretty.showDocWith PageMode $ d style
  where
    toNull '\n' = '\0'
    toNull x = x
