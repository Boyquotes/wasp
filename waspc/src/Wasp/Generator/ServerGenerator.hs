{-# LANGUAGE TypeApplications #-}

module Wasp.Generator.ServerGenerator
  ( genServer,
    preCleanup,
    operationsRouteInRootRouter,
    npmDepsForWasp,
  )
where

import Control.Monad (unless)
import Data.Aeson (object, (.=))
import Data.Maybe
  ( fromJust,
    fromMaybe,
    isJust,
  )
import StrongPath (Abs, Dir, File', Path, Path', Posix, Rel, reldir, reldirP, relfile, (</>))
import qualified StrongPath as SP
import System.Directory (removeFile)
import System.IO.Error (isDoesNotExistError)
import UnliftIO.Exception (catch, throwIO)
import Wasp.AppSpec (AppSpec)
import qualified Wasp.AppSpec as AS
import qualified Wasp.AppSpec.App as AS.App
import qualified Wasp.AppSpec.App.Auth as AS.App.Auth
import qualified Wasp.AppSpec.App.Dependency as AS.Dependency
import qualified Wasp.AppSpec.App.Server as AS.App.Server
import qualified Wasp.AppSpec.Entity as AS.Entity
import Wasp.Generator.Common (ProjectRootDir, nodeVersionAsText, prismaVersion)
import Wasp.Generator.ExternalCodeGenerator (generateExternalCodeDir)
import Wasp.Generator.ExternalCodeGenerator.Common (GeneratedExternalCodeDir)
import Wasp.Generator.FileDraft (FileDraft, createCopyFileDraft)
import Wasp.Generator.JsImport (getJsImportDetailsForExtFnImport)
import Wasp.Generator.Monad (Generator)
import qualified Wasp.Generator.NpmDependencies as N
import Wasp.Generator.ServerGenerator.AuthG (genAuth)
import Wasp.Generator.ServerGenerator.Common
  ( ServerSrcDir,
    asServerFile,
    asTmplFile,
  )
import qualified Wasp.Generator.ServerGenerator.Common as C
import Wasp.Generator.ServerGenerator.ConfigG (genConfigFile)
import qualified Wasp.Generator.ServerGenerator.ExternalCodeGenerator as ServerExternalCodeGenerator
import Wasp.Generator.ServerGenerator.OperationsG (genOperations)
import Wasp.Generator.ServerGenerator.OperationsRoutesG (genOperationsRoutes)
import Wasp.Util ((<++>))

genServer :: AppSpec -> Generator [FileDraft]
genServer spec =
  sequence
    [ genReadme,
      genPackageJson spec npmDepsForWasp,
      genNpmrc,
      genNvmrc,
      genGitignore
    ]
    <++> genSrcDir spec
    <++> generateExternalCodeDir ServerExternalCodeGenerator.generatorStrategy (AS.externalCodeFiles spec)
    <++> genDotEnv spec

-- Cleanup to be performed before generating new server code.
-- This might be needed in case if outDir is not empty (e.g. we already generated server code there before).
-- TODO: Once we implement a fancier method of removing old/redundant files in outDir,
--   we will not need this method any more. Check https://github.com/wasp-lang/wasp/issues/209
--   for progress of this.
preCleanup :: AppSpec -> Path' Abs (Dir ProjectRootDir) -> IO ()
preCleanup _ outDir = do
  -- If .env gets removed but there is old .env file in generated project from previous attempts,
  -- we need to make sure we remove it.
  removeFile dotEnvAbsFilePath
    `catch` \e -> unless (isDoesNotExistError e) $ throwIO e
  where
    dotEnvAbsFilePath = SP.toFilePath $ outDir </> C.serverRootDirInProjectRootDir </> dotEnvInServerRootDir

genDotEnv :: AppSpec -> Generator [FileDraft]
genDotEnv spec = return $
  case AS.dotEnvFile spec of
    Just srcFilePath
      | not $ AS.isBuild spec ->
        [ createCopyFileDraft
            (C.serverRootDirInProjectRootDir </> dotEnvInServerRootDir)
            srcFilePath
        ]
    _ -> []

dotEnvInServerRootDir :: Path' (Rel C.ServerRootDir) File'
dotEnvInServerRootDir = [relfile|.env|]

genReadme :: Generator FileDraft
genReadme = return $ C.mkTmplFd (asTmplFile [relfile|README.md|])

genPackageJson :: AppSpec -> N.NpmDepsForWasp -> Generator FileDraft
genPackageJson spec waspDependencies = do
  combinedDependencies <- N.genNpmDepsForPackage spec waspDependencies
  return $
    C.mkTmplFdWithDstAndData
      (asTmplFile [relfile|package.json|])
      (asServerFile [relfile|package.json|])
      ( Just $
          object
            [ "depsChunk" .= N.getDependenciesPackageJsonEntry combinedDependencies,
              "devDepsChunk" .= N.getDevDependenciesPackageJsonEntry combinedDependencies,
              "nodeVersion" .= nodeVersionAsText,
              "startProductionScript"
                .= ( (if not (null $ AS.getDecls @AS.Entity.Entity spec) then "npm run db-migrate-prod && " else "")
                       ++ "NODE_ENV=production node ./src/server.js"
                   )
            ]
      )

npmDepsForWasp :: N.NpmDepsForWasp
npmDepsForWasp =
  N.NpmDepsForWasp
    { N.waspDependencies =
        AS.Dependency.fromList
          [ ("cookie-parser", "~1.4.4"),
            ("cors", "^2.8.5"),
            ("debug", "~2.6.9"),
            ("express", "~4.16.1"),
            ("morgan", "~1.9.1"),
            ("@prisma/client", prismaVersion),
            ("jsonwebtoken", "^8.5.1"),
            ("secure-password", "^4.0.0"),
            ("dotenv", "8.2.0"),
            ("helmet", "^4.6.0")
          ],
      N.waspDevDependencies =
        AS.Dependency.fromList
          [ ("nodemon", "^2.0.4"),
            ("standard", "^14.3.4"),
            ("prisma", prismaVersion)
          ]
    }

genNpmrc :: Generator FileDraft
genNpmrc =
  return $
    C.mkTmplFdWithDstAndData
      (asTmplFile [relfile|npmrc|])
      (asServerFile [relfile|.npmrc|])
      Nothing

genNvmrc :: Generator FileDraft
genNvmrc =
  return $
    C.mkTmplFdWithDstAndData
      (asTmplFile [relfile|nvmrc|])
      (asServerFile [relfile|.nvmrc|])
      (Just (object ["nodeVersion" .= ('v' : nodeVersionAsText)]))

genGitignore :: Generator FileDraft
genGitignore =
  return $
    C.mkTmplFdWithDstAndData
      (asTmplFile [relfile|gitignore|])
      (asServerFile [relfile|.gitignore|])
      Nothing

genSrcDir :: AppSpec -> Generator [FileDraft]
genSrcDir spec =
  sequence
    [ return $ C.mkSrcTmplFd $ C.asTmplSrcFile [relfile|app.js|],
      return $ C.mkSrcTmplFd $ C.asTmplSrcFile [relfile|server.js|],
      return $ C.mkSrcTmplFd $ C.asTmplSrcFile [relfile|utils.js|],
      return $ C.mkSrcTmplFd $ C.asTmplSrcFile [relfile|core/AuthError.js|],
      return $ C.mkSrcTmplFd $ C.asTmplSrcFile [relfile|core/HttpError.js|],
      genDbClient spec,
      genConfigFile spec,
      genServerJs spec
    ]
    <++> genRoutesDir spec
    <++> genOperationsRoutes spec
    <++> genOperations spec
    <++> genAuth spec

genDbClient :: AppSpec -> Generator FileDraft
genDbClient spec = return $ C.mkTmplFdWithDstAndData tmplFile dstFile (Just tmplData)
  where
    maybeAuth = AS.App.auth $ snd $ AS.getApp spec

    dbClientRelToSrcP = [relfile|dbClient.js|]
    tmplFile = C.asTmplFile $ [reldir|src|] </> dbClientRelToSrcP
    dstFile = C.serverSrcDirInServerRootDir </> C.asServerSrcFile dbClientRelToSrcP

    tmplData =
      if isJust maybeAuth
        then
          object
            [ "isAuthEnabled" .= True,
              "userEntityUpper" .= (AS.refName (AS.App.Auth.userEntity $ fromJust maybeAuth) :: String)
            ]
        else object []

genServerJs :: AppSpec -> Generator FileDraft
genServerJs spec =
  return $
    C.mkTmplFdWithDstAndData
      (asTmplFile [relfile|src/server.js|])
      (asServerFile [relfile|src/server.js|])
      ( Just $
          object
            [ "doesServerSetupFnExist" .= isJust maybeSetupJsFunction,
              "serverSetupJsFnImportStatement" .= fromMaybe "" maybeSetupJsFnImportStmt,
              "serverSetupJsFnIdentifier" .= fromMaybe "" maybeSetupJsFnImportIdentifier
            ]
      )
  where
    maybeSetupJsFunction = AS.App.Server.setupFn =<< AS.App.server (snd $ AS.getApp spec)
    maybeSetupJsFnImportDetails = getJsImportDetailsForExtFnImport relPosixPathFromSrcDirToExtSrcDir <$> maybeSetupJsFunction
    (maybeSetupJsFnImportIdentifier, maybeSetupJsFnImportStmt) =
      (fst <$> maybeSetupJsFnImportDetails, snd <$> maybeSetupJsFnImportDetails)

-- | TODO: Make this not hardcoded!
relPosixPathFromSrcDirToExtSrcDir :: Path Posix (Rel (Dir ServerSrcDir)) (Dir GeneratedExternalCodeDir)
relPosixPathFromSrcDirToExtSrcDir = [reldirP|./ext-src|]

genRoutesDir :: AppSpec -> Generator [FileDraft]
genRoutesDir spec =
  -- TODO(martin): We will probably want to extract "routes" path here same as we did with "src", to avoid hardcoding,
  -- but I did not bother with it yet since it is used only here for now.
  return
    [ C.mkTmplFdWithDstAndData
        (asTmplFile [relfile|src/routes/index.js|])
        (asServerFile [relfile|src/routes/index.js|])
        ( Just $
            object
              [ "operationsRouteInRootRouter" .= (operationsRouteInRootRouter :: String),
                "isAuthEnabled" .= (AS.isAuthEnabled spec :: Bool)
              ]
        )
    ]

operationsRouteInRootRouter :: String
operationsRouteInRootRouter = "operations"
