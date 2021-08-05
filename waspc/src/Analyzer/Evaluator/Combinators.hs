{-# LANGUAGE GeneralisedNewtypeDeriving #-}
{-# LANGUAGE LambdaCase #-}
{-# LANGUAGE ScopedTypeVariables #-}
{-# LANGUAGE TypeApplications #-}

module Analyzer.Evaluator.Combinators
  ( -- * Types
    Transform,
    TransformDict,

    -- * Functions
    build,

    -- * "Transform" combinators
    string,
    integer,
    double,
    bool,
    decl,
    enum,
    dict,
    list,
    extImport,
    json,
    psl,

    -- * "TransformDict" combinators
    field,
    maybeField,
  )
where

import Analyzer.Evaluator.Decl
import Analyzer.Evaluator.EvaluationError
import qualified Analyzer.Evaluator.Types as E
import Analyzer.TypeChecker.AST (ExtImportName (..), TypedExpr (..))
import qualified Analyzer.TypeDefinitions as TD
import qualified Data.HashMap.Internal.Strict as H
import Data.Typeable (cast)

newtype Transform a = Transform
  { runTransform :: (TD.TypeDefinitions, H.HashMap String Decl, TypedExpr) -> a
  }
  deriving (Functor, Applicative, Monad)

newtype TransformDict a = TransformDict
  { runTransformDict :: (TD.TypeDefinitions, H.HashMap String Decl, [(String, TypedExpr)]) -> a
  }
  deriving (Functor, Applicative, Monad)

build :: Transform a -> TD.TypeDefinitions -> H.HashMap String Decl -> TypedExpr -> Either EvaluationError a
build transform typeDefs bindings expr = Right $ runTransform transform (typeDefs, bindings, expr)

string :: Transform String
string = Transform $ \case
  (_, _, StringLiteral str) -> str
  _ -> error "expected StringType (invalid instance of IsDeclType)"

integer :: Transform Integer
integer = Transform $ \case
  (_, _, IntegerLiteral i) -> i
  (_, _, DoubleLiteral x) -> round x
  _ -> error "expected NumberType (invalid instance of IsDeclType)"

double :: Transform Double
double = Transform $ \case
  (_, _, IntegerLiteral i) -> fromIntegral i
  (_, _, DoubleLiteral x) -> x
  _ -> error "expected NumberType (invalid instance of IsDeclType)"

bool :: Transform Bool
bool = Transform $ \case
  (_, _, BoolLiteral b) -> b
  _ -> error "expected BoolType (invalid instance of IsDeclType)"

decl :: TD.IsDeclType a => Transform a
decl = Transform $ \case
  (_, bindings, Var var _) -> case H.lookup var bindings of
    Nothing -> error $ "undefined variable " ++ var
    Just (Decl _ value) -> case cast value of
      Nothing -> error $ "wrong type for variable " ++ var
      Just a -> a
  _ -> error "expected Var (invalid instance of IsDeclType)"

enum :: forall a. TD.IsEnumType a => Transform a
enum = Transform $ \case
  (_, _, Var var _) -> let Right x = TD.enumTypeFromVariant @a var in x
  _ -> error "expected Var (invalid instance of IsEnumType"

dict :: TransformDict a -> Transform a
dict inner = Transform $ \case
  (typeDefs, bindings, Dict entries _) -> runTransformDict inner (typeDefs, bindings, entries)
  _ -> error "Expected DictType (invalid instance of IsDeclType)"

list :: Transform a -> Transform [a]
list inner = Transform $ \case
  (typeDefs, bindings, List values _) -> map (\expr -> runTransform inner (typeDefs, bindings, expr)) values
  _ -> error "Expected ListType (invalid instance of IsDeclType)"

extImport :: Transform E.ExtImport
extImport = Transform $ \case
  (_, _, ExtImport name file) -> E.ExtImport name file
  _ -> error "Expected ExtImport (invalid instance of IsDeclType)"

json :: Transform E.JSON
json = Transform $ \case
  (_, _, JSON str) -> E.JSON str
  _ -> error "Expected JSON (invalid instance of IsDeclType)"

psl :: Transform E.PSL
psl = Transform $ \case
  (_, _, PSL str) -> E.PSL str
  _ -> error "Expected PSL (invalid instance of IsDeclType)"

field :: String -> Transform a -> TransformDict a
field key valueTransform = TransformDict $ \(typeDefs, bindings, entries) -> case lookup key entries of
  Nothing -> error $ "Missing field " ++ key ++ " (invalid instance of IsDeclType)"
  Just value -> runTransform valueTransform (typeDefs, bindings, value)

maybeField :: String -> Transform a -> TransformDict (Maybe a)
maybeField key valueTransform = TransformDict $ \(typeDefs, bindings, entries) -> case lookup key entries of
  Nothing -> Nothing
  Just value -> Just $ runTransform valueTransform (typeDefs, bindings, value)
