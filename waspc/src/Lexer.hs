module Lexer where

import Text.Parsec (letter, alphaNum, (<|>), char, between)
import Text.Parsec.String (Parser)
import Text.Parsec.Language (emptyDef)
import qualified Text.Parsec.Token as Token

reservedNameImport :: String
reservedNameImport = "import"

reservedNameFrom :: String
reservedNameFrom = "from"

-- * Wasp element types

reservedNameApp :: String
reservedNameApp = "app"

reservedNamePage :: String
reservedNamePage = "page"

reservedNameRoute :: String
reservedNameRoute = "route"

reservedNameEntityPSL :: String
reservedNameEntityPSL = "entityPSL"


-- TODO(matija): old Entity stuff, to be removed.
reservedNameEntity :: String
reservedNameEntity = "entity"

reservedNameEntityForm :: String
reservedNameEntityForm = "entity-form"

reservedNameEntityList :: String
reservedNameEntityList = "entity-list"


reservedNameQuery :: String
reservedNameQuery = "query"

reservedNameAction :: String
reservedNameAction = "action"

reservedNameDependencies :: String
reservedNameDependencies = "dependencies"

-- * Data types.

reservedNameString :: String
reservedNameString = "string"

reservedNameBoolean :: String
reservedNameBoolean = "boolean"

reservedNameBooleanTrue :: String
reservedNameBooleanTrue = "true"

reservedNameBooleanFalse :: String
reservedNameBooleanFalse = "false"

reservedNames :: [String]
reservedNames =
    [ reservedNameImport
    , reservedNameFrom
    -- * Wasp element types
    , reservedNameApp
    , reservedNameDependencies
    , reservedNamePage
    , reservedNameRoute
    , reservedNameEntityPSL

    -- TODO(matija): old entity stuff, to be removed.
    , reservedNameEntity
    , reservedNameEntityForm

    , reservedNameQuery
    , reservedNameAction
    -- * Data types
    , reservedNameString
    , reservedNameBoolean
    , reservedNameBooleanTrue
    , reservedNameBooleanFalse
    ]

waspLanguageDef :: Token.LanguageDef ()
waspLanguageDef = emptyDef
    { Token.commentLine = "//"
    , Token.reservedNames = reservedNames
    , Token.caseSensitive = True
    -- Identifier
    , Token.identStart = letter
    , Token.identLetter = alphaNum <|> char '_'
    }

waspLexer :: Token.TokenParser ()
waspLexer = Token.makeTokenParser waspLanguageDef

reserved :: String -> Parser ()
reserved = Token.reserved waspLexer

identifier :: Parser String
identifier = Token.identifier waspLexer

symbol :: String -> Parser String
symbol = Token.symbol waspLexer

colon :: Parser String
colon = Token.colon waspLexer

braces :: Parser a -> Parser a
braces = Token.braces waspLexer

brackets :: Parser a -> Parser a
brackets = Token.brackets waspLexer

-- Parses content between '<' and '>'.
angles :: Parser a -> Parser a
angles = Token.angles waspLexer

commaSep :: Parser a -> Parser [a]
commaSep = Token.commaSep waspLexer

commaSep1 :: Parser a -> Parser [a]
commaSep1 = Token.commaSep1 waspLexer

whiteSpace :: Parser ()
whiteSpace = Token.whiteSpace waspLexer

singleQuotes :: Parser a -> Parser a
singleQuotes p = between (symbol "'") (symbol "'") p

stringLiteral :: Parser String
stringLiteral = Token.stringLiteral waspLexer

-- * Parsing boolean values

bool :: Parser Bool
bool = boolTrue <|> boolFalse

boolTrue :: Parser Bool
boolTrue = reserved reservedNameBooleanTrue *> return True

boolFalse :: Parser Bool
boolFalse = reserved reservedNameBooleanFalse *> return False
