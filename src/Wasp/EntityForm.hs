module Wasp.EntityForm
    ( EntityForm(..)
    , Submit(..)
    , SubmitButton(..)
    , Field(..)
    , DefaultValue(..)
    , getConfigForField
    ) where

import Data.Aeson ((.=), object, ToJSON(..))

import qualified Util as U
import qualified Wasp.Entity as Entity


data EntityForm = EntityForm
    { _name :: !String -- Name of the form
    , _entityName :: !String -- Name of the entity the form is linked to
    -- TODO(matija): should we make these maybes also strict?
    , _submit :: Maybe Submit
    , _fields :: [Field]
    } deriving (Show, Eq)

-- NOTE(matija): Ideally generator would not depend on this logic defined outside of it.
-- We are moving away from this approach but some parts of code (Page generator) still
-- rely on it so we cannot remove it completely yet without further refactoring.
--
-- Some record fields are note even included (e.g. _fields), we are keeping this only for the
-- backwards compatibility.
instance ToJSON EntityForm where
    toJSON entityForm = object
        [ "name" .= _name entityForm
        , "entityName" .= _entityName entityForm
        , "submitConfig" .= _submit entityForm
        ]

-- | For a given entity field, returns its configuration from the given entity-form, if present.
getConfigForField :: EntityForm -> Entity.EntityField -> Maybe Field
getConfigForField entityForm entityField =
    U.headSafe $ filter isConfigOfInputEntityField $ _fields entityForm
    where
        isConfigOfInputEntityField :: Field -> Bool
        isConfigOfInputEntityField =
            (== Entity.entityFieldName entityField) . _fieldName

-- * Submit

data Submit = Submit
    { _onEnter :: Maybe Bool
    , _submitButton :: Maybe SubmitButton
    } deriving (Show, Eq)

data SubmitButton = SubmitButton
    { _submitButtonShow :: Maybe Bool
    } deriving (Show, Eq)

instance ToJSON Submit where
    toJSON submit = object
        [ "onEnter" .= _onEnter submit
        ]

-- * Field

data Field = Field
    { _fieldName :: !String
    , _fieldShow :: Maybe Bool
    , _fieldDefaultValue :: Maybe DefaultValue
    , _fieldPlaceholder :: Maybe String
    } deriving (Show, Eq)

data DefaultValue
    = DefaultValueString String
    | DefaultValueBool Bool
    deriving (Show, Eq)


