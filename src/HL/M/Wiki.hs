{-# LANGUAGE ViewPatterns #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE OverloadedStrings #-}

-- | Model for wiki.

module HL.M.Wiki where

import HL.C

import Control.Exception.Lifted (catch)
import Data.Conduit

import Data.Maybe
import Data.Monoid
import Data.Text (unpack)

import Network.HTTP.Conduit
import Prelude hiding (readFile,catch)
import Text.Pandoc.Definition
import Text.Pandoc.Options
import Text.Pandoc.Readers.MediaWiki

import Text.XML
import Text.XML.Cursor

-- | Get the MediaWiki markup of a wiki page and then convert it to
-- HTML.
getWikiPage :: Text -> IO (Either Text (Text,Pandoc))
getWikiPage article =
  do request <- parseUrl ("http://www.haskell.org/haskellwiki/Special:Export/" <> unpack article)
     withManager $ \manager -> do
       response <- http request manager
       doc <- catch (fmap Just (responseBody response $$+- sinkDoc def))
                    (\(_::UnresolvedEntityException) -> return Nothing)
       case doc >>= parse of
         Nothing -> return (Left "Unable to parse XML from haskell.org.")
         Just (title,pan) -> return (Right (title,pan))
  where
    parse doc =
      do let cursor = fromDocument doc
         title <- listToMaybe (getTitle cursor)
         text <- listToMaybe (getText cursor)
         return (title,readMediaWiki def (unpack text))
    name n =
      Name {nameLocalName = n
           ,nameNamespace = Just "http://www.mediawiki.org/xml/export-0.6/"
           ,namePrefix = Nothing}
    getText cursor =
      element (name "mediawiki") cursor >>=
      descendant >>=
      element (name "page") >>=
      descendant >>=
      element (name "text") >>=
      descendant >>=
      content
    getTitle cursor =
      element (name "mediawiki") cursor >>=
      descendant >>=
      element (name "page") >>=
      descendant >>=
      element (name "title") >>=
      descendant >>=
      content
