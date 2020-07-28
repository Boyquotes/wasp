module Generator.ExternalCodeGenerator.Common
    ( ExternalCodeGeneratorStrategy(..)
    , GeneratedExternalCodeDir
    , castRelPathFromSrcToGenExtCodeDir
    , asGenExtFile
    ) where

import Data.Text (Text)
import qualified Path as P

import StrongPath (Path, Rel, File, Dir)
import qualified StrongPath as SP
import Generator.Common (ProjectRootDir)
import ExternalCode (SourceExternalCodeDir)


data GeneratedExternalCodeDir -- ^ Path to the directory where ext code will be generated.

asGenExtFile :: P.Path P.Rel P.File -> (Path (Rel GeneratedExternalCodeDir) File)
asGenExtFile = SP.fromPathRelFile

castRelPathFromSrcToGenExtCodeDir :: Path (Rel SourceExternalCodeDir) a -> Path (Rel GeneratedExternalCodeDir) a
castRelPathFromSrcToGenExtCodeDir = SP.castRel

data ExternalCodeGeneratorStrategy = ExternalCodeGeneratorStrategy
    { -- | Takes a path where the external code js file will be generated.
      -- Also takes text of the file. Returns text where special @wasp imports have been replaced with
      -- imports that will work.
      _resolveJsFileWaspImports :: Path (Rel GeneratedExternalCodeDir) File -> Text -> Text
    , _extCodeDirInProjectRootDir :: Path (Rel ProjectRootDir) (Dir GeneratedExternalCodeDir)
    }
