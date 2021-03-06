{-# LANGUAGE ScopedTypeVariables #-}
-- BANNERSTART
-- - Copyright 2006-2008, Galois, Inc.
-- - This software is distributed under a standard, three-clause BSD license.
-- - Please see the file LICENSE, distributed with this software, for specific
-- - terms and conditions.
-- Author: Adam Wick <awick@galois.com>
-- BANNEREND
module Common where

import Data.Word
import Foreign.Storable
import Hypervisor.Memory
import Hypervisor.XenStore
import Communication.IVC
import Communication.Rendezvous

offer  :: XenStore -> IO (OutChannel GrantRef)
accept :: XenStore -> IO (InChannel GrantRef)
(offer,accept) = peerConnection "CopyTest" 1

makePageData :: IO (VPtr a)
makePageData = do
  ptr <- allocPage
  writePageData ptr 0
  return ptr
 where writePageData :: VPtr a -> Int -> IO ()
       writePageData _ 4096 = return ()
       writePageData ptr off = do
         let (val::Word32) = fromIntegral off
         pokeByteOff ptr off val
         writePageData ptr (off + 4)

isRightPageData :: VPtr a -> IO Bool
isRightPageData page = isRightPageData' 0
 where isRightPageData' :: Int -> IO Bool
       isRightPageData' 4096 = return True
       isRightPageData' off = do
         (val::Word32) <- peekByteOff page off
         if (fromIntegral val) == off
            then isRightPageData' (off + 4)
            else return False
