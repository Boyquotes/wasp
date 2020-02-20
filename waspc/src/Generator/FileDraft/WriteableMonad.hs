module Generator.FileDraft.WriteableMonad
       ( WriteableMonad(..)
       ) where


import qualified System.Directory
import qualified Data.Text.IO
import Data.Aeson as Aeson
import Data.Text (Text)
import qualified Path.Aliases as Path

import qualified Generator.Templates


-- TODO: Should we use DI via data instead of typeclasses?
--   https://news.ycombinator.com/item?id=10392044

-- TODO: Should we make constraint MonadIO instead of just Monad?
--   That would allow us to do liftIO. And that might allow us to perform any IO
--   we want (hm will it?), which could be useful for custom stuff (but does that defeat the whole purpose?).
--   But that means we can't test that part, which yes, defeats the purpose somewhat.
--   I feel like all together we should not do it :), but it is an option if needed.

-- | Describes effects needed by File Drafts.
class (Monad m) => WriteableMonad m where
    createDirectoryIfMissing
        :: Bool  -- ^ True if parents should also be created.
        -> FilePath  -- ^ Path to the directory to create.
        -> m ()

    copyFile
        :: FilePath  -- ^ Src path.
        -> FilePath  -- ^ Dst path.
        -> m ()

    writeFileFromText :: FilePath -> Text -> m ()

    getTemplateFileAbsPath
        :: Path.RelFile  -- ^ Template file path, relative to templates root directory.
        -> m Path.AbsFile

    -- | Returns absolute path of templates root directory.
    getTemplatesDirAbsPath :: m Path.AbsDir

    compileAndRenderTemplate
        :: Path.RelFile  -- ^ Path to the template file, relative to template root dir.
        -> Aeson.Value  -- ^ JSON to be provided as template data.
        -> m Text

instance WriteableMonad IO where
    createDirectoryIfMissing = System.Directory.createDirectoryIfMissing
    copyFile = System.Directory.copyFile
    writeFileFromText = Data.Text.IO.writeFile
    getTemplateFileAbsPath = Generator.Templates.getTemplateFileAbsPath
    getTemplatesDirAbsPath = Generator.Templates.getTemplatesDirAbsPath
    compileAndRenderTemplate = Generator.Templates.compileAndRenderTemplate
