-- Copyright 2006-2008, Galois, Inc.
-- This software is distributed under a standard, three-clause BSD license.
-- Please see the file LICENSE, distributed with this software, for specific
-- terms and conditions.
-- An example showing how programs can interact with the Xenstore.
import Control.Concurrent
import Control.Exception
import Control.Monad
import Hypervisor.Console
import Hypervisor.Debug
import Hypervisor.ErrorCodes
import Hypervisor.XenStore
import System.FilePath

import Prelude hiding (getLine)

main :: IO ()
main = do
  con <- initXenConsole
  xs  <- initXenStore

  me   <- xsGetDomId xs
  here <- xsGetDomainPath xs me
  writeConsole con ("Hello! This is an interactive XenStore thing for " ++
                    show me ++ "\n")
  writeConsole con ("Valid commands: quit, ls, cd\n\n")
  writeDebugConsole "Starting interaction loop!\n"
  runPrompt con xs here

runPrompt :: Console -> XenStore -> FilePath -> IO ()
runPrompt con xs here = do
  writeConsole con (here ++ "> ")
  inquery <- getLine con
  case words inquery of
    ("quit":_) -> return ()
    ("ls"  :_) -> do
      contents <- filter (/= "") `fmap` xsDirectory xs here
      values   <- mapM (getValue xs) (map (here </>) contents)
      let contents' = map (forceSize 25) contents
          values'   = map (forceSize 40) values
      forM_ (zip contents' values') $ \ (key, value) ->
        writeConsole con (key ++ " ==> " ++ value ++ "\n")
      runPrompt con xs here
    ("cd"  :x:_) -> do
      case x of
        ".." -> runPrompt con xs (takeDirectory here)
        d    -> runPrompt con xs (here </> d)
    _ -> do writeConsole con "Unrecognized command.\n"
            runPrompt con xs here

getValue :: XenStore -> String -> IO String
getValue xs key = handle handleException (emptify `fmap` xsRead xs key)
  where
   handleException :: ErrorCode -> IO String
   handleException _ = return "<read error>"
   emptify "" = "<empty>"
   emptify s  = s

forceSize :: Int -> String -> String
forceSize n str
  | length str > n = "..." ++ drop (length str - (n - 3)) str
  | length str < n = str ++ (replicate (n - length str) ' ')
  | otherwise      = str

getLine :: Console -> IO String
getLine con = do
  nextC <- readConsole con 1
  writeConsole con nextC
  case nextC of
    "\r" -> writeConsole con "\n" >> return ""
    [x]  -> (x:) `fmap` getLine con
    _    -> fail "More than one character back?"
