module Page.PreviewDocumentation where

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Dict
import Json.Decode as Json exposing ((:=))

import Route
import Component.Header as Header
import Component.PackageDocs as PDocs
import Docs.Package as Docs



-- PORTS

port fileReader : Signal (Maybe { fileText : String })



-- SIGNALS

main : Signal Html
main =
  Signal.map (view actionsInbox.address) models


models : Signal Model
models =
  Signal.foldp update initialModel actions


actions : Signal Action
actions =
  Signal.merge actionsInbox.signal loadedJsons


actionsInbox : Signal.Mailbox Action
actionsInbox =
  Signal.mailbox NoOp


loadedJsons : Signal Action
loadedJsons =
  let
    loadFile readFile =
      case readFile of
        Just jsonFile ->
          LoadDocs (jsonFile.fileText)

        Nothing ->
          WrongFile

  in
    Signal.map loadFile fileReader


dummySignal : Signal.Mailbox PDocs.Action
dummySignal =
  Signal.mailbox PDocs.NoOp



-- MODEL

type alias Model =
  { header : Header.Model
  , currentModuleDoc : PDocs.Model
  , moduleDocs : Dict.Dict String Docs.Module
  , fileError : Bool
  }


initialModel : Model
initialModel =
  { header = Header.Model Route.Tools
  , currentModuleDoc = PDocs.Loading
  , moduleDocs = Dict.empty
  , fileError = False
  }



-- UPDATE

type Action
  = NoOp
  | WrongFile
  | LoadDocs String
  | ShowModule String


update : Action -> Model -> Model
update action model =
  case action of
    NoOp ->
      model

    LoadDocs fileText ->
      let
        docs = loadDocs fileText
      in
        { model
          | currentModuleDoc = rawDocs (firstModuleName docs) docs
          , moduleDocs = docs
          , fileError = False
        }

    ShowModule moduleName ->
      { model
        | currentModuleDoc = rawDocs moduleName model.moduleDocs
      }

    WrongFile ->
      { model
        | fileError = True
      }



-- VIEW

view : Signal.Address Action -> Model -> Html
view address model =
  Header.view dummySignal.address model.header
    [ node "script" [ src "/assets/js/jsonLoader.js" ] []
    , div []
      [ h1 [] [ text "Preview your documentation" ]
      , input [ type' "file", id "fileLoader" ] []
      , hr [] []
      ]
    , moduleView address model
    ]


moduleView : Signal.Address Action -> Model -> Html
moduleView address model =
  let
    modulesNames =
      Dict.keys model.moduleDocs

    instructions =
      [ h2 [] [ text "How to use this:"]
      , text instructionsText ]
  in
    div [] <|
      if model.fileError then
        [ h3
          [ style [ ("color", "red") ] ]
          [ text "Wrong File. Make sure you're loading a .json file" ]
        ] ++ instructions
      else
        case model.currentModuleDoc of
          (PDocs.Loading) ->
              instructions

          (PDocs.RawDocs _) ->
              [ PDocs.view dummySignal.address model.currentModuleDoc
              , viewSidebar address modulesNames
              ]

          (PDocs.ParsedDocs _) -> []
          (PDocs.Readme _) -> []  -- We can add this later maybe
          (PDocs.Failed _) -> []


viewSidebar : Signal.Address Action -> List String -> Html
viewSidebar address modulesNames =
  div [ class "pkg-nav" ]
    [ ul
      [ class "pkg-nav-value" ]
      (moduleLinks address modulesNames)
    ]


moduleLinks : Signal.Address Action -> List String -> List Html
moduleLinks address modulesNames =
  let
    moduleItem moduleName =
      li [] [ moduleLink address moduleName ]

  in
    List.map moduleItem modulesNames


moduleLink : Signal.Address Action -> String -> Html
moduleLink address moduleName =
  a
    [ onClick address (ShowModule moduleName)
    , class "pkg-nav-module", href "#"
    ]
    [ text moduleName ]



-- DOCS FUNCTIONS

loadDocs : String -> Dict.Dict String Docs.Module
loadDocs fileText =
  getModules fileText


firstModuleName : Dict.Dict String Docs.Module -> String
firstModuleName modules =
  Dict.keys modules
    |> List.head
    |> Maybe.withDefault ""


getModules : String -> Dict.Dict String Docs.Module
getModules docs =
  Json.decodeString Docs.decodePackage docs
  |> Result.withDefault Dict.empty


rawDocs : String -> Dict.Dict String Docs.Module -> PDocs.Model
rawDocs moduleName docs =
  case Dict.get moduleName docs of
    Just moduleDocs ->
      let
        chunks =
          PDocs.toChunks moduleDocs
      in
        PDocs.RawDocs (PDocs.Info moduleName (PDocs.toNameDict docs) chunks)

    Nothing ->
      PDocs.Loading



-- INSTRUCTIONS

instructionsText : String
instructionsText = """
Hola a todos
como estan
"""
