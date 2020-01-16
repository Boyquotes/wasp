module Generator.Generators
       ( generateWebApp
       ) where

import Data.Aeson ((.=), object, ToJSON(..))
import System.FilePath (FilePath, (</>))

import CompileOptions (CompileOptions)
import qualified Util
import Wasp
import Generator.FileDraft
import qualified Generator.EntityGenerator as EntityGenerator
import qualified Generator.PageGenerator as PageGenerator
import qualified Generator.ExternalCode as ExternalCodeGenerator
import qualified Generator.Common as Common


generateWebApp :: Wasp -> CompileOptions -> [FileDraft]
generateWebApp wasp options = concatMap ($ wasp)
    [ generateReadme
    , generatePackageJson
    , generateGitignore
    , generatePublicDir
    , generateSrcDir
    , ExternalCodeGenerator.generateExternalCodeDir options
    ]

generateReadme :: Wasp -> [FileDraft]
generateReadme wasp = [simpleTemplateFileDraft "README.md" wasp]

generatePackageJson :: Wasp -> [FileDraft]
generatePackageJson wasp = [simpleTemplateFileDraft "package.json" wasp]

generateGitignore :: Wasp -> [FileDraft]
generateGitignore wasp = [createTemplateFileDraft ".gitignore" "gitignore" (Just $ toJSON wasp)]

generatePublicDir :: Wasp -> [FileDraft]
generatePublicDir wasp
    = createTemplateFileDraft ("public" </> "favicon.ico") ("public" </> "favicon.ico") Nothing
    : map (\path -> simpleTemplateFileDraft ("public/" </> path) wasp)
        [ "index.html"
        , "manifest.json"
        ]

-- * Src dir

generateSrcDir :: Wasp -> [FileDraft]
generateSrcDir wasp
    = (createTemplateFileDraft (Common.srcDirPath </> "logo.png") ("src" </> "logo.png") Nothing)
    : map (\path -> simpleTemplateFileDraft ("src/" </> path) wasp)
        [ "index.js"
        , "index.css"
        , "router.js"
        , "serviceWorker.js"
        , "store/index.js"
        , "store/middleware/logger.js"
        ]
    ++ PageGenerator.generatePages wasp
    ++ EntityGenerator.generateEntities wasp
    ++ [generateReducersJs wasp]

generateReducersJs :: Wasp -> FileDraft
generateReducersJs wasp = createTemplateFileDraft dstPath srcPath (Just templateData)
  where
    srcPath = "src" </> "reducers.js"
    dstPath = Common.srcDirPath </> "reducers.js"
    templateData = object
        [ "wasp" .= wasp
        , "entities" .= map toEntityData (getEntities wasp)
        ]
    toEntityData entity = object
        [ "entity" .= entity
        , "entityLowerName" .= (Util.toLowerFirst $ entityName entity)
        , "entityStatePath" .= ("./" ++ (EntityGenerator.entityStatePathInSrc entity))
        ]


-- * Helpers

-- | Creates template file draft that uses given path as both src and dst path
--   and wasp as template data.
simpleTemplateFileDraft :: FilePath -> Wasp -> FileDraft
simpleTemplateFileDraft path wasp = createTemplateFileDraft path path (Just $ toJSON wasp)
