{-# LANGUAGE FlexibleContexts #-}
{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE TypeSynonymInstances #-}

module Controller.Paste
    ( recentPastesSplice
    , singlePasteSplice
    , addPasteHandler
    , possibleLanguagesSplice
    ) where
    
import qualified Data.Text    as T
import           Data.Text (Text)
import           Data.Maybe
import qualified Data.Text.Encoding as T (decodeUtf8)
import qualified Text.XmlHtml as X
import           Control.Monad.Trans
import           Control.Monad (mzero)
import qualified Data.ByteString.Char8 as BS (unpack)

import           Snap.Types
import           Text.Templating.Heist

import           Application
import           Model.Utils      
import           Model.Paste


languageParts :: (Text, Text) -> [(Text, Text)]
languageParts (n, v) = [("lang-name", n), ("lang-value", v)]

possibleLanguages :: [(Text, Text)]
possibleLanguages = [ ("C++",     "cpp")
                    , ("Haskell", "hs") ]

possibleLanguagesSplice :: Splice Application
possibleLanguagesSplice = mapSplices (runChildrenWithText . languageParts) possibleLanguages

pasteParts :: Paste -> [(Text, Text)]
pasteParts p = map applyAndPack [ ("title", pasteTitle)
                                , ("source-code", pasteCode)
                                , ("description", pasteDescription)
                                , ("language", pasteLanguage)
                                , ("paste-id", pasteLink) ]
    where applyAndPack (x, f) = (x, f p)
          pasteLink p = maybe "#" id $ pasteIDText p
          

singlePasteSplice :: Maybe ObjectId -> Splice Application
singlePasteSplice Nothing    = textSplice "There is no such paste."
singlePasteSplice (Just pid) = do
    mp <- lift $ getPaste pid
    case mp of
         Nothing -> textSplice "There is no such paste"
         Just  p -> runChildrenWithText $ pasteParts p
    

recentPastesSplice :: Splice Application
recentPastesSplice = do
    ps <- lift getRecentPastes
    mapSplices (runChildrenWithText . pasteParts) ps

addPasteHandler :: Application ()
addPasteHandler = do
    t <- getParam "title" >>= maybe (redirect "/") (return . T.decodeUtf8)
    c <- getParam "source-code" >>= maybe (redirect "/") (return . T.decodeUtf8)
    d <- getParam "description" >>= maybe (redirect "/") (return . T.decodeUtf8)
    l <- getParam "language" >>= maybe (redirect "/") (return . T.decodeUtf8)
    if (not $ any T.null [t, c, d, l]) then insertPaste $ paste t c d l else return ()
    redirect "/"

         
    