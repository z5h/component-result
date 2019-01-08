module Main exposing (main)

import Browser
import ComponentResult
import Html
import Page


type alias Model =
    { pageModel : Page.Model
    }


type Msg
    = PageMsg Page.Msg


main : Program () Model Msg
main =
    Browser.document
        { init = init
        , view = view
        , update = update
        , subscriptions = \_ -> Sub.none
        }


init : () -> ( Model, Cmd Msg )
init _ =
    Page.init
        |> ComponentResult.mapModel (\pageModel -> { pageModel = pageModel })
        |> ComponentResult.resolve


view : Model -> Browser.Document Msg
view model =
    { title = "Sample app"
    , body =
        [ Page.view model.pageModel |> Html.map PageMsg
        ]
    }


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        PageMsg pageMsg ->
            Page.update pageMsg model.pageModel
                |> ComponentResult.mapModel (\newPageModel -> { pageModel = newPageModel })
                |> ComponentResult.mapMsg PageMsg
                |> ComponentResult.resolve
